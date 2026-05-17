// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { VulnerableAdmin } from "../../src/vulnerabilities/VulnerableAdmin.sol";
import { FixedAdmin } from "../../src/vulnerabilities/FixedAdmin.sol";

// Malicious intermediary that tricks the admin into invoking it.
// Because VulnerableAdmin uses tx.origin, this attack succeeds.
contract MaliciousProxy {
    VulnerableAdmin public vulnerableTarget;
    FixedAdmin public fixedTarget;

    constructor(address vulnerable, address fixed_) {
        vulnerableTarget = VulnerableAdmin(vulnerable);
        fixedTarget = FixedAdmin(fixed_);
    }

    function triggerVulnerableSet(uint256 maliciousValue) external {
        vulnerableTarget.setCriticalValue(maliciousValue);
    }

    function triggerFixedSet(uint256 maliciousValue) external {
        fixedTarget.setCriticalValue(maliciousValue);
    }
}

contract AccessControlCaseStudyTest is Test {
    VulnerableAdmin public vulnerableAdmin;
    FixedAdmin public fixedAdmin;
    MaliciousProxy public maliciousProxy;
    address public admin = address(0xAD314);

    function setUp() public {
        vulnerableAdmin = new VulnerableAdmin(admin);
        fixedAdmin = new FixedAdmin(admin);
        maliciousProxy = new MaliciousProxy(address(vulnerableAdmin), address(fixedAdmin));
    }

    // BEFORE FIX: tx.origin makes admin's call through a malicious proxy succeed.
    // Admin thinks they're calling the proxy; the proxy calls VulnerableAdmin;
    // tx.origin is still admin, so the check passes.
    function test_Before_VulnerableAdmin_TxOriginAllowsProxyAttack() public {
        assertEq(vulnerableAdmin.criticalValue(), 0);

        // Simulate admin being tricked into invoking the malicious proxy.
        vm.prank(admin, admin);
        maliciousProxy.triggerVulnerableSet(99999);

        // Attack succeeded: critical value was modified by the proxy
        // even though the proxy itself is not the administrator.
        assertEq(vulnerableAdmin.criticalValue(), 99999);
    }

    // AFTER FIX: AccessControl uses msg.sender, which is the proxy contract.
    // The proxy does not hold ADMIN_ROLE, so the call reverts.
    function test_After_FixedAdmin_AccessControlBlocksProxyAttack() public {
        assertEq(fixedAdmin.criticalValue(), 0);

        vm.prank(admin);
        vm.expectRevert();
        maliciousProxy.triggerFixedSet(99999);

        // Attack failed: critical value is unchanged.
        assertEq(fixedAdmin.criticalValue(), 0);
    }

    // Sanity check: legitimate admin still works on FixedAdmin via direct call.
    function test_After_FixedAdmin_LegitimateAdminCanSetValue() public {
        vm.prank(admin);
        fixedAdmin.setCriticalValue(42);
        assertEq(fixedAdmin.criticalValue(), 42);
    }
}
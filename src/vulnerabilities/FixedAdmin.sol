// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

// FIXED VERSION - SAFE FOR PRODUCTION
// Replaces tx.origin with msg.sender via OpenZeppelin AccessControl.
// Now an intermediary contract cannot impersonate the administrator
// because role check uses msg.sender, not tx.origin.
contract FixedAdmin is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public criticalValue;

    constructor(address initialAdministrator) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdministrator);
        _grantRole(ADMIN_ROLE, initialAdministrator);
    }

    // FIX: onlyRole modifier uses msg.sender via AccessControl internally.
    // Intermediary contract calls will fail because the contract address
    // does not hold ADMIN_ROLE.
    function setCriticalValue(uint256 newValue) external onlyRole(ADMIN_ROLE) {
        criticalValue = newValue;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// VULNERABLE VERSION - DO NOT USE IN PRODUCTION
// This contract uses tx.origin for authorization, which can be bypassed
// by a malicious intermediary contract that the user unwittingly calls.
contract VulnerableAdmin {
    address public administrator;
    uint256 public criticalValue;

    constructor(address initialAdministrator) {
        administrator = initialAdministrator;
    }

    // VULNERABILITY: tx.origin always points to the original EOA.
    // If admin is tricked into calling a malicious contract, that contract
    // can invoke setCriticalValue successfully because tx.origin == admin
    // even though msg.sender is the malicious contract.
    function setCriticalValue(uint256 newValue) external {
        require(tx.origin == administrator, "Not admin");
        criticalValue = newValue;
    }
}
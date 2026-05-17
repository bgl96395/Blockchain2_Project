// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// VULNERABLE VERSION - DO NOT USE IN PRODUCTION
// This contract is intentionally vulnerable to demonstrate reentrancy attacks.
// See FixedBank.sol for the corrected version with CEI pattern.
contract VulnerableBank {
    mapping(address => uint256) public depositorBalances;

    function depositEther() external payable {
        depositorBalances[msg.sender] += msg.value;
    }

    // VULNERABILITY: external call happens before state update.
    // A malicious receiver can re-enter and drain the contract.
    function withdrawEther() external {
        uint256 callerBalance = depositorBalances[msg.sender];
        require(callerBalance > 0, "Zero balance");

        (bool success,) = msg.sender.call{value: callerBalance}("");
        require(success, "Transfer failed");

        depositorBalances[msg.sender] = 0;
    }

    receive() external payable {}
}
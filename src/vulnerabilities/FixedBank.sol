// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// FIXED VERSION - SAFE FOR PRODUCTION
// Demonstrates the corrected approach with Checks-Effects-Interactions
// and OpenZeppelin's ReentrancyGuard for defense in depth.
contract FixedBank is ReentrancyGuard {
    mapping(address => uint256) public depositorBalances;

    function depositEther() external payable {
        depositorBalances[msg.sender] += msg.value;
    }

    // FIX 1: state update happens before external call (CEI pattern).
    // FIX 2: nonReentrant modifier prevents reentrancy as defense in depth.
    function withdrawEther() external nonReentrant {
        uint256 callerBalance = depositorBalances[msg.sender];
        require(callerBalance > 0, "Zero balance");

        depositorBalances[msg.sender] = 0;

        (bool success,) = msg.sender.call{value: callerBalance}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}
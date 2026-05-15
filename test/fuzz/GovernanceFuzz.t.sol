// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { GameToken } from "../../src/governance/GameToken.sol";

contract GovernanceFuzzTest is Test {
    GameToken public governanceToken;

    address public constant TOKEN_ADMIN = address(0xAD314);
    uint256 public constant MAXIMUM_TOKEN_SUPPLY = 1_000_000 ether;

    function setUp() public {
        governanceToken = new GameToken(MAXIMUM_TOKEN_SUPPLY, TOKEN_ADMIN);
    }

    function testFuzz_Mint_BalanceIncreasesByMintedAmount(address mintRecipient, uint256 mintAmount) public {
        vm.assume(mintRecipient != address(0));
        mintAmount = bound(mintAmount, 1, MAXIMUM_TOKEN_SUPPLY);

        vm.prank(TOKEN_ADMIN);
        governanceToken.mintTokens(mintRecipient, mintAmount);

        assertEq(governanceToken.balanceOf(mintRecipient), mintAmount);
        assertEq(governanceToken.totalSupply(), mintAmount);
    }

    function testFuzz_Mint_RevertWhen_ExceedsMaxSupply(uint256 mintAmount) public {
        mintAmount = bound(mintAmount, MAXIMUM_TOKEN_SUPPLY + 1, type(uint128).max);

        vm.prank(TOKEN_ADMIN);
        vm.expectRevert(GameToken.ExceedsMaximumSupply.selector);
        governanceToken.mintTokens(address(0xBEEF), mintAmount);
    }

    function testFuzz_Delegate_VotingPowerMatchesBalance(address tokenHolder, uint256 mintAmount) public {
        vm.assume(tokenHolder != address(0));
        mintAmount = bound(mintAmount, 1, MAXIMUM_TOKEN_SUPPLY);

        vm.prank(TOKEN_ADMIN);
        governanceToken.mintTokens(tokenHolder, mintAmount);

        vm.prank(tokenHolder);
        governanceToken.delegate(tokenHolder);

        assertEq(governanceToken.getVotes(tokenHolder), mintAmount);
    }

    function testFuzz_Transfer_PreservesTotalSupply(address sender, address recipient, uint256 transferAmount) public {
        vm.assume(sender != address(0) && recipient != address(0) && sender != recipient);
        transferAmount = bound(transferAmount, 1, MAXIMUM_TOKEN_SUPPLY / 2);

        vm.prank(TOKEN_ADMIN);
        governanceToken.mintTokens(sender, transferAmount);

        uint256 totalBefore = governanceToken.totalSupply();

        vm.prank(sender);
        governanceToken.transfer(recipient, transferAmount);

        assertEq(governanceToken.totalSupply(), totalBefore);
        assertEq(governanceToken.balanceOf(sender), 0);
        assertEq(governanceToken.balanceOf(recipient), transferAmount);
    }

    function testFuzz_Mint_RevertWhen_CallerLacksMinterRole(address unauthorizedCaller, uint256 mintAmount) public {
        vm.assume(unauthorizedCaller != TOKEN_ADMIN && unauthorizedCaller != address(0));
        mintAmount = bound(mintAmount, 1, MAXIMUM_TOKEN_SUPPLY);

        vm.prank(unauthorizedCaller);
        vm.expectRevert();
        governanceToken.mintTokens(address(0xBEEF), mintAmount);
    }

    function testFuzz_VotingPower_PreservedAfterTransferIfBothDelegated(uint256 mintAmount) public {
        address holderAlice = address(0xA11CE);
        address holderBob = address(0xB0B);

        mintAmount = bound(mintAmount, 2, MAXIMUM_TOKEN_SUPPLY);

        vm.prank(TOKEN_ADMIN);
        governanceToken.mintTokens(holderAlice, mintAmount);

        vm.prank(holderAlice);
        governanceToken.delegate(holderAlice);

        vm.prank(holderBob);
        governanceToken.delegate(holderBob);

        uint256 transferAmount = mintAmount / 2;
        vm.prank(holderAlice);
        governanceToken.transfer(holderBob, transferAmount);

        assertEq(governanceToken.getVotes(holderAlice) + governanceToken.getVotes(holderBob), mintAmount);
    }
}

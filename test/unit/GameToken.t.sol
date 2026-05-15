// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { GameToken } from "../../src/governance/GameToken.sol";

contract GameTokenTest is Test {
    GameToken public gameToken;
    address public constant ADMIN = address(0xAD314);
    address public constant USER = address(0xA11CE);

    function setUp() public {
        gameToken = new GameToken(1_000_000 ether, ADMIN);
    }

    function test_Constructor_SetsMetadata() public view {
        assertEq(gameToken.name(), "Crypto Realm Token");
        assertEq(gameToken.symbol(), "REALM");
        assertEq(gameToken.maximumTokenSupply(), 1_000_000 ether);
    }

    function test_MintTokens_AdminCanMint() public {
        vm.prank(ADMIN);
        gameToken.mintTokens(USER, 1000 ether);
        assertEq(gameToken.balanceOf(USER), 1000 ether);
    }

    function test_MintTokens_RevertWhen_ExceedsMaxSupply() public {
        vm.prank(ADMIN);
        vm.expectRevert(GameToken.ExceedsMaximumSupply.selector);
        gameToken.mintTokens(USER, 2_000_000 ether);
    }

    function test_MintTokens_RevertWhen_CallerLacksRole() public {
        vm.prank(USER);
        vm.expectRevert();
        gameToken.mintTokens(USER, 1000 ether);
    }

    function test_Delegate_VotingPowerActivates() public {
        vm.prank(ADMIN);
        gameToken.mintTokens(USER, 5000 ether);

        vm.prank(USER);
        gameToken.delegate(USER);

        assertEq(gameToken.getVotes(USER), 5000 ether);
    }

    function test_Permit_NonceStartsAtZero() public view {
        assertEq(gameToken.nonces(USER), 0);
    }
}

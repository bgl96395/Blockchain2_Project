// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { GameResources } from "../../src/resources/GameResources.sol";

contract GameResourcesTest is Test {
    GameResources public gameResources;
    
    address public ADMIN_ADDRESS;
    address public USER_ALICE; 

    function setUp() public {
    ADMIN_ADDRESS = makeAddr("admin");
    USER_ALICE = makeAddr("alice");
    gameResources = new GameResources("https://api.gamefi/{id}.json", ADMIN_ADDRESS);
    }

    function test_MintResource_AssignsCorrectBalance() public {
        uint256 woodId = gameResources.RESOURCE_WOOD();
        vm.prank(ADMIN_ADDRESS);
        gameResources.mintResource(USER_ALICE, woodId, 1000);
        assertEq(gameResources.balanceOf(USER_ALICE, woodId), 1000);
    }

    function test_MintResource_RevertWhen_CallerLacksMinterRole() public {
        uint256 woodId = gameResources.RESOURCE_WOOD();
        vm.prank(USER_ALICE);
        vm.expectRevert();
        gameResources.mintResource(USER_ALICE, woodId, 1000);
    }

    function test_MintResource_RevertWhen_InvalidResourceId() public {
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert(GameResources.InvalidResourceId.selector);
        gameResources.mintResource(USER_ALICE, 999, 1000);
    }

    function test_MintResource_RevertWhen_ZeroAmount() public {
        uint256 woodId = gameResources.RESOURCE_WOOD();
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert(GameResources.ZeroMintAmount.selector);
        gameResources.mintResource(USER_ALICE, woodId, 0);
    }

    function test_Pause_BlocksMinting() public {
        uint256 woodId = gameResources.RESOURCE_WOOD();
        vm.prank(ADMIN_ADDRESS);
        gameResources.pause();
        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert();
        gameResources.mintResource(USER_ALICE, woodId, 1000);
    }

    function test_Unpause_RestoresMinting() public {
        uint256 woodId = gameResources.RESOURCE_WOOD();
        vm.prank(ADMIN_ADDRESS);
        gameResources.pause();
        vm.prank(ADMIN_ADDRESS);
        gameResources.unpause();
        vm.prank(ADMIN_ADDRESS);
        gameResources.mintResource(USER_ALICE, woodId, 1000);
        assertEq(gameResources.balanceOf(USER_ALICE, woodId), 1000);
    }

    function test_BurnResource_ReducesBalance() public {
        uint256 woodId = gameResources.RESOURCE_WOOD();
        vm.prank(ADMIN_ADDRESS);
        gameResources.mintResource(USER_ALICE, woodId, 1000);
        vm.prank(USER_ALICE);
        gameResources.burnResource(USER_ALICE, woodId, 500);
        assertEq(gameResources.balanceOf(USER_ALICE, woodId), 500);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { GameResources } from "../../src/resources/GameResources.sol";

contract GameResourcesFuzzTest is Test {
    GameResources public gameResources;
    address public constant ADMIN = address(0xAD314);

    function setUp() public {
        gameResources = new GameResources("https://api.gamefi/{id}.json", ADMIN);
    }

    function testFuzz_Mint_BalanceMatchesAmount(address recipient, uint256 amount) public {
        vm.assume(recipient != address(0));
        vm.assume(recipient.code.length == 0);
        amount = bound(amount, 1, type(uint128).max);

        uint256 woodId = gameResources.RESOURCE_WOOD(); 

        vm.prank(ADMIN);
        gameResources.mintResource(recipient, woodId, amount);

        assertEq(gameResources.balanceOf(recipient, woodId), amount);
    }

    function testFuzz_Mint_RevertWhen_InvalidResourceId(uint256 resourceId) public {
        vm.assume(resourceId == 0 || resourceId > gameResources.ITEM_SHIELD());

        vm.prank(ADMIN);
        vm.expectRevert(GameResources.InvalidResourceId.selector);
        gameResources.mintResource(address(0xBEEF), resourceId, 100);
    }

    function testFuzz_Burn_BalanceDecreasesByAmount(uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 1, type(uint128).max);
        burnAmount = bound(burnAmount, 1, mintAmount);

        address user = address(0xA11CE);
        uint256 woodId = gameResources.RESOURCE_WOOD(); 

        vm.prank(ADMIN);
        gameResources.mintResource(user, woodId, mintAmount); 

        vm.prank(user);
        gameResources.burnResource(user, woodId, burnAmount);

        assertEq(gameResources.balanceOf(user, woodId), mintAmount - burnAmount);
    }

    function testFuzz_BatchMint_AllResourcesAssigned(uint256 woodAmount, uint256 ironAmount, uint256 gemAmount) public {
        woodAmount = bound(woodAmount, 1, type(uint64).max);
        ironAmount = bound(ironAmount, 1, type(uint64).max);
        gemAmount = bound(gemAmount, 1, type(uint64).max);

        address user = address(0xBEEF);
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = gameResources.RESOURCE_WOOD();
        ids[1] = gameResources.RESOURCE_IRON();
        ids[2] = gameResources.RESOURCE_GEM();
        amounts[0] = woodAmount;
        amounts[1] = ironAmount;
        amounts[2] = gemAmount;

        vm.prank(ADMIN);
        gameResources.mintBatch(user, ids, amounts);

        assertEq(gameResources.balanceOf(user, gameResources.RESOURCE_WOOD()), woodAmount);
        assertEq(gameResources.balanceOf(user, gameResources.RESOURCE_IRON()), ironAmount);
        assertEq(gameResources.balanceOf(user, gameResources.RESOURCE_GEM()), gemAmount);
    }
}
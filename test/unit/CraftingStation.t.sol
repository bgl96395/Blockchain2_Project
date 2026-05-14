// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { CraftingStation } from "../../src/crafting/CraftingStation.sol";
import { GameResources } from "../../src/resources/GameResources.sol";

contract CraftingStationTest is Test {
    CraftingStation public crafting;
    GameResources public gameResources;

    address public constant ADMIN_ADDRESS = address(0xAD314);
    address public constant USER_ALICE = address(0xA11CE);

    function setUp() public {
        gameResources = new GameResources("https://api.gamefi/{id}.json", ADMIN_ADDRESS);
        crafting = new CraftingStation(address(gameResources), ADMIN_ADDRESS);

        vm.startPrank(ADMIN_ADDRESS);
        gameResources.grantRole(gameResources.MINTER_ROLE(), address(crafting));
        gameResources.mintResource(USER_ALICE, gameResources.RESOURCE_WOOD(), 100);
        gameResources.mintResource(USER_ALICE, gameResources.RESOURCE_IRON(), 100);
        vm.stopPrank();
    }

    function test_RegisterRecipe_StoresRecipeData() public {
        vm.prank(ADMIN_ADDRESS);
        uint256 recipeId = crafting.registerRecipe(1, 2, 2, 1, 4, 1);
        assertEq(recipeId, 0);
    }

    function test_RegisterRecipe_RevertWhen_CallerUnauthorized() public {
        vm.prank(USER_ALICE);
        vm.expectRevert();
        crafting.registerRecipe(1, 2, 2, 1, 4, 1);
    }

    function test_CraftRecipe_ConsumesInputsAndProducesOutput() public {
        vm.prank(ADMIN_ADDRESS);
        crafting.registerRecipe(1, 2, 2, 1, 4, 1);

        vm.prank(USER_ALICE);
        gameResources.setApprovalForAll(address(crafting), true);

        vm.prank(USER_ALICE);
        crafting.craftRecipe(0);

        assertEq(gameResources.balanceOf(USER_ALICE, 1), 98);
        assertEq(gameResources.balanceOf(USER_ALICE, 2), 99);
        assertEq(gameResources.balanceOf(USER_ALICE, 4), 1);
    }

    function test_CraftRecipe_RevertWhen_RecipeDoesNotExist() public {
        vm.prank(USER_ALICE);
        vm.expectRevert(CraftingStation.RecipeDoesNotExist.selector);
        crafting.craftRecipe(999);
    }

    function test_CraftRecipe_RevertWhen_RecipeNotActive() public {
        vm.prank(ADMIN_ADDRESS);
        crafting.registerRecipe(1, 2, 2, 1, 4, 1);

        vm.prank(ADMIN_ADDRESS);
        crafting.setRecipeActiveStatus(0, false);

        vm.prank(USER_ALICE);
        vm.expectRevert(CraftingStation.RecipeIsNotActive.selector);
        crafting.craftRecipe(0);
    }

    function test_SetRecipeActiveStatus_AdminCanToggle() public {
        vm.prank(ADMIN_ADDRESS);
        crafting.registerRecipe(1, 2, 2, 1, 4, 1);

        vm.prank(ADMIN_ADDRESS);
        crafting.setRecipeActiveStatus(0, false);

        (,,,,,, bool active) = crafting.craftingRecipes(0);
        assertFalse(active);
    }
}

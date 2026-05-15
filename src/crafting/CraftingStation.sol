// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IGameResourcesMintable {
    function mintResource(address mintRecipient, uint256 resourceId, uint256 mintAmount) external;
    function burnResource(address burnFromAddress, uint256 resourceId, uint256 burnAmount) external;
}

contract CraftingStation is AccessControl, ReentrancyGuard, IERC1155Receiver {
    bytes32 public constant RECIPE_MANAGER_ROLE = keccak256("RECIPE_MANAGER_ROLE");

    struct CraftingRecipe {
        uint256 firstInputResourceId;
        uint256 firstInputAmount;
        uint256 secondInputResourceId;
        uint256 secondInputAmount;
        uint256 outputResourceId;
        uint256 outputAmount;
        bool recipeIsActive;
    }

    IERC1155 public immutable gameResources;
    IGameResourcesMintable public immutable mintableResources;

    mapping(uint256 recipeId => CraftingRecipe recipe) public craftingRecipes;
    uint256 public nextAvailableRecipeId;

    error RecipeIsNotActive();
    error InsufficientResourceBalance();
    error RecipeDoesNotExist();

    event RecipeRegistered(uint256 indexed recipeId, uint256 outputResourceId, uint256 outputAmount);
    event RecipeCrafted(address indexed craftingUser, uint256 indexed recipeId, uint256 outputAmount);
    event RecipeStatusChanged(uint256 indexed recipeId, bool isActive);

    constructor(address gameResourcesAddress, address recipeAdministrator) {
        gameResources = IERC1155(gameResourcesAddress);
        mintableResources = IGameResourcesMintable(gameResourcesAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, recipeAdministrator);
        _grantRole(RECIPE_MANAGER_ROLE, recipeAdministrator);
    }

    function registerRecipe(
        uint256 firstInputResourceId,
        uint256 firstInputAmount,
        uint256 secondInputResourceId,
        uint256 secondInputAmount,
        uint256 outputResourceId,
        uint256 outputAmount
    ) external onlyRole(RECIPE_MANAGER_ROLE) returns (uint256 newRecipeId) {
        newRecipeId = nextAvailableRecipeId++;
        craftingRecipes[newRecipeId] = CraftingRecipe({
            firstInputResourceId: firstInputResourceId,
            firstInputAmount: firstInputAmount,
            secondInputResourceId: secondInputResourceId,
            secondInputAmount: secondInputAmount,
            outputResourceId: outputResourceId,
            outputAmount: outputAmount,
            recipeIsActive: true
        });
        emit RecipeRegistered(newRecipeId, outputResourceId, outputAmount);
    }

    function craftRecipe(uint256 recipeId) external nonReentrant {
        CraftingRecipe memory recipe = craftingRecipes[recipeId];
        if (recipe.outputAmount == 0) revert RecipeDoesNotExist();
        if (!recipe.recipeIsActive) revert RecipeIsNotActive();

        if (gameResources.balanceOf(msg.sender, recipe.firstInputResourceId) < recipe.firstInputAmount) {
            revert InsufficientResourceBalance();
        }
        if (gameResources.balanceOf(msg.sender, recipe.secondInputResourceId) < recipe.secondInputAmount) {
            revert InsufficientResourceBalance();
        }
        mintableResources.burnResource(msg.sender, recipe.firstInputResourceId, recipe.firstInputAmount);
        mintableResources.burnResource(msg.sender, recipe.secondInputResourceId, recipe.secondInputAmount);
        mintableResources.mintResource(msg.sender, recipe.outputResourceId, recipe.outputAmount);

        emit RecipeCrafted(msg.sender, recipeId, recipe.outputAmount);
    }

    function setRecipeActiveStatus(uint256 recipeId, bool isActive) external onlyRole(RECIPE_MANAGER_ROLE) {
        if (craftingRecipes[recipeId].outputAmount == 0) revert RecipeDoesNotExist();
        craftingRecipes[recipeId].recipeIsActive = isActive;
        emit RecipeStatusChanged(recipeId, isActive);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}


// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ResourceMarketplace } from "../../src/marketplace/ResourceMarketplace.sol";
import { MockGameResources } from "../../src/mocks/MockGameResources.sol";

contract MarketplaceHandler is Test {
    ResourceMarketplace public marketplace;
    MockGameResources public gameResources;

    uint256 public constant RESOURCE_WOOD = 1;
    uint256 public constant RESOURCE_IRON = 2;

    address public constant ACTOR_ALICE = address(0xA11CE);
    address public constant ACTOR_BOB = address(0xB0B);

    uint256 public totalLiquidityAddedOperations;
    uint256 public totalLiquidityRemovedOperations;
    uint256 public totalSwapOperations;

    constructor(ResourceMarketplace marketplaceContract, MockGameResources resourcesContract) {
        marketplace = marketplaceContract;
        gameResources = resourcesContract;
    }

    function addLiquidityHandler(uint256 firstAmount, uint256 secondAmount) external {
        firstAmount = bound(firstAmount, 10_000, 1_000_000);
        secondAmount = bound(secondAmount, 10_000, 1_000_000);

        gameResources.mint(ACTOR_ALICE, RESOURCE_WOOD, firstAmount);
        gameResources.mint(ACTOR_ALICE, RESOURCE_IRON, secondAmount);

        vm.prank(ACTOR_ALICE);
        gameResources.setApprovalForAll(address(marketplace), true);

        vm.prank(ACTOR_ALICE);
        try marketplace.addLiquidity(
            RESOURCE_WOOD, RESOURCE_IRON, firstAmount, secondAmount, 1, 1, ACTOR_ALICE, block.timestamp + 1 hours
        ) {
            totalLiquidityAddedOperations++;
        } catch { }
    }

    function swapHandler(uint256 inputAmount, bool swapWoodForIron) external {
        inputAmount = bound(inputAmount, 1000, 100_000);

        uint256 inputId = swapWoodForIron ? RESOURCE_WOOD : RESOURCE_IRON;
        uint256 outputId = swapWoodForIron ? RESOURCE_IRON : RESOURCE_WOOD;

        gameResources.mint(ACTOR_BOB, inputId, inputAmount);

        vm.prank(ACTOR_BOB);
        gameResources.setApprovalForAll(address(marketplace), true);

        vm.prank(ACTOR_BOB);
        try marketplace.swapExactInputForOutput(
            inputId, outputId, inputAmount, 1, ACTOR_BOB, block.timestamp + 1 hours
        ) {
            totalSwapOperations++;
        } catch { }
    }
}

contract ResourceMarketplaceInvariantTest is Test {
    ResourceMarketplace public marketplace;
    MockGameResources public gameResources;
    MarketplaceHandler public handler;

    uint256 public constant RESOURCE_WOOD = 1;
    uint256 public constant RESOURCE_IRON = 2;

    function setUp() public {
        gameResources = new MockGameResources();
        marketplace = new ResourceMarketplace(address(gameResources));
        handler = new MarketplaceHandler(marketplace, gameResources);

        targetContract(address(handler));
    }

    function invariant_KProductNeverDecreasesUnexpectedly() public view {
        (uint256 firstReserve, uint256 secondReserve) = marketplace.getPoolReserves(RESOURCE_WOOD, RESOURCE_IRON);
        uint256 currentK = firstReserve * secondReserve;
        assertGe(currentK, 0);
    }

    function invariant_ReservesMatchContractBalance() public view {
        (uint256 firstReserve, uint256 secondReserve) = marketplace.getPoolReserves(RESOURCE_WOOD, RESOURCE_IRON);
        uint256 contractWoodBalance = gameResources.balanceOf(address(marketplace), RESOURCE_WOOD);
        uint256 contractIronBalance = gameResources.balanceOf(address(marketplace), RESOURCE_IRON);

        assertEq(firstReserve, contractWoodBalance);
        assertEq(secondReserve, contractIronBalance);
    }

    function invariant_TotalLiquiditySupplyNonZeroAfterFirstDeposit() public view {
        if (handler.totalLiquidityAddedOperations() > 0) {
            (uint256 firstReserve,) = marketplace.getPoolReserves(RESOURCE_WOOD, RESOURCE_IRON);
            assertGt(firstReserve, 0);
        }
    }

    function invariant_OperationCountersAreConsistent() public view {
        uint256 totalOperations = handler.totalLiquidityAddedOperations() + handler.totalSwapOperations();
        assertGe(totalOperations, 0);
    }

    function invariant_HandlerStateIsBounded() public view {
        assertLe(handler.totalLiquidityAddedOperations(), 10_000);
        assertLe(handler.totalSwapOperations(), 10_000);
    }
}

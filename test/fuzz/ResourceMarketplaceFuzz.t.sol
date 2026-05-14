// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ResourceMarketplace } from "../../src/marketplace/ResourceMarketplace.sol";
import { MockGameResources } from "../../src/mocks/MockGameResources.sol";

contract ResourceMarketplaceFuzzTest is Test {
    ResourceMarketplace public marketplace;
    MockGameResources public gameResources;

    address public constant LIQUIDITY_PROVIDER = address(0xA11CE);
    address public constant TRADER = address(0xB0B);

    uint256 public constant RESOURCE_WOOD = 1;
    uint256 public constant RESOURCE_IRON = 2;
    uint256 public constant LARGE_BALANCE = type(uint128).max;

    function setUp() public {
        gameResources = new MockGameResources();
        marketplace = new ResourceMarketplace(address(gameResources));

        gameResources.mint(LIQUIDITY_PROVIDER, RESOURCE_WOOD, LARGE_BALANCE);
        gameResources.mint(LIQUIDITY_PROVIDER, RESOURCE_IRON, LARGE_BALANCE);
        gameResources.mint(TRADER, RESOURCE_WOOD, LARGE_BALANCE);
        gameResources.mint(TRADER, RESOURCE_IRON, LARGE_BALANCE);

        vm.prank(LIQUIDITY_PROVIDER);
        gameResources.setApprovalForAll(address(marketplace), true);

        vm.prank(TRADER);
        gameResources.setApprovalForAll(address(marketplace), true);
    }

    function testFuzz_AddLiquidity_FirstDepositMintsExpectedShares(uint256 firstAmount, uint256 secondAmount) public {
        firstAmount = bound(firstAmount, 1001, 1_000_000_000_000);
        secondAmount = bound(secondAmount, 1001, 1_000_000_000_000);

        vm.prank(LIQUIDITY_PROVIDER);
        (,, uint256 liquidityMinted) = marketplace.addLiquidity(
            RESOURCE_WOOD,
            RESOURCE_IRON,
            firstAmount,
            secondAmount,
            firstAmount,
            secondAmount,
            LIQUIDITY_PROVIDER,
            block.timestamp + 1 hours
        );

        assertGt(liquidityMinted, 0);
    }

    function testFuzz_Swap_OutputAlwaysLessThanReserve(uint256 inputAmount) public {
        uint256 poolReserve = 1_000_000;

        vm.prank(LIQUIDITY_PROVIDER);
        marketplace.addLiquidity(
            RESOURCE_WOOD,
            RESOURCE_IRON,
            poolReserve,
            poolReserve,
            poolReserve,
            poolReserve,
            LIQUIDITY_PROVIDER,
            block.timestamp + 1 hours
        );

        inputAmount = bound(inputAmount, 1000, poolReserve / 2);

        vm.prank(TRADER);
        uint256 output = marketplace.swapExactInputForOutput(
            RESOURCE_WOOD, RESOURCE_IRON, inputAmount, 1, TRADER, block.timestamp + 1 hours
        );

        assertLt(output, poolReserve);
    }

    function testFuzz_Swap_KInvariantNeverDecreases(uint256 inputAmount) public {
        uint256 poolReserve = 1_000_000;

        vm.prank(LIQUIDITY_PROVIDER);
        marketplace.addLiquidity(
            RESOURCE_WOOD,
            RESOURCE_IRON,
            poolReserve,
            poolReserve,
            poolReserve,
            poolReserve,
            LIQUIDITY_PROVIDER,
            block.timestamp + 1 hours
        );

        inputAmount = bound(inputAmount, 1000, poolReserve / 2);

        uint256 kBefore = poolReserve * poolReserve;

        vm.prank(TRADER);
        marketplace.swapExactInputForOutput(
            RESOURCE_WOOD, RESOURCE_IRON, inputAmount, 1, TRADER, block.timestamp + 1 hours
        );

        (uint256 firstReserve, uint256 secondReserve) = marketplace.getPoolReserves(RESOURCE_WOOD, RESOURCE_IRON);
        uint256 kAfter = firstReserve * secondReserve;

        assertGe(kAfter, kBefore);
    }

    function testFuzz_RemoveLiquidity_ReturnsNoMoreThanDeposited(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1001, 1_000_000_000);

        vm.prank(LIQUIDITY_PROVIDER);
        (,, uint256 liquidityMinted) = marketplace.addLiquidity(
            RESOURCE_WOOD,
            RESOURCE_IRON,
            depositAmount,
            depositAmount,
            depositAmount,
            depositAmount,
            LIQUIDITY_PROVIDER,
            block.timestamp + 1 hours
        );

        vm.prank(LIQUIDITY_PROVIDER);
        (uint256 withdrawn1, uint256 withdrawn2) = marketplace.removeLiquidity(
            RESOURCE_WOOD, RESOURCE_IRON, liquidityMinted, 1, 1, LIQUIDITY_PROVIDER, block.timestamp + 1 hours
        );

        assertLe(withdrawn1, depositAmount);
        assertLe(withdrawn2, depositAmount);
    }
}

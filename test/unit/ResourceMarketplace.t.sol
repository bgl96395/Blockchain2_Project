// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ResourceMarketplace } from "../../src/marketplace/ResourceMarketplace.sol";
import { MockGameResources } from "../../src/mocks/MockGameResources.sol";

contract ResourceMarketplaceTest is Test {
    ResourceMarketplace public marketplace;
    MockGameResources public gameResources;

    address public constant LIQUIDITY_PROVIDER_ALICE = address(0xA11CE);
    address public constant TRADER_BOB = address(0xB0B);

    uint256 public constant RESOURCE_WOOD_ID = 1;
    uint256 public constant RESOURCE_IRON_ID = 2;
    uint256 public constant INITIAL_RESOURCE_MINT_AMOUNT = 1_000_000;

    function setUp() public {
        gameResources = new MockGameResources();
        marketplace = new ResourceMarketplace(address(gameResources));

        gameResources.mint(LIQUIDITY_PROVIDER_ALICE, RESOURCE_WOOD_ID, INITIAL_RESOURCE_MINT_AMOUNT);
        gameResources.mint(LIQUIDITY_PROVIDER_ALICE, RESOURCE_IRON_ID, INITIAL_RESOURCE_MINT_AMOUNT);
        gameResources.mint(TRADER_BOB, RESOURCE_WOOD_ID, INITIAL_RESOURCE_MINT_AMOUNT);
        gameResources.mint(TRADER_BOB, RESOURCE_IRON_ID, INITIAL_RESOURCE_MINT_AMOUNT);

        vm.prank(LIQUIDITY_PROVIDER_ALICE);
        gameResources.setApprovalForAll(address(marketplace), true);

        vm.prank(TRADER_BOB);
        gameResources.setApprovalForAll(address(marketplace), true);
    }

    function test_AddLiquidity_FirstProviderReceivesSquareRootMinusMinimum() public {
        uint256 firstAmount = 10_000;
        uint256 secondAmount = 40_000;

        vm.prank(LIQUIDITY_PROVIDER_ALICE);
        (uint256 deposited1, uint256 deposited2, uint256 liquidityMinted) = marketplace.addLiquidity(
            RESOURCE_WOOD_ID,
            RESOURCE_IRON_ID,
            firstAmount,
            secondAmount,
            firstAmount,
            secondAmount,
            LIQUIDITY_PROVIDER_ALICE,
            block.timestamp + 1 hours
        );

        assertEq(deposited1, firstAmount);
        assertEq(deposited2, secondAmount);
        assertEq(liquidityMinted, 20_000 - marketplace.MINIMUM_LIQUIDITY());
    }

    function test_AddLiquidity_RevertWhen_DeadlineExpired() public {
        vm.warp(block.timestamp + 2 hours);

        vm.prank(LIQUIDITY_PROVIDER_ALICE);
        vm.expectRevert(ResourceMarketplace.TransactionDeadlineExpired.selector);
        marketplace.addLiquidity(
            RESOURCE_WOOD_ID,
            RESOURCE_IRON_ID,
            10_000,
            40_000,
            10_000,
            40_000,
            LIQUIDITY_PROVIDER_ALICE,
            block.timestamp - 1 hours
        );
    }

    function test_Swap_OutputAmountMatchesConstantProductFormula() public {
        vm.prank(LIQUIDITY_PROVIDER_ALICE);
        marketplace.addLiquidity(
            RESOURCE_WOOD_ID,
            RESOURCE_IRON_ID,
            100_000,
            100_000,
            100_000,
            100_000,
            LIQUIDITY_PROVIDER_ALICE,
            block.timestamp + 1 hours
        );

        uint256 swapInputAmount = 1000;

        vm.prank(TRADER_BOB);
        uint256 actualOutput = marketplace.swapExactInputForOutput(
            RESOURCE_WOOD_ID, RESOURCE_IRON_ID, swapInputAmount, 1, TRADER_BOB, block.timestamp + 1 hours
        );

        uint256 inputWithFee = swapInputAmount * 997;
        uint256 expectedOutput = (inputWithFee * 100_000) / ((100_000 * 1000) + inputWithFee);
        assertEq(actualOutput, expectedOutput);
    }

    function test_RemoveLiquidity_ReturnsProportionalAmounts() public {
        vm.prank(LIQUIDITY_PROVIDER_ALICE);
        (,, uint256 liquidityMinted) = marketplace.addLiquidity(
            RESOURCE_WOOD_ID,
            RESOURCE_IRON_ID,
            50_000,
            50_000,
            50_000,
            50_000,
            LIQUIDITY_PROVIDER_ALICE,
            block.timestamp + 1 hours
        );

        vm.prank(LIQUIDITY_PROVIDER_ALICE);
        (uint256 withdrawn1, uint256 withdrawn2) = marketplace.removeLiquidity(
            RESOURCE_WOOD_ID,
            RESOURCE_IRON_ID,
            liquidityMinted,
            1,
            1,
            LIQUIDITY_PROVIDER_ALICE,
            block.timestamp + 1 hours
        );

        assertGt(withdrawn1, 0);
        assertGt(withdrawn2, 0);
    }

    function test_Swap_RevertWhen_PoolDoesNotExist() public {
        vm.prank(TRADER_BOB);
        vm.expectRevert(ResourceMarketplace.PoolDoesNotExist.selector);
        marketplace.swapExactInputForOutput(
            RESOURCE_WOOD_ID, RESOURCE_IRON_ID, 1000, 1, TRADER_BOB, block.timestamp + 1 hours
        );
    }
}

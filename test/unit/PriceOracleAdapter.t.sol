// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { PriceOracleAdapter } from "../../src/oracle/PriceOracleAdapter.sol";
import { MockAggregatorV3 } from "../../src/mocks/MockAggregatorV3.sol";

contract PriceOracleAdapterTest is Test {
    PriceOracleAdapter public oracleAdapter;
    MockAggregatorV3 public mockPriceFeed;

    address public constant ORACLE_ADMINISTRATOR = address(0xAD314);
    address public constant UNAUTHORIZED_USER = address(0xBAD);
    address public constant ASSET_ADDRESS = address(0xA55E7);
    uint256 public constant MAXIMUM_STALENESS = 3600;

    function setUp() public {
        oracleAdapter = new PriceOracleAdapter(MAXIMUM_STALENESS, ORACLE_ADMINISTRATOR);
        mockPriceFeed = new MockAggregatorV3(8, 2000 * 10 ** 8);
    }

    function test_RegisterPriceFeed_StoresFeedAddress() public {
        vm.prank(ORACLE_ADMINISTRATOR);
        oracleAdapter.registerPriceFeed(ASSET_ADDRESS, address(mockPriceFeed));

        assertEq(address(oracleAdapter.priceFeedForAsset(ASSET_ADDRESS)), address(mockPriceFeed));
    }

    function test_RegisterPriceFeed_RevertWhen_CallerUnauthorized() public {
        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert();
        oracleAdapter.registerPriceFeed(ASSET_ADDRESS, address(mockPriceFeed));
    }

    function test_GetLatestPrice_ScalesEightDecimalsToEighteen() public {
        vm.prank(ORACLE_ADMINISTRATOR);
        oracleAdapter.registerPriceFeed(ASSET_ADDRESS, address(mockPriceFeed));

        uint256 price = oracleAdapter.getLatestPriceWithStalenessCheck(ASSET_ADDRESS);
        assertEq(price, 2000 * 10 ** 18);
    }

    function test_GetLatestPrice_RevertWhen_FeedNotConfigured() public {
        vm.expectRevert(PriceOracleAdapter.PriceFeedNotConfigured.selector);
        oracleAdapter.getLatestPriceWithStalenessCheck(ASSET_ADDRESS);
    }

    function test_GetLatestPrice_RevertWhen_PriceIsZeroOrNegative() public {
        mockPriceFeed.setPrice(0);

        vm.prank(ORACLE_ADMINISTRATOR);
        oracleAdapter.registerPriceFeed(ASSET_ADDRESS, address(mockPriceFeed));

        vm.expectRevert(PriceOracleAdapter.PriceFeedReturnedZeroOrNegative.selector);
        oracleAdapter.getLatestPriceWithStalenessCheck(ASSET_ADDRESS);
    }

    function test_GetLatestPrice_RevertWhen_PriceIsNegative() public {
        mockPriceFeed.setPrice(-100);

        vm.prank(ORACLE_ADMINISTRATOR);
        oracleAdapter.registerPriceFeed(ASSET_ADDRESS, address(mockPriceFeed));

        vm.expectRevert(PriceOracleAdapter.PriceFeedReturnedZeroOrNegative.selector);
        oracleAdapter.getLatestPriceWithStalenessCheck(ASSET_ADDRESS);
    }

    function test_GetLatestPrice_RevertWhen_DataIsStale() public {
        vm.prank(ORACLE_ADMINISTRATOR);
        oracleAdapter.registerPriceFeed(ASSET_ADDRESS, address(mockPriceFeed));

        vm.warp(block.timestamp + MAXIMUM_STALENESS + 1);

        vm.expectRevert();
        oracleAdapter.getLatestPriceWithStalenessCheck(ASSET_ADDRESS);
    }

    function test_SetMaximumStaleness_UpdatesValue() public {
        vm.prank(ORACLE_ADMINISTRATOR);
        oracleAdapter.setMaximumStaleness(7200);

        assertEq(oracleAdapter.getMaximumStalenessSeconds(), 7200);
    }

    function test_SetMaximumStaleness_RevertWhen_CallerUnauthorized() public {
        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert();
        oracleAdapter.setMaximumStaleness(7200);
    }

    function test_PriceUpdate_AfterStalenessReverts_FreshDataPasses() public {
        vm.prank(ORACLE_ADMINISTRATOR);
        oracleAdapter.registerPriceFeed(ASSET_ADDRESS, address(mockPriceFeed));

        vm.warp(block.timestamp + MAXIMUM_STALENESS + 1);

        mockPriceFeed.setPrice(2500 * 10 ** 8);

        uint256 price = oracleAdapter.getLatestPriceWithStalenessCheck(ASSET_ADDRESS);
        assertEq(price, 2500 * 10 ** 18);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { PriceOracleAdapter } from "../../src/oracle/PriceOracleAdapter.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PriceOracleForkTest is Test {
    PriceOracleAdapter public oracleAdapter;

    address public constant ORACLE_ADMINISTRATOR = address(0xAD314);
    address public constant BASE_SEPOLIA_ETH_USD_FEED = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
    address public constant SIMULATED_ETH_ASSET = address(0xE71);

    uint256 public constant MAXIMUM_STALENESS_FOR_TESTNET = 86_400;

    function setUp() public {
        try vm.envString("BASE_SEPOLIA_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl);
        } catch {
            vm.skip(true);
        }

        oracleAdapter = new PriceOracleAdapter(MAXIMUM_STALENESS_FOR_TESTNET, ORACLE_ADMINISTRATOR);
    }

    function test_Fork_ChainlinkFeedReturnsPrice() public {
        vm.prank(ORACLE_ADMINISTRATOR);
        oracleAdapter.registerPriceFeed(SIMULATED_ETH_ASSET, BASE_SEPOLIA_ETH_USD_FEED);

        uint256 price = oracleAdapter.getLatestPriceWithStalenessCheck(SIMULATED_ETH_ASSET);

        assertGt(price, 0);
        assertLt(price, 100_000 * 10 ** 18);
    }

    function test_Fork_ChainlinkFeedHasCorrectDecimals() public view {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(BASE_SEPOLIA_ETH_USD_FEED);
        uint8 decimals = priceFeed.decimals();
        assertEq(decimals, 8);
    }

    function test_Fork_ChainlinkFeedReturnsRecentData() public view {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(BASE_SEPOLIA_ETH_USD_FEED);
        (, , , uint256 updatedAt, ) = priceFeed.latestRoundData();

        assertGt(updatedAt, 0);
    }
}
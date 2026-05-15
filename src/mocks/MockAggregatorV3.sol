// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockAggregatorV3 is AggregatorV3Interface {
    uint8 private feedDecimals;
    int256 private currentPrice;
    uint256 private lastUpdate;
    uint80 private currentRoundId;

    constructor(uint8 decimalsValue, int256 initialPrice) {
        feedDecimals = decimalsValue;
        currentPrice = initialPrice;
        lastUpdate = block.timestamp;
        currentRoundId = 1;
    }

    function setPrice(int256 newPrice) external {
        currentPrice = newPrice;
        lastUpdate = block.timestamp;
        currentRoundId++;
    }

    function setLastUpdate(uint256 newTimestamp) external {
        lastUpdate = newTimestamp;
    }

    function decimals() external view override returns (uint8) {
        return feedDecimals;
    }

    function description() external pure override returns (string memory) {
        return "Mock Price Feed";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 roundId) external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, currentPrice, lastUpdate, lastUpdate, roundId);
    }

    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (currentRoundId, currentPrice, lastUpdate, lastUpdate, currentRoundId);
    }
}

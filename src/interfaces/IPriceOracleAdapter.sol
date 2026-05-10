// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IPriceOracleAdapter {
    error PriceFeedReturnedZeroOrNegative();
    error PriceFeedDataIsStale(uint256 lastUpdatedTimestamp, uint256 currentTimestamp);
    error PriceFeedRoundIncomplete();

    function getLatestPriceWithStalenessCheck(address assetAddress)
        external
        view
        returns (uint256 priceScaledToEighteenDecimals);

    function getMaximumStalenessSeconds() external view returns (uint256);
}

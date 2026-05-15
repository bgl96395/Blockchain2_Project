// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract PriceOracleAdapter is AccessControl {
    bytes32 public constant FEED_MANAGER_ROLE = keccak256("FEED_MANAGER_ROLE");

    uint256 public maximumStalenessSeconds;

    mapping(address assetAddress => AggregatorV3Interface priceFeed) public priceFeedForAsset;

    error PriceFeedReturnedZeroOrNegative();
    error PriceFeedDataIsStale(uint256 lastUpdatedTimestamp, uint256 currentTimestamp);
    error PriceFeedRoundIncomplete();
    error PriceFeedNotConfigured();

    event PriceFeedRegistered(address indexed assetAddress, address indexed priceFeedAddress);
    event MaximumStalenessUpdated(uint256 oldStaleness, uint256 newStaleness);

    constructor(uint256 initialMaximumStaleness, address oracleAdministrator) {
        maximumStalenessSeconds = initialMaximumStaleness;
        _grantRole(DEFAULT_ADMIN_ROLE, oracleAdministrator);
        _grantRole(FEED_MANAGER_ROLE, oracleAdministrator);
    }

    function registerPriceFeed(address assetAddress, address priceFeedAddress) external onlyRole(FEED_MANAGER_ROLE) {
        priceFeedForAsset[assetAddress] = AggregatorV3Interface(priceFeedAddress);
        emit PriceFeedRegistered(assetAddress, priceFeedAddress);
    }

    function setMaximumStaleness(uint256 newMaximumStaleness) external onlyRole(FEED_MANAGER_ROLE) {
        uint256 oldStaleness = maximumStalenessSeconds;
        maximumStalenessSeconds = newMaximumStaleness;
        emit MaximumStalenessUpdated(oldStaleness, newMaximumStaleness);
    }

    function getLatestPriceWithStalenessCheck(address assetAddress)
        external
        view
        returns (uint256 priceScaledToEighteenDecimals)
    {
        AggregatorV3Interface priceFeed = priceFeedForAsset[assetAddress];
        if (address(priceFeed) == address(0)) revert PriceFeedNotConfigured();

        (uint80 roundId, int256 rawPrice,, uint256 lastUpdatedTimestamp, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        if (rawPrice <= 0) revert PriceFeedReturnedZeroOrNegative();
        if (answeredInRound < roundId) revert PriceFeedRoundIncomplete();
        if (block.timestamp - lastUpdatedTimestamp > maximumStalenessSeconds) {
            revert PriceFeedDataIsStale(lastUpdatedTimestamp, block.timestamp);
        }

        uint8 feedDecimals = priceFeed.decimals();
        priceScaledToEighteenDecimals = uint256(rawPrice) * (10 ** (18 - feedDecimals));
    }

    function getMaximumStalenessSeconds() external view returns (uint256) {
        return maximumStalenessSeconds;
    }
}

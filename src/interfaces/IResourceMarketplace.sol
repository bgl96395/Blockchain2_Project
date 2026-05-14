// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IResourceMarketplace {
    event LiquidityAdded(
        address indexed liquidityProvider,
        uint256 firstResourceId,
        uint256 secondResourceId,
        uint256 firstResourceAmount,
        uint256 secondResourceAmount,
        uint256 liquidityTokensMinted
    );

    event LiquidityRemoved(
        address indexed liquidityProvider,
        uint256 firstResourceId,
        uint256 secondResourceId,
        uint256 firstResourceAmount,
        uint256 secondResourceAmount,
        uint256 liquidityTokensBurned
    );

    event ResourcesSwapped(
        address indexed swapInitiator,
        uint256 indexed inputResourceId,
        uint256 indexed outputResourceId,
        uint256 inputResourceAmount,
        uint256 outputResourceAmount
    );

    function addLiquidity(
        uint256 firstResourceId,
        uint256 secondResourceId,
        uint256 firstResourceAmountDesired,
        uint256 secondResourceAmountDesired,
        uint256 firstResourceAmountMinimum,
        uint256 secondResourceAmountMinimum,
        address liquidityRecipient,
        uint256 transactionDeadline
    )
        external
        returns (
            uint256 firstResourceAmountDeposited,
            uint256 secondResourceAmountDeposited,
            uint256 liquidityTokensMinted
        );

    function removeLiquidity(
        uint256 firstResourceId,
        uint256 secondResourceId,
        uint256 liquidityTokensToBurn,
        uint256 firstResourceAmountMinimum,
        uint256 secondResourceAmountMinimum,
        address resourceRecipient,
        uint256 transactionDeadline
    ) external returns (uint256 firstResourceAmountWithdrawn, uint256 secondResourceAmountWithdrawn);

    function swapExactInputForOutput(
        uint256 inputResourceId,
        uint256 outputResourceId,
        uint256 inputResourceAmount,
        uint256 minimumOutputResourceAmount,
        address outputRecipient,
        uint256 transactionDeadline
    ) external returns (uint256 outputResourceAmount);

    function getPoolReserves(uint256 firstResourceId, uint256 secondResourceId)
        external
        view
        returns (uint256 firstReserve, uint256 secondReserve);
}

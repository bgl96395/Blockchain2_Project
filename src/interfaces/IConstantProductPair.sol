// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IConstantProductPair {
    event LiquidityAdded(
        address indexed liquidityProvider,
        uint256 firstTokenAmountDeposited,
        uint256 secondTokenAmountDeposited,
        uint256 liquidityTokensMinted
    );

    event LiquidityRemoved(
        address indexed liquidityProvider,
        uint256 firstTokenAmountWithdrawn,
        uint256 secondTokenAmountWithdrawn,
        uint256 liquidityTokensBurned
    );

    event TokensSwapped(
        address indexed swapInitiator,
        address indexed inputTokenAddress,
        uint256 inputTokenAmount,
        uint256 outputTokenAmount
    );

    event ReservesSynchronized(uint112 firstTokenReserve, uint112 secondTokenReserve);

    function addLiquidity(
        uint256 firstTokenAmountDesired,
        uint256 secondTokenAmountDesired,
        uint256 firstTokenAmountMinimum,
        uint256 secondTokenAmountMinimum,
        address liquidityRecipient,
        uint256 transactionDeadline
    ) external returns (uint256 firstTokenAmountDeposited, uint256 secondTokenAmountDeposited, uint256 liquidityTokensMinted);

    function removeLiquidity(
        uint256 liquidityTokensToBurn,
        uint256 firstTokenAmountMinimum,
        uint256 secondTokenAmountMinimum,
        address tokenRecipient,
        uint256 transactionDeadline
    ) external returns (uint256 firstTokenAmountWithdrawn, uint256 secondTokenAmountWithdrawn);

    function swapExactInputForOutput(
        uint256 inputTokenAmount,
        uint256 minimumOutputTokenAmount,
        address inputTokenAddress,
        address outputRecipient,
        uint256 transactionDeadline
    ) external returns (uint256 outputTokenAmount);

    function getReserves()
        external
        view
        returns (uint112 firstTokenReserve, uint112 secondTokenReserve, uint32 lastBlockTimestamp);

    function firstToken() external view returns (address);

    function secondToken() external view returns (address);
}

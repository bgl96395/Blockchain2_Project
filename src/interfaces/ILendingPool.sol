// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ILendingPool {
    event CollateralDeposited(address indexed depositor, uint256 collateralAmount);
    event CollateralWithdrawn(address indexed withdrawer, uint256 collateralAmount);
    event AssetBorrowed(address indexed borrower, uint256 borrowedAmount);
    event LoanRepaid(address indexed repayer, address indexed borrower, uint256 repaidAmount);
    event PositionLiquidated(
        address indexed liquidator,
        address indexed liquidatedBorrower,
        uint256 collateralSeizedAmount,
        uint256 debtRepaidAmount
    );

    function depositCollateral(uint256 collateralAmount) external;

    function withdrawCollateral(uint256 collateralAmount) external;

    function borrow(uint256 amountToBorrow) external;

    function repay(uint256 amountToRepay, address borrowerToRepayFor) external;

    function liquidate(address borrowerToLiquidate, uint256 debtAmountToCover) external;

    function getHealthFactor(address borrower) external view returns (uint256 healthFactorScaled);

    function getCollateralValueInQuoteToken(address borrower) external view returns (uint256);

    function getOutstandingDebt(address borrower) external view returns (uint256);
}

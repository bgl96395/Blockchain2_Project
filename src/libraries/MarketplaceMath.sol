// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library MarketplaceMath {
    error InsufficientInputAmount();
    error InsufficientReserves();

    function getAmountOutPureSolidity(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve)
        internal
        pure
        returns (uint256 outputAmount)
    {
        if (inputAmount == 0) revert InsufficientInputAmount();
        if (inputReserve == 0 || outputReserve == 0) revert InsufficientReserves();

        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;
        outputAmount = numerator / denominator;
    }

    function getAmountOutYulOptimized(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve)
        internal
        pure
        returns (uint256 outputAmount)
    {
        assembly {
            if iszero(inputAmount) {
                mstore(0x00, 0x098fb56100000000000000000000000000000000000000000000000000000000)
                revert(0x00, 0x04)
            }
            if or(iszero(inputReserve), iszero(outputReserve)) {
                mstore(0x00, 0x5b6c10ab00000000000000000000000000000000000000000000000000000000)
                revert(0x00, 0x04)
            }

            let inputAmountWithFee := mul(inputAmount, 997)
            let numerator := mul(inputAmountWithFee, outputReserve)
            let denominator := add(mul(inputReserve, 1000), inputAmountWithFee)
            outputAmount := div(numerator, denominator)
        }
    }
}

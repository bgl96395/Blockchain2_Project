// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MarketplaceMath } from "../../src/libraries/MarketplaceMath.sol";

contract MarketplaceMathTest is Test {
    function test_GetAmountOutPureSolidity_BasicCalculation() public pure {
        uint256 inputAmount = 1000;
        uint256 inputReserve = 10000;
        uint256 outputReserve = 10000;
        uint256 expectedOutput = MarketplaceMath.getAmountOutPureSolidity(inputAmount, inputReserve, outputReserve);
        assertGt(expectedOutput, 0);
        assertLt(expectedOutput, outputReserve);
    }

    function test_GetAmountOutYulOptimized_BasicCalculation() public pure {
        uint256 inputAmount = 1000;
        uint256 inputReserve = 10000;
        uint256 outputReserve = 10000;
        uint256 expectedOutput = MarketplaceMath.getAmountOutYulOptimized(inputAmount, inputReserve, outputReserve);
        assertGt(expectedOutput, 0);
        assertLt(expectedOutput, outputReserve);
    }

    function test_BothImplementations_ProduceIdenticalResults() public pure {
        uint256 inputAmount = 5000;
        uint256 inputReserve = 100000;
        uint256 outputReserve = 50000;
        uint256 pureResult = MarketplaceMath.getAmountOutPureSolidity(inputAmount, inputReserve, outputReserve);
        uint256 yulResult = MarketplaceMath.getAmountOutYulOptimized(inputAmount, inputReserve, outputReserve);
        assertEq(pureResult, yulResult);
    }

    function test_LargeAmounts_ProduceIdenticalResults() public pure {
        uint256 inputAmount = 1_000_000 ether;
        uint256 inputReserve = 10_000_000 ether;
        uint256 outputReserve = 10_000_000 ether;
        uint256 pureResult = MarketplaceMath.getAmountOutPureSolidity(inputAmount, inputReserve, outputReserve);
        uint256 yulResult = MarketplaceMath.getAmountOutYulOptimized(inputAmount, inputReserve, outputReserve);
        assertEq(pureResult, yulResult);
    }

    function test_SmallAmounts_ProduceIdenticalResults() public pure {
        uint256 inputAmount = 100;
        uint256 inputReserve = 1000;
        uint256 outputReserve = 1000;
        uint256 pureResult = MarketplaceMath.getAmountOutPureSolidity(inputAmount, inputReserve, outputReserve);
        uint256 yulResult = MarketplaceMath.getAmountOutYulOptimized(inputAmount, inputReserve, outputReserve);
        assertEq(pureResult, yulResult);
    }

    function testFuzz_BothImplementations_AlwaysEqual(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure {
        inputAmount = bound(inputAmount, 1, type(uint96).max);
        inputReserve = bound(inputReserve, 1000, type(uint96).max);
        outputReserve = bound(outputReserve, 1000, type(uint96).max);

        uint256 pureResult = MarketplaceMath.getAmountOutPureSolidity(inputAmount, inputReserve, outputReserve);
        uint256 yulResult = MarketplaceMath.getAmountOutYulOptimized(inputAmount, inputReserve, outputReserve);
        assertEq(pureResult, yulResult);
    }

    function testFuzz_OutputAlwaysLessThanOutputReserve(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure {
        inputAmount = bound(inputAmount, 1, type(uint96).max);
        inputReserve = bound(inputReserve, 1000, type(uint96).max);
        outputReserve = bound(outputReserve, 1000, type(uint96).max);

        uint256 result = MarketplaceMath.getAmountOutPureSolidity(inputAmount, inputReserve, outputReserve);
        assertLt(result, outputReserve);
    }
}
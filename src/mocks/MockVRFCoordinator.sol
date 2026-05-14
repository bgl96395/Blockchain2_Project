// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ILootBoxConsumer {
    function fulfillRandomWords(uint256 requestId, uint256 randomValue) external;
}

contract MockVRFCoordinator {
    address public registeredConsumer;
    uint256 public nextRandomValue;

    function setConsumer(address consumerAddress) external {
        registeredConsumer = consumerAddress;
    }

    function setNextRandomValue(uint256 randomValue) external {
        nextRandomValue = randomValue;
    }

    function requestRandomWords(uint256 requestId, uint32) external returns (uint256) {
        ILootBoxConsumer(registeredConsumer).fulfillRandomWords(requestId, nextRandomValue);
        return requestId;
    }
}

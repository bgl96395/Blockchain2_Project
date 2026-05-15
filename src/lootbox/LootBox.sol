// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IVRFCoordinator {
    function requestRandomWords(uint256 requestId, uint32 callbackGasLimit) external returns (uint256);
}

interface IGameResourcesMinter {
    function mintResource(address mintRecipient, uint256 resourceId, uint256 mintAmount) external;
    function burnResource(address burnFromAddress, uint256 resourceId, uint256 burnAmount) external;
}

contract LootBox is AccessControl, ReentrancyGuard {
    bytes32 public constant DROP_RATE_MANAGER_ROLE = keccak256("DROP_RATE_MANAGER_ROLE");

    IVRFCoordinator public immutable vrfCoordinator;
    IGameResourcesMinter public immutable gameResources;

    uint256 public lootBoxOpeningCostInWood;
    uint32 public immutable callbackGasLimit;
    uint256 public nextRequestId;

    uint256[5] public possibleRewardResourceIds;
    uint256[5] public dropProbabilityWeights;
    uint256 public totalProbabilityWeight;

    struct PendingLootRequest {
        address requester;
        bool fulfilled;
    }

    mapping(uint256 requestId => PendingLootRequest request) public pendingRequests;

    error InsufficientWoodForLootBox();
    error RequestAlreadyFulfilled();
    error CallerIsNotCoordinator();
    error InvalidProbabilityWeights();

    event LootBoxRequested(uint256 indexed requestId, address indexed requester);
    event LootBoxFulfilled(uint256 indexed requestId, address indexed requester, uint256 awardedResourceId);
    event DropRatesUpdated(uint256[5] newWeights);

    constructor(
        address vrfCoordinatorAddress,
        address gameResourcesAddress,
        uint256 openingCostInWood,
        address lootBoxAdministrator
    ) {
        vrfCoordinator = IVRFCoordinator(vrfCoordinatorAddress);
        gameResources = IGameResourcesMinter(gameResourcesAddress);
        lootBoxOpeningCostInWood = openingCostInWood;
        callbackGasLimit = 200_000;

        possibleRewardResourceIds = [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5)];
        dropProbabilityWeights = [uint256(50), uint256(30), uint256(15), uint256(4), uint256(1)];
        totalProbabilityWeight = 100;

        _grantRole(DEFAULT_ADMIN_ROLE, lootBoxAdministrator);
        _grantRole(DROP_RATE_MANAGER_ROLE, lootBoxAdministrator);
    }

    function openLootBox() external nonReentrant returns (uint256 requestId) {
        requestId = nextRequestId++;
        pendingRequests[requestId] = PendingLootRequest({ requester: msg.sender, fulfilled: false });

        gameResources.burnResource(msg.sender, 1, lootBoxOpeningCostInWood);
        vrfCoordinator.requestRandomWords(requestId, callbackGasLimit);

        emit LootBoxRequested(requestId, msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256 randomValue) external {
        if (msg.sender != address(vrfCoordinator)) revert CallerIsNotCoordinator();

        PendingLootRequest storage request = pendingRequests[requestId];
        if (request.fulfilled) revert RequestAlreadyFulfilled();

        request.fulfilled = true;

        uint256 rolledValue = randomValue % totalProbabilityWeight;
        uint256 awardedResourceId = _determineRewardFromRoll(rolledValue);

        gameResources.mintResource(request.requester, awardedResourceId, 1);

        emit LootBoxFulfilled(requestId, request.requester, awardedResourceId);
    }

    function _determineRewardFromRoll(uint256 rolledValue) private view returns (uint256 awardedResourceId) {
        uint256 cumulativeWeight = 0;
        for (uint256 i = 0; i < 5; i++) {
            cumulativeWeight += dropProbabilityWeights[i];
            if (rolledValue < cumulativeWeight) {
                return possibleRewardResourceIds[i];
            }
        }
        return possibleRewardResourceIds[4];
    }

    function updateDropProbabilities(uint256[5] calldata newWeights) external onlyRole(DROP_RATE_MANAGER_ROLE) {
        uint256 weightSum = 0;
        for (uint256 i = 0; i < 5; i++) {
            weightSum += newWeights[i];
        }
        if (weightSum == 0) revert InvalidProbabilityWeights();

        dropProbabilityWeights = newWeights;
        totalProbabilityWeight = weightSum;

        emit DropRatesUpdated(newWeights);
    }

    function setLootBoxCost(uint256 newCost) external onlyRole(DROP_RATE_MANAGER_ROLE) {
        lootBoxOpeningCostInWood = newCost;
    }
}

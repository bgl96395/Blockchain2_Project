// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { LootBox } from "../../src/lootbox/LootBox.sol";
import { MockVRFCoordinator } from "../../src/mocks/MockVRFCoordinator.sol";

contract MockGameResourcesForLoot {
    mapping(address => mapping(uint256 => uint256)) public balances;

    function mintResource(address mintRecipient, uint256 resourceId, uint256 mintAmount) external {
        balances[mintRecipient][resourceId] += mintAmount;
    }

    function burnResource(address burnFromAddress, uint256 resourceId, uint256 burnAmount) external {
        require(balances[burnFromAddress][resourceId] >= burnAmount, "insufficient");
        balances[burnFromAddress][resourceId] -= burnAmount;
    }

    function balanceOf(address account, uint256 resourceId) external view returns (uint256) {
        return balances[account][resourceId];
    }
}

contract LootBoxTest is Test {
    LootBox public lootBox;
    MockVRFCoordinator public mockCoordinator;
    MockGameResourcesForLoot public mockResources;

    address public constant ADMIN_ADDRESS = address(0xAD314);
    address public constant USER_ALICE = address(0xA11CE);

    uint256 public constant OPENING_COST = 100;

    function setUp() public {
        mockCoordinator = new MockVRFCoordinator();
        mockResources = new MockGameResourcesForLoot();
        lootBox = new LootBox(address(mockCoordinator), address(mockResources), OPENING_COST, ADMIN_ADDRESS);
        mockCoordinator.setConsumer(address(lootBox));

        mockResources.mintResource(USER_ALICE, 1, 10_000);
    }

    function test_Constructor_SetsInitialState() public view {
        assertEq(address(lootBox.vrfCoordinator()), address(mockCoordinator));
        assertEq(lootBox.lootBoxOpeningCostInWood(), OPENING_COST);
        assertEq(lootBox.totalProbabilityWeight(), 100);
    }

    function test_OpenLootBox_BurnsWoodAndCreatesRequest() public {
        mockCoordinator.setNextRandomValue(0);

        vm.prank(USER_ALICE);
        uint256 requestId = lootBox.openLootBox();

        assertEq(mockResources.balanceOf(USER_ALICE, 1), 10_000 - OPENING_COST + 1);
        assertEq(requestId, 0);
    }

    function test_OpenLootBox_FulfilledImmediately_AwardsCommonResource() public {
        mockCoordinator.setNextRandomValue(10);

        vm.prank(USER_ALICE);
        lootBox.openLootBox();

        assertEq(mockResources.balanceOf(USER_ALICE, 1), 10_000 - OPENING_COST + 1);
    }

    function test_OpenLootBox_FulfilledWithRareRoll_AwardsRareResource() public {
        mockCoordinator.setNextRandomValue(99);

        vm.prank(USER_ALICE);
        lootBox.openLootBox();

        assertEq(mockResources.balanceOf(USER_ALICE, 5), 1);
    }

    function test_FulfillRandomWords_RevertWhen_NotCoordinator() public {
        vm.prank(USER_ALICE);
        vm.expectRevert(LootBox.CallerIsNotCoordinator.selector);
        lootBox.fulfillRandomWords(0, 50);
    }

    function test_UpdateDropProbabilities_AdminCanModify() public {
        uint256[5] memory newWeights = [uint256(20), uint256(20), uint256(20), uint256(20), uint256(20)];

        vm.prank(ADMIN_ADDRESS);
        lootBox.updateDropProbabilities(newWeights);

        assertEq(lootBox.totalProbabilityWeight(), 100);
        assertEq(lootBox.dropProbabilityWeights(0), 20);
    }

    function test_UpdateDropProbabilities_RevertWhen_AllZeroWeights() public {
        uint256[5] memory zeroWeights = [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)];

        vm.prank(ADMIN_ADDRESS);
        vm.expectRevert(LootBox.InvalidProbabilityWeights.selector);
        lootBox.updateDropProbabilities(zeroWeights);
    }

    function test_UpdateDropProbabilities_RevertWhen_CallerUnauthorized() public {
        uint256[5] memory newWeights = [uint256(20), uint256(20), uint256(20), uint256(20), uint256(20)];

        vm.prank(USER_ALICE);
        vm.expectRevert();
        lootBox.updateDropProbabilities(newWeights);
    }

    function test_SetLootBoxCost_AdminCanModify() public {
        vm.prank(ADMIN_ADDRESS);
        lootBox.setLootBoxCost(500);

        assertEq(lootBox.lootBoxOpeningCostInWood(), 500);
    }
}

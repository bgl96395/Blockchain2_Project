// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { GameToken } from "../../src/governance/GameToken.sol";
import { GameTimelock } from "../../src/governance/GameTimelock.sol";
import { GameGovernor } from "../../src/governance/GameGovernor.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernanceTest is Test {
    GameToken public governanceToken;
    GameTimelock public timelock;
    GameGovernor public governor;

    address public constant TOKEN_ADMIN = address(0xAD314);
    address public constant VOTER_ALICE = address(0xA11CE);
    address public constant VOTER_BOB = address(0xB0B);
    address public constant PROPOSAL_TARGET = address(0xDEAD);

    uint256 public constant MAXIMUM_TOKEN_SUPPLY = 1_000_000 ether;
    uint256 public constant TIMELOCK_DELAY_SECONDS = 2 days;
    uint256 public constant VOTER_ALICE_BALANCE = 500_000 ether;
    uint256 public constant VOTER_BOB_BALANCE = 100_000 ether;

    function setUp() public {
        governanceToken = new GameToken(MAXIMUM_TOKEN_SUPPLY, TOKEN_ADMIN);

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new GameTimelock(TIMELOCK_DELAY_SECONDS, proposers, executors, TOKEN_ADMIN);

        governor = new GameGovernor(governanceToken, timelock);

        vm.startPrank(TOKEN_ADMIN);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        governanceToken.mintTokens(VOTER_ALICE, VOTER_ALICE_BALANCE);
        governanceToken.mintTokens(VOTER_BOB, VOTER_BOB_BALANCE);
        vm.stopPrank();

        vm.prank(VOTER_ALICE);
        governanceToken.delegate(VOTER_ALICE);

        vm.prank(VOTER_BOB);
        governanceToken.delegate(VOTER_BOB);

        vm.roll(block.number + 1);
    }

    function test_GovernorParameters_MatchSpecification() public view {
        assertEq(governor.votingDelay(), 7200);
        assertEq(governor.votingPeriod(), 50_400);
        assertEq(governor.proposalThreshold(), 1);
        assertEq(governor.quorumNumerator(), 4);
    }

    function test_Token_HasCorrectMetadata() public view {
        assertEq(governanceToken.name(), "Crypto Realm Token");
        assertEq(governanceToken.symbol(), "REALM");
        assertEq(governanceToken.maximumTokenSupply(), MAXIMUM_TOKEN_SUPPLY);
    }

    function test_VotingPower_MatchesDelegatedBalance() public view {
        assertEq(governanceToken.getVotes(VOTER_ALICE), VOTER_ALICE_BALANCE);
        assertEq(governanceToken.getVotes(VOTER_BOB), VOTER_BOB_BALANCE);
    }

    function test_Mint_RevertWhen_ExceedsMaximumSupply() public {
        vm.prank(TOKEN_ADMIN);
        vm.expectRevert(GameToken.ExceedsMaximumSupply.selector);
        governanceToken.mintTokens(VOTER_ALICE, MAXIMUM_TOKEN_SUPPLY);
    }

    function test_FullProposalLifecycle_ProposeVoteQueueExecute() public {
        address[] memory targets = new address[](1);
        targets[0] = address(governanceToken);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(GameToken.mintTokens.selector, PROPOSAL_TARGET, 1000 ether);

        string memory description = "Mint 1000 tokens to target";

        vm.prank(VOTER_ALICE);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        vm.roll(block.number + governor.votingDelay() + 1);

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        vm.prank(VOTER_ALICE);
        governor.castVote(proposalId, 1);

        vm.prank(VOTER_BOB);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        governor.queue(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        vm.startPrank(TOKEN_ADMIN);
        governanceToken.grantRole(governanceToken.MINTER_ROLE(), address(timelock));
        vm.stopPrank();

        vm.warp(block.timestamp + TIMELOCK_DELAY_SECONDS + 1);

        governor.execute(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
        assertEq(governanceToken.balanceOf(PROPOSAL_TARGET), 1000 ether);
    }
}

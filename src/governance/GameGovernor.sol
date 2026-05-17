// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";
import { GovernorSettings } from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import { GovernorCountingSimple } from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import { GovernorVotes } from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import { GovernorTimelockControl } from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title GameGovernor
/// @notice Governance contract for the Crypto Realm protocol.
contract GameGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    /// @notice Initializes the governance contract.
    /// @param governanceTokenAddress ERC20Votes-compatible governance token.
    /// @param timelockAddress Timelock controller used for queued proposal execution.
    constructor(IVotes governanceTokenAddress, TimelockController timelockAddress)
        Governor("CryptoRealmGovernor")
        GovernorSettings(7200, 50_400, 1)
        GovernorVotes(governanceTokenAddress)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(timelockAddress)
    { }

    /// @notice Returns the voting delay before proposals become active.
    /// @return Voting delay in blocks.
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    /// @notice Returns the duration of the voting period.
    /// @return Voting period in blocks.
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    /// @notice Returns the quorum required for a proposal at a specific block.
    /// @param blockNumber Block number used for quorum calculation.
    /// @return Required quorum amount.
    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    /// @notice Returns the current state of a proposal.
    /// @param proposalId Identifier of the governance proposal.
    /// @return Current proposal state.
    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    /// @notice Returns whether a successful proposal must be queued before execution.
    /// @param proposalId Identifier of the proposal.
    /// @return True if proposal must be queued.
    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /// @notice Returns the minimum voting power required to create proposals.
    /// @return Proposal threshold amount.
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    /// @notice Queues approved proposal operations into the timelock.
    /// @param proposalId Identifier of the proposal.
    /// @param targets Addresses targeted by proposal calls.
    /// @param values ETH values sent with calls.
    /// @param calldatas Encoded function calls.
    /// @param descriptionHash Hash of proposal description.
    /// @return Timestamp when operations become executable.
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @notice Executes queued proposal operations.
    /// @param proposalId Identifier of the proposal.
    /// @param targets Addresses targeted by proposal calls.
    /// @param values ETH values sent with calls.
    /// @param calldatas Encoded function calls.
    /// @param descriptionHash Hash of proposal description.
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @notice Cancels a governance proposal.
    /// @param targets Addresses targeted by proposal calls.
    /// @param values ETH values sent with calls.
    /// @param calldatas Encoded function calls.
    /// @param descriptionHash Hash of proposal description.
    /// @return Cancelled proposal identifier.
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /// @notice Returns the executor responsible for governance execution.
    /// @return Executor address.
    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
import { BigInt } from "@graphprotocol/graph-ts"
import { ProposalCreated } from "../generated/GameGovernor/GameGovernor"
import { Proposal } from "../generated/schema"

export function handleProposalCreated(event: ProposalCreated): void {
  let proposalId = event.params.proposalId.toString()
  let proposal = new Proposal(proposalId)
  proposal.proposer = event.params.proposer
  proposal.description = event.params.description
  proposal.state = "Pending"
  proposal.forVotes = BigInt.fromI32(0)
  proposal.againstVotes = BigInt.fromI32(0)
  proposal.createdTimestamp = event.block.timestamp
  proposal.save()
}
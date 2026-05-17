# ADR-002: ERC-1155 Multi-Token Over Multiple ERC-20 Contracts

**Status:** Accepted
**Date:** 2026-05-15
**Author:** Bigali

## Context

The game economy holds five distinct asset types: three fungible resources
(WOOD, IRON, GEM) and two crafted items (SWORD, SHIELD). Two viable token
standards exist for representing these assets: deploying five separate ERC-20
contracts, or using a single ERC-1155 multi-token contract.

## Decision

We adopted ERC-1155 as the single asset registry in GameResources.

## Rationale

ERC-1155 was designed by Enjin specifically for gaming use cases and offers
three concrete advantages for this protocol. First, deployment cost is paid
once instead of five times, reducing initial gas substantially. Second, batch
operations (safeBatchTransferFrom, mintBatch) let players move multiple asset
types in a single transaction, which is the common gameplay pattern. Third,
the marketplace, crafting, and rental contracts each integrate with a single
token contract rather than five separate ones, simplifying access control and
reducing surface area for bugs.

Five separate ERC-20s would offer richer per-token metadata and simpler
external tooling integration, but these benefits do not outweigh the gas and
complexity costs at this protocol scale.

## Consequences

- All resources and items share the same balance mapping and approval model.
  Operator approval via setApprovalForAll grants access to all token IDs.
- Per-token supply caps are not enforced at the contract level; mint
  authorization is gated by MINTER_ROLE instead.
- The AMM ResourceMarketplace adapts the Uniswap V2 constant-product formula
  to ERC-1155 pools keyed by token ID pairs.
- Metadata is a single URI with the {id} placeholder, following ERC-1155
  metadata extension semantics.
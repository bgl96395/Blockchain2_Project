# Crypto Realm Subgraph

Indexes events from the Crypto Realm protocol on Base Sepolia.

## Entities

- LiquidityProvider: tracks liquidity provider activity
- SwapEvent: records each swap transaction
- LiquidityEvent: records add/remove liquidity events
- Proposal: tracks governance proposals

## Documented GraphQL Queries

### 1. Get all swap events

{
swapEvents(first: 10, orderBy: blockTimestamp, orderDirection: desc) {
id
swapInitiator
inputResourceId
outputResourceId
inputAmount
outputAmount
}
}

### 2. Get active proposals

{
proposals(where: { state: "Active" }) {
id
proposer
description
forVotes
againstVotes
}
}

### 3. Get top liquidity providers

{
liquidityProviders(first: 10, orderBy: totalLiquidityAdded, orderDirection: desc) {
id
address
totalLiquidityAdded
}
}

### 4. Get liquidity events for a specific provider

{
liquidityEvents(where: { liquidityProvider: "0x..." }) {
firstResourceAmount
secondResourceAmount
isAddition
}
}

### 5. Recent activity

{
swapEvents(first: 5, orderBy: blockTimestamp, orderDirection: desc) {
blockTimestamp
inputResourceId
outputResourceId
}
liquidityEvents(first: 5, orderBy: blockTimestamp, orderDirection: desc) {
blockTimestamp
isAddition
}
}

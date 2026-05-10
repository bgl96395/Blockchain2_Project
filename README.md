# DeFi Super-App — Blockchain Technologies 2 Final Project

Production-grade decentralized finance protocol combining a constant-product
automated market maker, a collateralized lending pool, and an ERC-4626
tokenized yield vault, governed by an on-chain DAO and deployed to Base Sepolia.

## Team

| Member  | Role            | Primary ownership                                                        |
| ------- | --------------- | ------------------------------------------------------------------------ |
| Asylbek | Team lead       | AMM, lending pool, Yul assembly module, architecture documentation       |
| Bigali  | Smart contracts | ERC-4626 vault, token contracts, UUPS upgradeability, gas report         |
| Miras   | Infrastructure  | Governor + Timelock, Chainlink oracle, subgraph, frontend, deploy scripts |

## Scenario

Option A — DeFi Super-App.

## Mandatory components

- Constant-product AMM with 0.3 percent fee, slippage protection, LP tokens (built from scratch)
- Collateralized lending pool with LTV, health factor, liquidation, linear interest
- ERC-4626 tokenized yield vault passing all rounding invariants
- ERC20Votes plus ERC20Permit governance token
- Full OpenZeppelin Governor stack with TimelockController (two-day delay)
- Chainlink price feed integration with staleness checks and mock aggregator
- The Graph subgraph with at least four entities and five documented queries
- UUPS upgradeable architecture with documented V1 to V2 upgrade path
- Factory contract using both CREATE and CREATE2
- Yul assembly module benchmarked against pure Solidity equivalent
- Deployment and verification on Base Sepolia
- React plus Wagmi plus Viem frontend with wallet connection and subgraph reads


# Crypto Realm — Blockchain Technologies 2 Final Project

Production-grade GameFi economy combining an ERC-1155 in-game item system,
a crafting station, a constant-product marketplace for fungible resources,
an NFT rental vault, Chainlink VRF-powered loot boxes, and on-chain DAO
governance, deployed on Base Sepolia.

## Team

| Member  | Role            | Primary ownership                                                 |
| ------- | --------------- | ----------------------------------------------------------------- |
| Asylbek | Team lead       | ResourceMarketplace AMM, Yul assembly module, architecture docs   |
| Bigali  | Smart contracts | GameResources ERC-1155, CraftingStation, NFTRentalVault, UUPS     |
| Miras   | Infrastructure  | GameToken, Governor, LootBox VRF, PriceOracle, frontend, subgraph |

## Scenario

Option B — GameFi Economy.

## Mandatory components

- ERC-1155 in-game item system with crafting recipes
- Constant-product AMM marketplace for fungible resources
- ERC-4626 NFT rental vault
- Chainlink VRF-powered loot box drops
- ERC20Votes plus ERC20Permit governance token
- Full OpenZeppelin Governor stack with TimelockController
- Chainlink price feed integration with staleness checks
- The Graph subgraph with indexed protocol events
- UUPS upgradeable architecture
- Factory contract with CREATE and CREATE2
- Yul assembly module benchmarked against pure Solidity
- Deployment and verification on Base Sepolia
- HTML plus Ethers.js frontend

## Repository structure

\`\`\`
src/
  resources/      ERC-1155 game items
  crafting/       crafting station with recipes
  marketplace/    constant-product AMM for resources
  rental/         ERC-4626 NFT rental vault
  lootbox/        Chainlink VRF-powered loot drops
  oracle/         Chainlink price feed adapter
  governance/     Governor, Timelock, ERC20Votes token
  upgradeable/    UUPS upgradeable variants
  factory/        deterministic deployment factories
  libraries/      shared math and Yul-optimized helpers
  interfaces/     external interfaces
  mocks/          test-only mock contracts
test/             unit, fuzz, invariant, fork tests
script/           Foundry deployment scripts
docs/             architecture, audit, gas, ADRs
frontend/         HTML + Ethers.js dApp
subgraph/         The Graph subgraph
\`\`\`

## Getting started
foundry installing
\`\`\`bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge install
forge build
forge test -vvv
\`\`\`


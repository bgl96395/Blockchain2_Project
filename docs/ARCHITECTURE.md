# Crypto Realm — Architecture Document

## 1. Project Overview

Crypto Realm is a production-grade GameFi protocol deployed on Base Sepolia. It
combines an ERC-1155 in-game item system, a constant-product AMM marketplace for
fungible resources, an ERC-4626 NFT rental vault, Chainlink VRF-powered loot
boxes, on-chain DAO governance, and a Chainlink price feed oracle.

The system models a complete blockchain game economy where players gather
resources, craft items, swap on an AMM, rent items from a vault, open randomized
loot boxes, and govern protocol parameters through token-weighted voting subject
to a two-day timelock.

## 2. System Architecture

The protocol is composed of twelve smart contracts organized into seven domains:

- **resources/** — GameResources (ERC-1155 multi-token)
- **crafting/** — CraftingStation (recipe execution)
- **marketplace/** — ResourceMarketplace (constant-product AMM)
- **rental/** — NFTRentalVault (ERC-4626 collateralized rental)
- **lootbox/** — LootBox (Chainlink VRF-driven random drops)
- **oracle/** — PriceOracleAdapter (Chainlink price feed with staleness)
- **governance/** — GameToken (ERC20Votes), GameTimelock, GameGovernor
- **upgradeable/** — MarketplaceV1 / MarketplaceV2 (UUPS upgrade path)
- **factory/** — MarketplaceFactory (CREATE and CREATE2 deployment)
- **libraries/** — MarketplaceMath (Yul-optimized AMM math)


                GameGovernor (DAO)
                      |
                GameTimelock (2-day delay)
                      |
    +-----------------+-----------------+
    |                 |                 |
GameResources      CraftingStation    ResourceMarketplace
(ERC-1155)      (recipe burns)     (constant-product)
^                 |                 ^
|                 v                 |
+----- LootBox ---+--- NFTRentalVault
(VRF)            (ERC-4626)
|
GameToken (ERC20Votes)
|
PriceOracleAdapter
(Chainlink)



## 3. Core Design Patterns

### 3.1 Constant Product AMM

ResourceMarketplace implements Uniswap V2 style x · y = k pricing for ERC-1155
resources. Pool keys are computed as keccak256(smallerId, largerId) so swap
direction is canonical regardless of how the trader passes the two resource IDs.
The 0.3% protocol fee (997/1000 numerator) accrues to liquidity providers via
the standard reserve adjustment, requiring no separate fee accounting.

MINIMUM_LIQUIDITY = 1000 is permanently locked at first deposit to prevent the
first-depositor inflation attack documented by OpenZeppelin and Uniswap.

### 3.2 Checks-Effects-Interactions

All state-mutating external functions follow CEI strictly. Reserves and balances
are updated before safeTransferFrom calls, eliminating Slither's reentrancy-2
finding and ensuring read-only reentrancy through getPoolReserves cannot return
stale state during an in-flight swap.

### 3.3 UUPS Upgradeability

MarketplaceV1 inherits OpenZeppelin UUPSUpgradeable with onlyOwner-gated
_authorizeUpgrade. V2 demonstrates the upgrade path by inheriting V1 and adding
executeUpgradeOnlyFunction plus a version string. The ERC1967Proxy slot layout
is preserved across versions; storage variables are append-only.

### 3.4 Factory with CREATE and CREATE2

MarketplaceFactory deploys ResourceMarketplace instances. deployMarketplaceWithCreate
uses standard CREATE for nonce-derived addresses; deployMarketplaceWithCreate2
uses inline Yul to invoke CREATE2 for deterministic addresses, with
predictMarketplaceAddress computing the address off-chain before deployment.

### 3.5 Yul Assembly Module

MarketplaceMath.getAmountOutYulOptimized reimplements the AMM output formula in
inline assembly, achieving ~25% gas reduction over the pure-Solidity equivalent
in MarketplaceMath.getAmountOutPureSolidity. Both versions are exported so the
benchmark is auditable.

## 4. Security Architecture

### 4.1 Access Control

Every privileged function uses OpenZeppelin AccessControl roles. Roles include
MINTER_ROLE, PAUSER_ROLE, RECIPE_MANAGER_ROLE, RENTAL_MANAGER_ROLE,
DROP_RATE_MANAGER_ROLE, FEED_MANAGER_ROLE, and DEFAULT_ADMIN_ROLE.
DEFAULT_ADMIN_ROLE is transferred to GameTimelock after deployment so all
sensitive role changes require a two-day governance delay.

### 4.2 Circuit Breaker

ResourceMarketplace and GameResources inherit OpenZeppelin Pausable. PAUSER_ROLE
can halt all liquidity, swap, and mint operations during incident response.

### 4.3 Reentrancy Protection

All external state-changing functions in ResourceMarketplace, CraftingStation,
NFTRentalVault, and LootBox use OpenZeppelin ReentrancyGuard. SafeERC20 is used
for all ERC-20 transfers in the vault to handle non-standard tokens.

### 4.4 Oracle Staleness

PriceOracleAdapter requires every Chainlink response to satisfy three checks:
price > 0, answeredInRound >= roundId, and block.timestamp - updatedAt <=
maximumStalenessSeconds. The staleness window is governance-configurable.

### 4.5 Static Analysis

Slither reports zero High and zero Medium findings. Nineteen Low or
Informational findings are documented and acknowledged in AUDIT-REPORT.md.

## 5. Governance Architecture

The governance stack is the full OpenZeppelin Governor framework:

- **GameToken** — ERC20 + ERC20Permit + ERC20Votes with a 1,000,000 REALM cap
- **GameTimelock** — TimelockController with a two-day minimum delay
- **GameGovernor** — Governor + GovernorSettings(7200 blocks delay,
  50400 blocks voting period, 1 token threshold) + GovernorCountingSimple +
  GovernorVotes + GovernorVotesQuorumFraction(4%) + GovernorTimelockControl

The full lifecycle (propose, vote, queue, execute) is demonstrated end-to-end
in test/unit/Governance.t.sol::test_FullProposalLifecycle_ProposeVoteQueueExecute.

## 6. Testing Strategy

The test suite covers seventy-six tests across four categories:

- **Unit tests** (test/unit/) — fifty tests covering every external function,
  every revert path, and every event emission across all twelve contracts
- **Fuzz tests** (test/fuzz/) — ten property-based tests on AMM invariants and
  governance token state
- **Invariant tests** (test/invariant/) — five Foundry invariants run through
  a MarketplaceHandler that exercises addLiquidity and swap
- **Fork tests** (test/fork/) — three tests against the live Base Sepolia
  Chainlink ETH/USD feed at 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1

## 7. Deployment

The entire stack is deployed atomically through script/Deploy.s.sol. The script
deploys every contract in dependency order, grants the required cross-contract
roles, and transfers all administrative privileges to GameTimelock.

Deployment to Base Sepolia is reproducible:

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url base_sepolia --broadcast
```

Deployed addresses are recorded in DEPLOYED-ADDRESSES.md.

## 8. Frontend Architecture

The frontend is a single-page HTML + Ethers.js v5 application styled with
Tailwind CSS (CDN). It connects to MetaMask, detects Base Sepolia, displays
balance / voting power / pool reserves, supports three state-changing flows
(swap, delegate, deposit), and reads active proposals from The Graph subgraph.

No build step is required; the application runs from a static file server.

## 9. Off-Chain Indexing

The Graph subgraph indexes ResourceMarketplace and GameGovernor events into
four entities (LiquidityProvider, SwapEvent, LiquidityEvent, Proposal). Five
documented GraphQL queries are committed in subgraph/README.md.

## 10. Trust Assumptions

- Deployer initially holds DEFAULT_ADMIN_ROLE on all role-gated contracts. This
  is mitigated by transferring the role to GameTimelock during deployment.
- Chainlink price feed is trusted to report the true ETH/USD price within the
  configured staleness window.
- Chainlink VRF coordinator is trusted to return uniformly random words. Tests
  use a MockVRFCoordinator to verify deterministic behavior under controlled
  randomness; production deployments would integrate the live VRF subscription.


  ## 12. Sequence Diagrams

### 12.1 Resource Swap

\`\`\`mermaid
sequenceDiagram
    actor User
    participant Frontend
    participant Marketplace as ResourceMarketplace
    participant Resources as GameResources

    User->>Frontend: Click swap
    Frontend->>Marketplace: swapExactInputForOutput()
    Marketplace->>Marketplace: Apply 0.3% fee, compute output
    Marketplace->>Marketplace: Update reserves (CEI)
    Marketplace->>Resources: safeTransferFrom(WOOD, user, pool)
    Marketplace->>Resources: safeTransferFrom(IRON, pool, user)
    Marketplace-->>Frontend: ResourcesSwapped event
    Frontend-->>User: Updated balance
\`\`\`

### 12.2 Governance Proposal Lifecycle

\`\`\`mermaid
sequenceDiagram
    actor Proposer
    actor Voters
    participant Governor as GameGovernor
    participant Timelock as GameTimelock
    participant Target

    Proposer->>Governor: propose()
    Governor-->>Proposer: ProposalCreated
    Voters->>Governor: castVote()
    Governor->>Governor: Tally, check 4% quorum
    Proposer->>Governor: queue()
    Governor->>Timelock: schedule()
    Note over Timelock: Wait 2 days
    Proposer->>Governor: execute()
    Governor->>Timelock: executeOperation()
    Timelock->>Target: Apply change
\`\`\`

### 12.3 Crafting

\`\`\`mermaid
sequenceDiagram
    actor Player
    participant Crafting as CraftingStation
    participant Resources as GameResources

    Player->>Crafting: craftRecipe(0)
    Crafting->>Resources: balanceOf(player, WOOD)
    Crafting->>Resources: balanceOf(player, IRON)
    Crafting->>Resources: burnResource(WOOD, 2)
    Crafting->>Resources: burnResource(IRON, 1)
    Crafting->>Resources: mintResource(SWORD, 1)
    Crafting-->>Player: RecipeCrafted event
\`\`\`
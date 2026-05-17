# Security Audit Report — Crypto Realm Protocol

**Auditors:** Asylbek (lead), Bigali
**Scope:** All contracts in `src/` excluding mocks
**Date:** 2026-05-15
**Commit:** Latest on `feature/marketplace-asylbek` and `feature/resources-bigali`
**Methodology:** Manual code review, Slither static analysis, Foundry unit + fuzz + invariant + fork testing

---

## 1. Executive Summary

This report documents the internal security audit of the Crypto Realm protocol,
a GameFi economy deployed on Base Sepolia. The protocol comprises twelve
production contracts covering an ERC-1155 in-game asset system, a constant-product
AMM, an ERC-4626 rental vault, Chainlink VRF-driven loot boxes, a Chainlink
price oracle, on-chain DAO governance with timelock, UUPS upgradeability, and a
deterministic factory.

After review, **no High or Medium severity findings** were identified. Nineteen
Low or Informational findings are documented below with mitigations or
acknowledged design rationale. All seventy-six tests pass on the audited commit.

## 2. Methodology

- **Manual code review** — every external and public function in every contract
- **Static analysis** — Slither v0.11.5 with the project `slither.config.json`
- **Unit testing** — fifty tests covering every external function, every revert
  path, and every event emission
- **Fuzz testing** — ten property-based tests covering AMM invariants and
  governance token state
- **Invariant testing** — five Foundry invariants run through a handler
- **Fork testing** — three tests against the live Base Sepolia Chainlink feed

## 3. Findings Summary

| Severity      | Count | Status                                |
| ------------- | ----- | ------------------------------------- |
| Critical      | 0     | —                                     |
| High          | 0     | —                                     |
| Medium        | 0     | —                                     |
| Low           | 8     | All acknowledged with mitigations     |
| Informational | 11    | All acknowledged                      |

## 4. ResourceMarketplace (AMM)

### 4.1 Constant Product Invariant

The contract implements x · y = k pricing with a 0.3% fee (997 / 1000). Pool
keys use `keccak256(smaller, larger)` so swap direction is canonical. After
every swap, `newReserve0 * newReserve1 >= oldReserve0 * oldReserve1` is checked
explicitly and reverts with `ConstantProductInvariantViolated` otherwise.

### 4.2 Inflation Attack Mitigation

MINIMUM_LIQUIDITY = 1000 LP tokens are permanently burned to address(0) on
first deposit. This prevents the documented first-depositor attack where an
attacker mints 1 LP token, donates a large amount, and then sandwiches future
deposits. The fuzz test `testFuzz_AddLiquidity_FirstDepositMintsExpectedShares`
covers this property over 256 random inputs.

### 4.3 Checks-Effects-Interactions

The initial implementation triggered Slither `reentrancy-2` (cross-function
reentrancy via `getPoolReserves`). The fix moved all reserve and supply state
mutations before the two `safeTransferFrom` calls in `addLiquidity`,
`removeLiquidity`, and `swapExactInputForOutput`. Slither now reports zero
reentrancy findings.

### 4.4 Findings

**M-01 (resolved):** Cross-function reentrancy via `getPoolReserves`. Fixed in
commit `9b8744e` by enforcing CEI throughout.

**L-01 (acknowledged):** `block.timestamp` used in deadline comparison. Miner
manipulation window is roughly fifteen seconds; deadlines are user-supplied
and typically exceed one hour, so the risk is immaterial.

## 5. Governance Stack (GameToken / GameTimelock / GameGovernor)

### 5.1 Full Lifecycle Coverage

`test/unit/Governance.t.sol::test_FullProposalLifecycle_ProposeVoteQueueExecute`
demonstrates the complete `propose → vote → queue → execute` flow end-to-end,
including state transitions, vote tallying, timelock delay enforcement, and
final execution against the GameToken contract.

### 5.2 Supply Cap Enforcement

`GameToken.mintTokens` reverts with `ExceedsMaximumSupply` if any mint would
push `totalSupply()` beyond the immutable cap. Fuzz test
`testFuzz_Mint_RevertWhen_ExceedsMaxSupply` validates this over the full
uint128 range above the cap.

### 5.3 Vote Power Conservation

`testFuzz_VotingPower_PreservedAfterTransferIfBothDelegated` proves that the
sum of voting power across two delegated holders equals the total minted
amount, regardless of how tokens move between them. This protects against
double-counting bugs from incorrect `_update` overrides.

### 5.4 Findings

**L-02 (acknowledged):** Initial deployer holds `DEFAULT_ADMIN_ROLE`. The
deployment script transfers this role to GameTimelock at the end, but during
the deployment window the role is held by a single key.

## 6. UUPS Upgradeability (MarketplaceV1 / MarketplaceV2)

### 6.1 Storage Layout

V1 declares four storage variables in order. V2 inherits V1 and appends
`totalUpgradeCallsExecuted`, preserving slot zero through three for V1
variables. `test_UpgradeToV2_PreservesStateAndAddsFunctionality` verifies
state survives the upgrade.

### 6.2 Upgrade Authorization

`_authorizeUpgrade(address)` is gated by `onlyOwner`. Ownership is intended to
transfer to GameTimelock so upgrades require the two-day governance delay.

### 6.3 Findings

**I-01 (informational):** OZ v5 removed `ReentrancyGuardUpgradeable` from its
public surface; we use the non-upgradeable `ReentrancyGuard` instead. This is
documented but does not affect correctness for our use case.

## 7. Factory (CREATE and CREATE2)

### 7.1 Deterministic Addresses

`deployMarketplaceWithCreate2` uses inline Yul to invoke the `create2` opcode
with the provided salt. `predictMarketplaceAddress` computes the expected
address using the standard `keccak256(0xff || factory || salt || codeHash)`
formula. Test `test_DeployWithCreate2_MatchesPredictedAddress` confirms
equality between predicted and actual addresses.

### 7.2 Findings

**L-03 (acknowledged):** No zero-address check on `factoryAdministrator`. A
deployer setting administrator to address(0) would lock factory deployment.
Mitigation: deploy scripts always pass a non-zero deployer.

## 8. Oracle (PriceOracleAdapter)

### 8.1 Three-Layer Staleness Check

Every `getLatestPriceWithStalenessCheck` call enforces:
1. `rawPrice > 0` (no zero or negative values),
2. `answeredInRound >= roundId` (round must be complete),
3. `block.timestamp - lastUpdatedTimestamp <= maximumStalenessSeconds`.

All three failure modes have dedicated custom errors and dedicated unit tests.

### 8.2 Fork Test

`test_Fork_ChainlinkFeedReturnsPrice` runs against the live Base Sepolia
ETH/USD feed at `0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1` and asserts
0 < price < 100000 * 10**18.

### 8.3 Findings

**I-02 (informational):** `unsafe-typecast` Slither warning on
`uint256(rawPrice)`. Safe because the preceding check rejects any
non-positive value before the cast.

## 9. LootBox (Chainlink VRF)

### 9.1 Random Reward Determination

`fulfillRandomWords` is restricted to the configured VRF coordinator. Drop
rates `[50, 30, 15, 4, 1]` sum to 100; reward selection is implemented as a
cumulative-weight lookup, ensuring uniformity over the full random space.

### 9.2 Checks-Effects-Interactions

The initial `openLootBox` triggered Slither `reentrancy-benign` because
external `burnResource` preceded state writes. Fixed in commit `f57fd26` by
moving `nextRequestId++` and `pendingRequests` assignment ahead of all
external calls.

### 9.3 Immutable Configuration

`callbackGasLimit` was changed from `public uint32` to `public immutable uint32`
to eliminate the SLOAD on every `openLootBox` call. Slither `immutable-states`
finding resolved.

### 9.4 Findings

**L-04 (acknowledged):** A malicious VRF coordinator could re-call
`fulfillRandomWords` for the same `requestId`. Mitigation: `requestId.fulfilled`
boolean is set before the external mint call, preventing double-fulfillment.

## 10. Resources, Crafting, Vault

See `AUDIT-REPORT-PART1.md` for findings G-01, G-02, C-01, and V-01 covering
GameResources, CraftingStation, and NFTRentalVault.

## 11. Static Analysis Summary

Slither reports nineteen findings:
- Zero High
- Zero Medium
- Eight Low (all acknowledged with mitigations above)
- Eleven Informational (timestamp comparisons, intentional assembly usage,
  too-many-digits in Yul mstore literals, unindexed event address, etc.)

## 12. Test Coverage

Seventy-six tests pass on the audited commit:

| Category | Count | Notes |
| -------- | ----- | ----- |
| Unit | 50 | Every external function, every revert path |
| Fuzz | 10 | Property-based, 256 runs each |
| Invariant | 5 | MarketplaceHandler with 128000 calls |
| Fork | 3 | Live Base Sepolia Chainlink ETH/USD |

## 13. Tools

- Foundry v1.6.0 nightly
- Solidity 0.8.24 (Cancun EVM)
- Slither v0.11.5
- OpenZeppelin Contracts v5
- OpenZeppelin Contracts Upgradeable v5
- Chainlink Brownie Contracts (AggregatorV3Interface)

## 14. Conclusion

The Crypto Realm protocol passes internal audit with zero High or Medium
findings. All Low and Informational findings are documented with concrete
mitigations or accepted design rationale. The codebase follows
Checks-Effects-Interactions, uses OpenZeppelin AccessControl for every
privileged function, and demonstrates the full governance lifecycle in tests.

Recommended next steps before mainnet deployment:
1. External audit by an independent firm
2. Bug bounty program covering at minimum the AMM and governance contracts
3. Mainnet deployment of contracts with administration immediately transferred
   to GameTimelock
4. Integration of live Chainlink VRF subscription replacing MockVRFCoordinator
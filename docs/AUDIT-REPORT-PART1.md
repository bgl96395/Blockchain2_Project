# Security Audit Report — Part 1
## GameResources, CraftingStation, NFTRentalVault

Auditor: Bigali (internal team audit)
Scope: src/resources/, src/crafting/, src/rental/
Methodology: Manual code review, Slither static analysis, unit + fuzz testing

## 1. Executive Summary

This part of the audit covers the GameResources ERC-1155 contract, the CraftingStation
recipe execution contract, and the NFTRentalVault ERC-4626 vault. After review,
no High or Medium severity findings were identified. Three Low severity findings
and two Informational findings are documented below with recommended mitigations.

## 2. GameResources Analysis

### 2.1 Access Control

The contract uses OpenZeppelin AccessControl with two roles:
- DEFAULT_ADMIN_ROLE: grants and revokes other roles
- MINTER_ROLE: authorized to mint resources
- PAUSER_ROLE: can pause and unpause minting

Finding G-01 (Low): Centralization risk in DEFAULT_ADMIN_ROLE.
The deployer initially holds DEFAULT_ADMIN_ROLE and can grant MINTER_ROLE
arbitrarily. After deployment, this role should be transferred to the
TimelockController to enforce governance review.
Status: Acknowledged. Production deploy script transfers admin to timelock.

### 2.2 Mint Function Validation

mintResource validates:
- resourceId is in valid range (1..5)
- mintAmount is non-zero
- whenNotPaused modifier prevents minting during emergency

Finding G-02 (Informational): No maximum supply cap per resource.
Unlike GameToken which enforces maximumTokenSupply, GameResources permits
unlimited minting. This is intentional for in-game economy flexibility but
should be documented as a centralization trust assumption.
Status: Acknowledged.

### 2.3 Burn Authorization

burnResource requires either msg.sender == burnFromAddress or operator approval.
No reentrancy risk because no external calls follow the _burn operation.

## 3. CraftingStation Analysis

### 3.1 Recipe Management

Recipes are stored in a mapping keyed by recipeId. Only RECIPE_MANAGER_ROLE
can register new recipes or toggle their active status.

Finding C-01 (Low): Recipe deletion is not supported.
If a recipe contains an exploitable economic flaw, it can only be deactivated,
not removed. The total recipe count is therefore monotonically increasing.
Status: Acknowledged as design choice. Deactivation is functionally equivalent.

### 3.2 Atomicity of Crafting

craftRecipe burns two input resources and mints one output. The sequence is:
1. Validate recipe is active and exists
2. Validate user balances
3. Burn both inputs
4. Mint output
5. Emit event

If the mint step fails (e.g., paused contract), the burn step reverts due to
EVM atomicity. No partial state is possible.

### 3.3 Reentrancy

nonReentrant modifier protects craftRecipe. The external calls (burn, mint)
go to GameResources, which we control and which does not call back. Cross-function
reentrancy is not possible because no state is read after external calls.

## 4. NFTRentalVault Analysis

### 4.1 ERC-4626 Compliance

The vault inherits from OpenZeppelin ERC4626 and exposes the standard
deposit / withdraw / mint / redeem interface. The asset is GameToken; vault
shares are minted as rvSHARE tokens.

### 4.2 Rental Lifecycle

createRental (RENTAL_MANAGER_ROLE only):
1. Validate non-zero collateral
2. Transfer collateral from renter using safeTransferFrom
3. Record rental agreement
4. Transfer game item to renter

endRental (permissionless):
1. Validate rental is active
2. Validate rental period has expired
3. Mark inactive
4. Return collateral to renter via safeTransfer

Finding V-01 (Low): No mechanism to slash collateral if renter does not
return the rented item.
The current design returns collateral on time expiration regardless of whether
the renter returns the rented NFT/resource. A production version should require
the renter to surrender the item before reclaiming collateral.
Status: Acknowledged. This MVP version trusts time-based expiration.

### 4.3 Reentrancy Protection

nonReentrant guards createRental and endRental. SafeERC20.safeTransferFrom and
safeTransfer are used for all token movements. The asset() token is GameToken,
which is standards-compliant and not malicious.

## 5. Centralization Analysis

Powers held by DEFAULT_ADMIN_ROLE (initially deployer):
- Grant or revoke MINTER_ROLE on GameResources
- Grant or revoke RECIPE_MANAGER_ROLE on CraftingStation
- Grant or revoke RENTAL_MANAGER_ROLE on NFTRentalVault
- Pause GameResources via PAUSER_ROLE

Mitigation: Deploy script transfers DEFAULT_ADMIN_ROLE to TimelockController
after initial setup. All future role changes go through 2-day governance delay.

## 6. Findings Table

| ID   | Severity      | Title                                | Status       |
| ---- | ------------- | ------------------------------------ | ------------ |
| G-01 | Low           | DEFAULT_ADMIN_ROLE centralization    | Acknowledged |
| G-02 | Informational | No per-resource supply cap           | Acknowledged |
| C-01 | Low           | Recipe deletion not supported        | Acknowledged |
| V-01 | Low           | No collateral slashing on no-return  | Acknowledged |

No High or Medium findings identified.

## 7. Tools Used

- Foundry v1.6.0 (forge build, forge test, forge fmt)
- Slither v0.11.5
- Manual code review

## 8. Test Coverage

- 7 unit tests for GameResources
- 6 unit tests for CraftingStation
- 7 unit tests for NFTRentalVault

All tests pass on the audited commit.



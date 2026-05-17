# ADR-001: UUPS Proxy Pattern over Transparent Proxy

**Status:** Accepted
**Date:** 2026-05-15
**Author:** Asylbek

## Context

The protocol requires at least one upgradeable contract per the project
specification. OpenZeppelin offers two production-grade upgrade patterns:
Transparent Proxy (TPP) and Universal Upgradeable Proxy Standard (UUPS).

## Decision

We adopted the UUPS pattern for MarketplaceV1 and MarketplaceV2.

## Rationale

UUPS places the upgrade logic in the implementation contract rather than the
proxy. This results in a smaller proxy bytecode (lower deployment gas), no
admin slot collision risk, and explicit removal of upgrade ability if a future
version omits _authorizeUpgrade.

Transparent Proxy was rejected because its admin slot adds complexity, it
requires two contracts (Proxy and ProxyAdmin), and the proxy bytecode is
larger. UUPS is also the OpenZeppelin recommended default for new projects.

## Consequences

- Smaller proxy footprint and lower deployment gas.
- Upgrade authorization lives in the implementation; we gate it with
  onlyOwner, and ownership is later transferred to GameTimelock so all
  upgrades require a two-day governance delay.
- Future implementations must include UUPSUpgradeable inheritance, or
  upgradeability is permanently disabled (a feature, not a bug).
- Storage layout is append-only across versions to prevent slot collisions.
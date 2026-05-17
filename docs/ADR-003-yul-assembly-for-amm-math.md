# ADR-003: Yul Assembly for AMM Output Math

**Status:** Accepted
**Date:** 2026-05-15
**Author:** Asylbek

## Context

The constant-product output formula getAmountOut is the most frequently
executed pure function in the AMM. Every swap calls it. At scale, even small
gas optimizations on this path produce meaningful savings for users. The
project specification also requires at least one contract with inline Yul
assembly benchmarked against a pure-Solidity equivalent.

## Decision

We implemented MarketplaceMath as a library exposing two functions with
identical semantics: getAmountOutPureSolidity (the readable baseline) and
getAmountOutYulOptimized (the inline-assembly version).

## Rationale

Inline Yul lets us bypass the Solidity compiler's intermediate representation
overhead on a hot path. We replaced Solidity custom-error reverts with manual
mstore + revert sequences, eliminated implicit overflow checks in the
multiplication and division (safe because the AMM contract enforces input
bounds on inputAmount and reserves), and used direct stack manipulation
instead of named local variables.

Both functions are exported. Auditors and integrators can verify equivalence
on identical inputs, and downstream callers can choose readability or
optimization depending on their gas profile.

## Consequences

- The Yul version saves approximately 25% gas relative to the pure-Solidity
  version on a typical swap (measured via forge test --gas-report).
- The Yul version is harder to read and audit. We mitigate this by keeping
  the pure-Solidity version as the canonical specification and treating the
  Yul version as a performance-equivalent alternative.
- Future Solidity compiler improvements may close the gap; we will re-benchmark
  on each compiler upgrade and revert to pure Solidity if savings drop below 10%.
- Any change to the constant-product formula must be applied to both versions
  identically.
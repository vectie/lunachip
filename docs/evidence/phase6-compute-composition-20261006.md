# Joint generation/compute extraction checkpoint

Implementation commit: `7892771`, parent `5f11e12`. Logged checks ran against
the parent with the exact six checkpoint paths recorded in unchanged Git
before/after status. The tested source was then committed without intervening
edits. This establishes exact extraction and native behavior, not an
authorization, ownership or full-device formal proof.

## Implemented slice

The [joint design](../PHASE6_COMPUTE_GENERATION.md) retains 27 original
registers / 416 bits: eighteen generation registers and nine compute
registers. It has one original clock domain, no memories, nineteen input
ports / 341 bits and 42 outputs. Eighteen nonstate cuts total 340 bits; clock
is the remaining input. Next expressions, reset/enable controls and arbitrary
initial values are copied without changing the production graph.

Discovery removes cut shadows derived by either retained cone and recomputes
closure from all register specifications and observations. The seventeen
formerly free generation fields used by compute admission are actual state.
Compute acceptance, Issue and Done remain derived; terminal ticket/fault are
the actual saved registers. Raw queue, load/core completion, conflicts and
preflight remain explicit local environment boundaries.

## Validation

The three focused joint tests pass. They verify all register specifications,
node order/remapping and output aliases, establish successful load generations
through original register transitions, reserve/accept a Mat command, and hold
its saved identity while a younger generation changes and fails. They then
handshake inner Issue, collect compute completion into the result generation,
and check preflight failure/reset priority. No test injects generation state.
These local-cut stimuli are not claimed to be full-device reachable traces.

The complete formal package passes 87/87 tests and the full native suite
passes 811/811. Interface generation, formatting, strict native checking,
default CLI smoke and dependency/source-size boundaries pass. Independent
activated-source review found no defect, alias omission or unsupported claim.

Fresh exports preserve all thirteen generation artifacts and all 46 ordinary
dependency artifacts byte-for-byte and by SHA256 against the retained
[generation bridge](phase6-generation-bridge-20261006.md). The comparison
inventory SHA256 remains
`ad5bcd83ad8a88c4cdb3c25ab47d7c63d955424ca899864f423c3b881671da73`.
No public API, CLI, fixture task, receipt or runner changed at this checkpoint.
No solver or formal engine ran.

## Retention and remaining work

Original evidence:
`/private/tmp/lunachip-compute-composition-20261006.2JCvBH`.

Verified workspace copy:
`/Users/kq/Workspace/lunachip/.phase6-compute-composition-evidence-20261006`.

The copy contains 169 inventoried files, including logs/context, the six
committed sources, independent/root review, existing export comparisons and
MoonBit retention scripts. Build caches and unverified staged bridge/export
work are excluded. Aggregate `outputs.sha256` SHA256:
`2a7c8d2c45364fd23aa0830b2eb1c2f8057d0473988d1195e160b10dc02b4311`.
Every retained byte/digest, exact copy inventory and comparison inventory was
verified after copying.

The existing independent generation and saved compute owner/authorization
reference still needs composition and actual induction. Staged proof inputs
are not part of this checkpoint or its evidence. Load/store ownership, core/
SRAM/arithmetic, FIFO, retirement, leases, wrap, fairness and full-device
safety remain unfinished. The normative phase gates remain unchanged.

# Public transport formal pilot on 2026-10-05

The first actual FluxTile formal task establishes monitor sensitivity only.
It is not a production safety proof or a completed formal gate.

Code snapshot: `a338a65dedc81099da9c5db43b7453082966b932`.
The predefined production graph is unchanged 1x1/K2, host1024, ring4, q2.
Canonical production IR and RTL are identical across all three pilot bundles;
the negative fixture changes only the wrapper's observed address bit 32.

## Completed task

`phase6-flux-tile-negative-request-bounds-bmc` produced the expected safety
counterexample at global step 13, on the exact selected assertion:

`lc_p5_b7472616e73706f72745f726571756573745f616464726573735f696e5f6170657274757265`

This is `transport_request_address_in_aperture`. The monitored 33-bit address
has bit 32 deliberately set, while the genuine production request is unchanged.
The nonwrapping 34-bit end-exclusive bound check detects that observation.
The five named host/reset assumptions remain active; malformed response
tag/status/data remain symbolic, and no fairness assumption is added.

The task bound is 256 global steps, corresponding to 128 DUT clocks. The
unchanged runner exited zero after the expected SBY failure and exact-label
check. Its typed result is `counterexample` and binds one retained VCD trace;
SBY elapsed time was 292 seconds, including preparation. The full output
manifest verifies. This result does not prove the production property.

The existing locked network-disabled/read-only volume transport used
`linux/amd64` image
`ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`,
Yosys 0.68, SBY v0.68 and Bitwuzla 0.9.1. Locks, flags and VM configuration
are unchanged.

Bundles, complete negative output, logs, versions, typed result/receipt and
the native checkpoint log are retained outside Git at
`/Users/kq/Workspace/lunachip/.phase6-formal-evidence-20261005`.
Original run root:
`/private/tmp/lunachip-phase6-formal-20261005.QHGLCc`.

| Artifact | SHA-256 |
|---|---|
| `negative-bounds/source-set.lcfs` | `d1791aadfce481c25a615da0ccb1b5e72de71d730d51a1726c485c3b24163bf8` |
| `negative-bounds-output/result.lcfr` | `2700a25e2b0e4dfd5535667360badddb466a3b23ba334685fffffd94407723e6` |
| `negative-bounds-output/receipt.lcfe` | `0ba68c56239c6e2a645bf23b19a2ba56d9d76585dba7425b4eadef597e0158d7` |
| `negative-bounds-output/outputs.sha256` | `026ff110e57ede8f7ed0a3e118cacd9a056d51765cfcc45e64924b741650dbf2` |
| `negative-bounds-output/phase6-flux-tile-negative-request-bounds-bmc-work/engine_0/trace.vcd` | `d7c2ac3da1fa16dfd8bff1d2aff7631e603ebb58f2dfc69b10535a07ba2ba229` |

## Outstanding claims

Valid bounded safety, all three reachability witnesses and the stalled-request
negative remain unrecorded. Even successful short pilot outcomes would not
exercise the write branch: an actual-write cover and safety depth reaching
it remain required. Private queue/dependency/lease obligations, larger 8x8
formal checks, induction and explicit-fairness eventual completion are separate
required gates. No complete Phase 6, unbounded, physical RAM or timing claim
follows from this partial result.

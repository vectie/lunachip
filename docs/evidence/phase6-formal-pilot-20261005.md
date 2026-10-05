# Public transport formal pilot on 2026-10-05

The completed pilot tasks establish monitor sensitivity and two public
reachability witnesses. They are not a production safety proof or completed gate.

Code snapshot: `a338a65dedc81099da9c5db43b7453082966b932`.
The predefined production graph is unchanged 1x1/K2, host1024, ring4, q2.
Canonical production IR and RTL are identical across all three pilot bundles;
the negative fixture changes only the wrapper's observed address bit 32.

## Completed bounds sensitivity task

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

## Completed held-request reachability task

`phase6-flux-tile-public-transport-cover-held-request` passed with an actual
witness at global step 13, on `reachable_held_request`. The production device
asserts a memory request while the symbolic host withholds readiness. No
monitor mutation is present. The runner exited zero, the typed result is
`cover-witness`, and the complete output manifest verifies. SBY elapsed time
was 285 seconds, including preparation and witness emission.

This establishes one reachable stalled request under the five named legal
host/reset assumptions, not stable-hold safety, eventual response or command
completion. Its bound remains 256 global steps / 128 DUT clocks with no
fairness assumption. Complete output and outer log are retained alongside
the negative result in the same evidence directory.

| Artifact | SHA-256 |
|---|---|
| `public-transport/source-set.lcfs` | `22d34db76064454b6bd0ef95b28eeb8bd4d71a4ad2b4210c6b070763bcbfddeb` |
| `held-request-output/result.lcfr` | `37a9b499af05652e583afbc48c880bcdd30a1ac491c403352abd1773d24acdae` |
| `held-request-output/receipt.lcfe` | `75f54883949612d5e658d139b2f5f20640c03e2210e0df43aa9131727e213bf5` |
| `held-request-output/outputs.sha256` | `a1d9cf1000778f3189af02b825b5f235df394b34521ecdc50a4f9644e66f6178` |
| `held-request-output/phase6-flux-tile-public-transport-cover-held-request-work/engine_0/trace0.vcd` | `0c5eb931a61ef4702b54ef7e57ce1a702a7b6bf90d4d27be65e1cd916ad4c5d2` |

## Completed owned-response reachability task

`phase6-flux-tile-public-transport-cover-owned-response` passed with an actual
witness at global step 15, on `reachable_owned_response`. A genuine previously
accepted memory request has a pending ownership obligation when the host
response is acknowledged. The runner exited zero, the typed result is
`cover-witness`, and the complete output manifest verifies. SBY elapsed time
was 372 seconds, including preparation and witness emission.

This establishes reachability of an owned response handshake, not successful
tag/status validation, command completion or safety. Host response tag and
status remain symbolic, including malformed responses. The same five named
host/reset assumptions apply; no fairness assumption or monitor mutation is
present. The bound remains 256 global steps / 128 DUT clocks. Complete output
and the outer log are retained in the same evidence directory.

| Artifact | SHA-256 |
|---|---|
| `owned-response-output/result.lcfr` | `4d7e7dd7fc5adff1560446093a436638f46ce0ac8c1daa8227ef2df0a13d7c37` |
| `owned-response-output/receipt.lcfe` | `730a936f77faa1d005180b0c28ace977852a203c804128ad792e4f444d01a82d` |
| `owned-response-output/outputs.sha256` | `685e011a2118e5d532273c35b4b4ef70589176fb8829675d8d6da94c6a2a6c8a` |
| `owned-response-output/phase6-flux-tile-public-transport-cover-owned-response-work/engine_0/trace0.vcd` | `dd896828c35dd58db75449bb3c29051cc8b34f4a6315953c3d2d786161e4271c` |

## Outstanding claims

The unchanged first-terminal task timed out after its declared 600-second
limit (SBY elapsed 601 seconds). The last logged search was global step 48;
SBY produced no trace and the runner exited 8. This is incomplete execution,
not an unreachable-cover result, counterexample or safety pass. Complete
output and the outer log are retained as `first-terminal-output` and
`first-terminal-run.log` in the same evidence directory. No typed success
result or receipt was manufactured for the timeout.

| Incomplete-run artifact | SHA-256 |
|---|---|
| `first-terminal-run.log` | `c3f218c4494fa6ec2cab26cb246c345c4fec60a7853d9e346ed58c179cfe1b71` |
| `first-terminal-output/phase6-flux-tile-public-transport-cover-first-terminal-work/status` | `78e889e2e3fe43a9ba3a65bb4854460e6367a704dfe8e13beb306c380bf11427` |
| `first-terminal-output/phase6-flux-tile-public-transport-cover-first-terminal-work/config.sby` | `048f0fd430e491ddb1716ffff097e5f7d2acaa5422c3ff6c14c9940d1e09b1bb` |

Valid bounded safety, the first-terminal witness and the stalled-request
negative remain unrecorded. Even successful short pilot outcomes would not
exercise the write branch: an actual-write cover and safety depth reaching
it remain required. Private queue/dependency/lease obligations, larger 8x8
formal checks, induction and explicit-fairness eventual completion are separate
required gates. No complete Phase 6, unbounded, physical RAM or timing claim
follows from this partial result.

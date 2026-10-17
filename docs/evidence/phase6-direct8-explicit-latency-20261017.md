# Direct8 explicit command latency proof

The original direct8 binary model now passes explicit inclusive command-to-Done
bounds jointly with accepted59: Load ≤1666, Store ≤898 and MatMul ≤99 DUT
edges. This is an unbounded k-induction result under the original seven public
premises, not the positive 11,718-edge retirement theorem. See the
[qualification plan](../PHASE6_DIRECT8_EXPLICIT_LATENCY.md).

Frozen clean source: `8e3902ff8b033f233dc2f3aeb63f6c1bcc59bf1d`.
Task: `phase6-flux-tile-direct8-q3-engine-latency-arith-r2-h2-prove`.
Canonical original IR:
`12e94f78c7136ada755eed2f35c92af52d77aa75fa2f1398bab19872057ff3ae`.

## Exact input extension

The new profile adds only original `d8l_command_latency` to the accepted
arithmetic59 selection: 60 selected groups and 144 actual assertions. Its
property manifest matches original unadapted full60 exactly. The assertion
export is the only DUT difference from arithmetic59. Reversing the same 13
helper substitutions restores the entire original full60 DUT exactly.
Regressions pin both older input sets and verify lossless regeneration.

The original observer equations, acceptance age one, inclusive Done conditions,
clock/reset, address-knownness, full UInt13 cursors, UInt64 DMA arithmetic,
memory connections and payloads are unchanged. All support remains asserted,
never assumed. No memory value is initialized, constrained, cut or replaced.
Production emission and public package interfaces remain unchanged.

Focused native regressions pass 5/5. Fresh preflight passes 83 tests:
68 native design, six verifier and nine automation, alongside 27 typed fixture
checks, 25 comparator audits, formatting, interface generation and strict native
checking. Native boundary/negative tests retain their original scope; they do
not substitute for the actual formal result.

Fresh pinned SAT proves all 13 helper pairs over all defined binary operand
assignments, including all 64 address bits. Corrupting only bit 63 of add64
produces a genuine SAT model and expected `-verify` failure. The full60 runner
checks its exact helper report/miter against this qualification before running.
The post-run retained MoonBit driver repeats that read-only check, exit 0.
No preparation benchmark is repeated and no four-state production equivalence
is claimed.

## Accepted unbounded result

The single full60 task returns `PASS 0 538`, runner exit 0, 403 SBY wall seconds
within its original 600-second cap. The 538 is process time, not wall duration.
Base steps 0–31 pass at 114 solver seconds. Temporal induction succeeds at
379 seconds and status passes at 381. Both base and induction return pass;
there is no trace. The typed result and receipt verify against the selected
task and exact inputs.

Independent review verifies all 144 assertions, the seven original premises,
exact compiled source copies and clean unchanged private HEAD/status. It also
checks all 38 memories/8,960 unknown storage INIT bits and unknown read INIT.
Its accepted scope explicitly names inclusive L1666/S898/M99 command-to-Done,
while retaining live-entry/dependency/queue rank as open global obligations.

Actual SBY model preparation reports 9.85 seconds and 156.84 MB peak. This is
one proof-model preparation observation, not a stable benchmark or physical
throughput measurement. The QEMU-only VM, immutable tool image digest and
Yosys0.68/SBY0.68/Bitwuzla0.9.1 remain unchanged. There is no extra VM,
Rosetta installation, device repeat, fallback job or time-cap extension.

| Artifact | SHA-256 |
| --- | --- |
| DUT | `0a484eb674738307d8ac541ebfa4a873d27c6b52c10a98939d3f6b02dae065de` |
| Source set | `d0929614c115d9a9651c3af40993d41068401a6dc926ea1458c1517350980e18` |
| Properties | `b1279066204cd91eba353ad99a8a4625102e0d370fff2348a39627c91a9742e6` |
| Result | `50f6e626841a4e746c34c2c6bf767a52252e8017b3e5a0a6eccd0ab64d5cf8a2` |
| Receipt | `ff2a15ba31884f99e72b7cb94bd203d67e1b40499e94ea3681e00519847e03ad` |
| Helper report | `957730b66955a1ef05ae1ff9fa8e1abaea7e5459c7409b926101767aaa5d8d74` |
| Pointwise miter | `779392fc3cf03370279a50aff4e834a324ca0bee512ecbb7c68738a7e0215eb3` |

## Retention and remaining scope

After review and post-qualification checks, Docker is empty and the original
eight protected volumes are exact. Diagnostic output bytes are verified against
retained copies before owned-volume cleanup; diagnostic/device before-after
inventories match. The native-heavy/Docker window is explicitly released before
light sealing/documentation. The peer's next HEAD-bound gate waits separately
for the final documentation commit notice.

The collector verifies the complete inventory before and after atomic rename
to `artifacts/phase6-direct8-explicit-latency-20261017-r1`: 980 listed files
plus inventory, 53 MiB. Inventory SHA-256:
`421f73953e7492e30b3b482c58db736aa993e2f3a8f9108b42c93896bc50a8d1`.
No compiler cache or copied historical archive is bundled. All previous
timeouts remain immutable; their task identities receive no fabricated receipt.

This closes explicit command-to-Done latency for the original direct8 binary
model, not dispatch waiting, dependency drainage or ordered public retirement.
Live-entry/dependency/queue progress composition, useful formal Store
reachability, the positive 11,718-edge theorem and aggregate Phase 6 remain
open. These receipts do not certify the PRX100 word-read-core d2 identity or
four-state production behavior. No PRX100 target, portable production library,
README/Phase7 status section or chip throughput is changed by this work.

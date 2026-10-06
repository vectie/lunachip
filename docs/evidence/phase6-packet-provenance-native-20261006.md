# Public packet provenance native checkpoint

The independent public-packet monitor and its additive fixture profiles pass
the targeted native checkpoint at clean source
`51f3fb5a1ccb3a68212f7c5355f0aad2c3a93767`. All 113 affected tests pass and
all 133 older formal artifacts remain byte-identical. This validates generation
and a real-DUT LunaWave replay, not execution or acceptance of the generated
SystemVerilog monitor. Phase 6 remains in progress.

## Source and validation

The clean frozen checkout is
`/private/tmp/lunachip-packet-provenance-native-20261006.vlphin`.
Every command below returns actual child exit 0; each records the same HEAD
before and after, with zero-byte full Git status on both sides.

| Log label | Check |
| --- | --- |
| clean-info | interface generation |
| clean-fmt | formatting without source changes |
| clean-check | native check with deny-warn and warning73 |
| clean-targeted-tests | 100 formal-package, 12 fixture-CLI and one real-DUT provenance test; 113/113 |
| clean-exporter-build | native fixture exporter build with deny-warn |
| clean-artifact-compatibility | fresh exports and exact old/new inventory checks |
| clean-boundaries | dependency isolation and source-size checks |
| clean-bootstrap | existing native LunaChip counter example |

The affected tests run serially with `--no-parallelize -j 1`; the full native
matrix and independent RTL/synthesis/formal matrices are not rerun for this
supporting slice. The previous complete native checkpoint remains separate.
The only public API additions are the two approved queue fixture enum cases.
No production generator, simulator backend, device ABI, tool lock or runner
changes accompany them.

The original working-tree native replay returned exit2 because its test used
the output API for public input pins. The corrected test resolves actual input
nodes and rejects missing or unknown values. Its working-tree retry and the
clean frozen test pass; the original failure and both source contexts remain
retained rather than relabeled as hardware results.

## Packet transfer coverage

The real device accepts distinct raw four-lane packets, all with caller ID 73,
including malformed version and reserved bits in every lane. It saves actual
public values only at accepted admissions and checks the synchronous FIFO
response, subsequent captured head, reservation entry/ticket and ordinal ACK.

The eighth admission coincides with an older FIFO pop and older retirement:
two older packets remain in the FIFO and five older admitted packets remain
unretired. Required flags confirm this corner, full pop/refill, held completion
and every watched transfer. The first epoch drains eight packets; the second
holds seven outstanding packets, then joint reset cancels three live entries,
one captured unreserved head and three queued packets. Four quiet edges expose
no stale completion. A fresh epoch drains eight packets with restarted tickets.
These finite malformed-packet paths issue no memory requests and do not
establish engine ownership, useful Store progress or fairness liveness.

## Artifact preservation and claim boundary

Thirteen older bundles retain exactly 133 files, with equal inventories, bytes
and SHA-256 values. Their sorted comparison manifest is
`988edb0019a8d998a784b4fdee998735da89aeaa4bdabd123fb808e72d69bcd4`.
The two new profiles retain 20 generated artifacts, with inventory manifest
`a97b074217075c8fa1bf815d1f240d987d7d903786202fc8041b3e291a5cfdca`.
This new inventory is not a proof result.

Both profiles retain all 115 observations, the unchanged production IR/RTL and
the exact Boolean adapter. Its existing 19-helper pointwise evidence matches
the same source hashes; it is reused, not rerun, and supplies neither four-state
nor sequential device equivalence. The property manifest declares four public
assumptions, seven assertions and three covers. Positive safety selects all
seven assertions; its cover selects only p13; the negative selects only p12.
Restoring the one checked lane-two bit-zero expression reproduces the complete
positive harness. Raw saved packet and transfer updates remain unchanged;
the identical sticky failure diagnostic naturally records the altered check.

Actual p12 sensitivity, coherent p13 witness and full seven-assertion safety
remain unexecuted. They retain 256 global steps, 128 DUT clocks, timeout 600,
PRE sampling and no fairness assumption. The unchanged runner must preserve
all emitted DUT memory assertions in safety tasks. Do not replace the original
queue/retirement/dependency timeouts or the mandatory fairness, fetched-write
and 8x8 obligations with this checkpoint.

## Retained support

The sealed original support root is
`/private/tmp/lunachip-packet-provenance-support-20261006.0Buu5c`.
Its retained byte-identical copy is
`/Users/kq/Workspace/lunachip/.phase6-packet-provenance-native-evidence-20261006`.
The 415-file manifest SHA-256 is
`4926b3cb320a80bf394f371fea7accd10d0b42558965302aa61f9ec7e2a326b4`.
Root and independent review verify artifact bindings, source contexts and the
selected profiles. Root verifies recursive copy equality and all 415 manifest
digests with actual exit 0. No new output may be written into either sealed root.

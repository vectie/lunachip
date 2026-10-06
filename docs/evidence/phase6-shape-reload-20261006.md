# Dynamic shape reload checkpoint

The existing 8x8 device with reduction capacity 17 passes native validation and
independent pinned RTL replay for a 3x5/K17 computation followed by an 8x8/K1
computation. Both persistent result slots, all 4096 host bytes and every cycle
of all 30 public outputs match their independent reference. This completes
the fixed workload's differential acceptance, not general shape safety or the
complete Phase 6 gate.

## Source and native validation

Implementation commit is `aad4b602222c8b0d30105d2f5e94690303be94fd`.
The clean frozen checkout is
`/private/tmp/lunachip-shape-reload-native-20261006.u6CAEu`.
The only public API addition is the existing validation package's fixture
generator; host and CLI selection are additive. Production hardware generators,
IR semantics, simulator, device ABI, tool locks and runners are unchanged.
The five focused fixture files remain below 500 lines each.

All eight clean native commands return actual child exit 0, with unchanged
HEAD and empty full Git status before and after:

| Log label | Check |
| --- | --- |
| clean-info | generated public interface |
| clean-fmt | formatting without source changes |
| clean-check | native deny-warn check, including warning 73 |
| clean-targeted-tests | one workload test and 14 existing CLI tests; 15/15 |
| clean-exporter-build | native fixture CLI build with deny-warn |
| clean-artifact-compatibility | new export/self-audit and exact older exports |
| clean-boundaries | product isolation and source-size checks |
| clean-bootstrap | existing native counter example |

Tests run serially with `--no-parallelize -j 1`. The earlier working-tree check
and 15 tests also pass at their recorded dirty `0b1ef76` context; they are not
relabeled as clean implementation-commit validation. Initial interface
generation identified a deprecated int-to-uint conversion, corrected before
the deny-warn checks. IDs remain 501 through 510. No hardware defect or failed
native test is inferred from that warning. The complete native matrix is not
rerun for this supporting workload.

## Workload and independent oracle

The [workload design](../PHASE6_DYNAMIC_SHAPE_RELOAD.md) fixes the 8x8/capacity17
device, host4096/ring4/queue3, mixed A1/B0 source slots, padded host rectangles,
ten commands and two ring refills. A first Fence retires before exact source
reloads. The second compute writes C1; C0 is stored only afterwards, so its
earlier 3x5 result must survive the intervening computation.

The pure signed row-major oracle checks all 79 little-endian int32 words and
all 4096 host bytes, including output padding and untouched regions. The fixed
replay takes 3917 post-reset cycles, with ten fault-free ordered completions,
551 requests and acknowledgements, 472 read bytes and 316 written bytes.
It also checks 16 held-completion edges, all five response-delay classes,
exact ring reuse and both compute schedules: 23/24/15 accepted/elapsed/capture
cycles for 3x5/K17, and 15/16/64 for 8x8/K1. These are fixed workload results,
not throughput or wall-clock performance claims.

All eleven older replay bundles retain exactly 121 filenames, bytes and
SHA-256 values. Root's helper and independent recursive comparisons both
verify them. Comparison manifest SHA-256:
`8e2f60c039a19fdbc153ccc02f61271d9365096887cd3ca2a02c3f962d355802`.
The new eleven-file bundle inventory is
`4031aff5e4aed8eaecc3b73cdf21f22eda16bb0db513bf1da311da230c272bd1`.
Ten implementation source hashes, the actual exporter binary and helper remain
stable across all exports. Reference self-audit Equal is separate from the
subsequent independently executed RTL comparison.

## Actual independent RTL agreement

Strict lint, build, execute and existing typed audit each return child exit 0
on the same clean source. Verilator 5.050 uses the unchanged pinned ARM64 image
and volume transport without networking, with `--Wall`, `-Wpedantic`, `--assert`
and `--no-timing`; no HDL warning waiver is introduced. The build has one job
and disables ccache. Its defined-binary replay uses the existing zero X modes;
this supplies no four-state equivalence claim.

All three original operation receipts retain their exact command hashes,
locked image identity and numeric user 501:20. Independent audit verifies their
bindings and confirms empty stderr and unchanged HEAD/status throughout.
The typed CLI audit reports `result=equal`. Actual and expected TSV are also
byte-identical: two header lines plus 3917 consecutive cycles and 30 outputs,
or 117510 public observations, with every reference bit defined.

| Artifact | SHA-256 |
| --- | --- |
| canonical IR | `c011281a48dd262646c39ca047a343b84310cd20c978eac24da73387a53996a0` |
| stimulus TSV | `7aeda686c4f192fa8fca076ffcc679fb108d918d4d356eab031cdceb3eff7ad0` |
| production RTL | `e974a60907d514ca28a4865068b8173608c1f46f4f67ec208b3e37a8bdac434d` |
| actual and expected TSV | `eeb1d0a3612af259e609fb0c0459185f052844583d807d132d6104a1b2e4849f` |

## Retained support and claim boundary

The sealed original support root is
`/private/tmp/lunachip-shape-reload-support-20261006.ODe7Cm`.
The retained byte-identical copy is
`/Users/kq/Workspace/lunachip/.phase6-shape-reload-evidence-20261006`.
Its complete 530-file inventory plus `outputs.sha256` includes actual native
checks, every export, old comparisons, generated reference, compiled RTL,
all operation receipts, actual TSV and typed audit. Manifest SHA-256:
`4027e40e57a8bf6e8cd8a8e512bfb9f628519f0e55767af5c2792a9ddda6c60f`.
Root and independent review verify recursive byte equality and all 530 original
and retained digests with actual exit 0. Temporary automation build cache is
outside the sealed roots; neither root accepts new output.

The first ordinary evidence-copy attempt encountered host disk exhaustion.
Its incomplete duplicate is preserved separately at
`/private/tmp/lunachip-evidence-seal-20261006.moOwcl/incomplete-shape-reload-copy`
and is not accepted evidence. A fresh copy-on-write clone then passes the full
byte/digest checks above. The sealed original is untouched throughout; no
unrelated files or earlier evidence are removed.

This establishes finite production RTL agreement for the declared dynamic
shape and exact reload workload. General ownership, leases, cursors,
arbitration, fetched write-path safety, controller-derived fairness deadlines
and all remaining Phase 6 formal gates stay mandatory. The all-seven packet
provenance safety timeout remains unchanged; this replay cannot replace it.
No synthesis, physical timing, FPGA, PDK or fabrication claim is added.

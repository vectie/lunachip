# Projected dependency witness experiment on 2026 10 05

A separate experimental run completes the priority cover and all four trace
formats in 161 seconds. Its unmodified Yosys witness replays successfully on
that same projected model at the exact selected cover/global step 21. Replay
against the older unprojected model fails before search on a generated witness
name mismatch. The ordinary runner and typed receipts remain unchanged;
this is neither a production safety result nor completed runner integration.

## Exact input and execution scope

The input is the validated fifth-run
[trace projection](phase6-trace-projection-20261005.md), with 1,942 conservative
private wire renamings. Its original source hashes, complete preparation,
selected task and structural controls remain retained. An external, one-purpose
MoonBit driver imports the prepared `after.json`, without repeating user prep
or skipping SBY's standard multiclock/formal preparation. It retains the exact
priority cover, four host assumptions, 256 global steps / 128 DUT clocks,
timeout 600 and `smtbmc bitwuzla`; no fairness is added.

The unchanged locked image, versions and isolated volume policy are reused.
Source context is frozen at `c2a14f2`; the canonical DUT source binding is the
earlier projection's retained source set, not a newly generated receipt for
that checkout. The strict-help-compiled driver runs through its exact archived
Wasm binary, allowing the native suite to finish without another compiler.
Complete commands, versions, script, runtime, JSON, status, logs and all actual
artifacts are archived. Temporary transport resources are removed.

SBY reports the exact p14 cover at global 21 after 22 solver seconds, then
finishes PASS after 161 wall-clock seconds. VCD export takes 114 seconds between
its start and the next-format message, versus 368 seconds in the earlier
unprojected cover. These are two observed runs, not a repeated benchmark or a
device-performance claim; this experiment also changes the frontend path to
JSON import. Verilog testbench, SMT constraints and Yosys witness all finish.

## Replay and import limitations

The replay driver stages the same unmodified 22-state `.yw` for both models
and runs them sequentially with the pinned solver, `-c -t22 --yw`, timeout 120
and no trace dumps. Projected-model replay exits 0, reaches exactly p14 at 21
and reports `Status: PASSED` after 16 seconds. The older model exits 1 before
search: `_witness_.anyseq_auto_setundef_cc_550_execute_22342[31:0]` is absent
from that model. No name mapping, ignored constraints, `--noinit`, forced state
or substituted successful receipt is introduced. Both outcomes are retained.

The import roundtrip is not byte-identical: all 112 netname `signed: 1` fields
are lost by the pinned JSON importer. Removing only those netname fields makes
the complete JSON objects equal. Ports, cells, parameters, attributes,
initializers, memories and numeric bit aliases remain exact in that comparison.
This is a measured metadata difference, not proof of general signed-semantics
equivalence. Direct integration into the existing preparation path must avoid
this additional import and validate its own complete witnesses and bindings.

Independent trace review confirms 22 complete states 0 through 21 plus the final
step 22 marker. All six DUT/ghost status and ticket pairs agree across all states:
264 scalar comparisons, zero differences. This does not extend the original
cover's scope to full dependency safety or other command paths.

The actual old A0 LoadA, caller `ffffffff`, reserves ticket 0, accepts at pre 10
and performs a real one-byte Read at address 1023/tag 0 at pre 14. A matching
response with fault 1 accepts at pre 16 and produces terminal fault 9/ticket 0.
A second syntax-valid A0 descriptor with zero dimensions is already queued.
At pre 18, the old terminal and newer intent coincide; at state 19 both DUT and
ghost publish Pending/ticket 1, head 1 and next 2. The remembered tickets 0 and 1
differ and p14 is sampled at 21. The new command subsequently rejects its own
zero dimensions as Failed/ticket 1; this is not a successful reload.

All other five slots stay Empty/ticket 0. All 48 typed observations are present
and binary at their original widths, with 1,056 matching observation/monitor-alias
comparisons. All four host-assumption predicates hold on the eleven sampled
even pre-edge states 0 through 20, not necessarily on unsampled intermediate
states. The independent review report is retained beside the two run directories.

## Retained evidence

The two complete directories are retained under
`/private/tmp/lunachip-phase6-boolean-20261005.eg54q2/` as
`projected-witness-output` and `projected-witness-replay-output`, with
byte-identical copies in
`/Users/kq/Workspace/lunachip/.phase6-boolean-evidence-20261005/`.
Both complete `outputs.sha256` inventories verify. The scripts are retained
inside those directories, not added as another permanent repository runner.

| Artifact | SHA-256 |
|---|---|
| Cover `outputs.sha256` | `aba2a9e2d135e3a0062a5addb459f5d10756685d717ac5116b319d2803c9f341` |
| Cover `driver.mbtx` | `dbeb6de00da5870d3ba2ad8621a94b73b024490c221086ea237117e57f1bd001` |
| Complete `trace0.vcd` | `1b21b400ac5120c4d250880b2a1ced8664c717ed87fa748a00622379411b6535` |
| Import roundtrip JSON | `8046dae2e2b975e727eab9bb933a2edb9f45bdcef82d5de707a59d17dcfe38e8` |
| Replay `outputs.sha256` | `eec48f5e7b1481a77f0369b553d0041077ad129c7067dfa9546e108ed3a45053` |
| Replay `driver.mbtx` | `e08baf9c801f7ad5e68463e0eb444b45aaec03abf29cb5c24e454b8b822a1b9a` |
| Independent review | `cc8293224b44ed8c861db1a495455b8e8c444348bd9d158b1c04383cae911ddc` |

Required next checks are direct-preparation projection, complete selected
negative counterexample, replay/typed binding validation and then ordinary
runner integration. The full 256-step safety timeout and all remaining Phase 6
requirements are still unfinished. VM resources and tool locks are unchanged.

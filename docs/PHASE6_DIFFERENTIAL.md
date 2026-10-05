# Fetched concurrent differential validation

This slice begins independent RTL validation of the
[Device ABI 1.0 profile](PHASE6_DEVICE_ABI.md). It reuses the pinned Phase 3
Verilator runner and existing differential observation protocol, rather than
introducing another simulator, runner or evidence framework.

## First fixture

The initial fixture elaborates the capability-driven fetched concurrent device:
one row, one column, reduction capacity two, 1024 host bytes, four ring slots,
and queue/retirement depth two. Real encoding-0.2 descriptors execute LoadA,
LoadB, MatMul, StoreC and Fence. The fifth descriptor reuses a slot only after
observed consumer advancement. Signed edge operands exercise actual SRAM,
compute and little-endian host writes; a separate matrix oracle checks the
stored result. The host introduces deterministic request backpressure,
response delay and held completion before releasing it.

`validation/phase6` records every input driven by this byte-memory environment
and every public output, at the existing harness's post-edge observation phase.
The generated input sequence is then fixed: independent RTL replay must not
adapt its inputs to RTL outputs. Comparing every public output checks requests,
tags, handshakes, publication, progress, retirement, faults and counters. It
also checks invalid-qualified payloads as emitted implementation observations;
that stronger fixture comparison does not make those payloads ABI events.

The bundle uses existing canonical IR, SystemVerilog, name-map, harness manifest,
C++ harness, stimulus/expected TSV and identity-bound audit formats. Generation
is deterministic and bounded; failure to finish is an error, not a shortened
successful trace. The pure fixture package does not write files or execute
tools. A focused native `cmd/phase6-fixtures` command exports only to a new
directory and audits actual TSV using the existing typed comparison.

## Verification order and claims

First check fixture generation, trace identity, deterministic bytes, complete
public-port coverage, expected host memory and deliberately mismatching replay
with targeted native tests. Then run pinned Verilator lint, build, execute and
typed audit on the same exported bundle. Keep actual results and existing
runner receipts outside source control; record their identities and outcomes.

A pass covers only this named successful pipeline and its recorded stalls. It
does not complete Phase 6, establish synthesis equivalence or prove all legal
command sequences. Subsequent fixtures must cover concurrent load/compute/store
overlap, both storage slots, capacity and counter wrap, invalid descriptors,
dependencies, partial remote failures, all protocol-fault owners, held terminal
records and joint reset with transport flush. The independent synthesis and
named formal tasks in PLAN.md remain separate required gates. Tool execution
failures must be reported separately from hardware counterexamples.

No first fixture requires changing the stopped Rosetta VM, installing host
tools, assigning MMIO offsets or claiming frequency, area, power or silicon.

## First result and reproduction

The [2026-10-05 scoped result](evidence/phase6-differential-20261005.md)
records strict pinned lint/build/execute and exact agreement for 1,114 cycles,
all 30 outputs, plus the 736-test native slice gate. It does not complete Phase 6.

The [concurrency result](evidence/phase6-concurrent-20261005.md) adds 9,041
cycles with all 30 outputs agreeing, real DMA acceptance during advancing
compute, ordered duplicate IDs and held-completion loader progress. Its
[workload contract](PHASE6_DIFFERENTIAL_CONCURRENT.md) states the measured
predicates and limits. Original fixture artifacts remain byte-identical.

The [reader-poison/reset result](evidence/phase6-fault-reset-20261005.md)
adds 1,261 cycles with all 30 outputs agreeing. Its owned wrong-tag response
arrives during advancing compute; committed loader progress, held cancellation,
compute drainage, an actual pending-response reset and invalidated old slots
are checked. Both earlier fixtures remain byte-identical.

The [signed 8x8 result](evidence/phase6-array8-20261005.md) adds 6,935 cycles
with all 30 outputs agreeing. Both persistent result slots match the signed
oracle, all 4096 host bytes agree, and safe ring refill plus varied delays and
younger bus progress under held retirement are checked. All three earlier
fixture bundles remain byte-identical. Its
[workload contract](PHASE6_DIFFERENTIAL_ARRAY8.md) states the scope and limits.

For a new run, create an empty parent directory and empty `lint`/`build`
directories. `export` creates `bundle` and refuses an existing destination:

~~~sh
moon run --target native --deny-warn cmd/phase6-fixtures -- export /absolute/new-run/bundle
LUNACHIP_VERILATOR_MOUNT_MODE=volume scripts/phase3-verilator-run.sh oci lint /absolute/new-run/bundle /absolute/new-run/lint
LUNACHIP_VERILATOR_MOUNT_MODE=volume scripts/phase3-verilator-run.sh oci build /absolute/new-run/bundle /absolute/new-run/build
LUNACHIP_VERILATOR_MOUNT_MODE=volume scripts/phase3-verilator-run.sh oci execute /absolute/new-run/bundle /absolute/new-run/build
moon run --target native --deny-warn cmd/phase6-fixtures -- audit /absolute/new-run/build/actual.tsv
~~~

For the concurrent fixture, use `export-concurrent` and `audit-concurrent`
instead of `export` and `audit`; the pinned runner commands are identical.
For reader poison and joint reset, use `export-fault-reset` and
`audit-fault-reset` in another new run directory.
For the signed 8x8 fixture, use `export-array8` and `audit-array8` in another
new run directory; the same three pinned runner commands apply.

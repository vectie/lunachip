# Fetched writer rejection and recovery replay

This fixture closes a concrete device-boundary coverage gap: syntax rejection
must preserve an older valid writer intent, while a syntax-valid rejected
writer must publish Failed and forbid fallback to old physical operands or
results. A later successful writer must restore useful computation. It uses
the existing fetched device, host-byte environment, eleven-artifact exporter,
30-output comparison and pinned Verilator runner. No new proof or receipt
framework is introduced, and this fixture does not complete Phase 6.

## Fixed hardware and workload

Use Device ABI 1.0, descriptor 0.2, a 1x1 array, reduction capacity 2,
4096 host bytes, four ring slots and queue/retirement depth3. Both operand
and result slots are real hardware. Ring base is 3072; origin is 0. Host bytes
begin at 165 except five scalar operand locations: 512=2, 640=3, 768=5, 896=7,
1024=9. Results are stored at 1536, 1792 and 2048 with stride 4.

The seventeen descriptors have IDs 101 through 117 in admission order:

| Position | Operation | Expected terminal fault and bytes |
| --- | --- | --- |
| 0,1,2 | LoadA0=2, LoadB0=3, MatMul0→C0 | 0/1, 0/1, 0/0 |
| 3,4,5 | LoadA1=5, LoadB1=7, MatMul1→C1 | 0/1, 0/1, 0/0 |
| 6 | LoadA0 with minor version1 instead of2 | 12/0 |
| 7,8 | MatMul0→C0, StoreC0→1536 | 0/0, 0/4; result6 |
| 9 | Syntax-valid LoadA0 with stride0 | 6/0 |
| 10,11 | MatMul0→C0, StoreC0→1536 | 4/0, 5/0; no operand/result bus issue |
| 12 | StoreC1→1792 | 0/4; unrelated result35 |
| 13,14,15 | LoadA0=9, MatMul0→C0, StoreC0→2048 | 0/1, 0/0, 0/4; recovered result27 |
| 16 | Fence | 0/0 |

All matrices are 1x1/K1. Load/Store unused selectors and fields remain zero.
The malformed version packet is the sole raw-byte mutation; it must not be
silently repaired by the descriptor encoder. Stride0 is syntax-valid and
fails semantic preflight, deliberately testing a different generation policy.
All fault addresses are zero, since these rejections issue no transfer.

Drain setup groups 0..2 and 3..5 before the syntax group 6..8. Drain that group
before the rejected-writer group 9..12. Publish recovery 13..15 only after the
rejection group retires, then Fence 16. Install host ring entries only after
the prior consumer count proves their slots free; publish groups of at most
four using pre-edge capacity. Recovery descriptors are offered together so
Pending dependencies can wait for the successful new generation.

## Required reference checks

Generation must fail rather than shorten an incomplete trace. Check all
seventeen ordered completions, exact faults/bytes/addresses, absence of ring
or transport poison, and final producer/consumer 17. Hold the oldest rejected
writer completion for 32 physical edges and check valid and every payload field
before and after each edge. The host varies request readiness and response
delay while preserving acknowledged request ownership and stalled payloads.

Observe actual accepted and acknowledged public bus transactions. Classify
descriptor reads separately from operands and results; the rejected group
may fetch descriptors and store the unrelated C1, but must perform zero
operand reads and zero writes to the rejected C0 destination. Require:

- 544 descriptor-byte reads, five operand-byte reads and three result writes;
- 552 accepted requests and 552 matching acknowledgements, 549 read bytes and
  12 write bytes;
- exact result values 6, 35, 27 from the independent matrix oracle;
- every one of 4096 final host bytes equals the expected descriptor refills,
  operands, three result words and untouched sentinel bytes;
- no active/capture advance caused by the rejected MatMul; recovery must
  actually execute and capture rather than copy an old result.

Record actual counts, hold length, safe refills, results and scope in
`workload.audit`. A mutated expected result must fail the typed comparator.
The public generator has black-box determinism, complete-port, required-audit
and checked documentation coverage. Original five bundles remain byte-identical.

## Independent gate and limits

Add only `export-writer-fault` and `audit-writer-fault` fixture choices to the
existing CLI. First run targeted native checks; at the completed slice run
the strict native phase gate and commit. Then export into a new external
directory, run unchanged pinned lint/build/execute and audit actual.tsv against
the frozen reference inputs. Retain actual logs and artifact digests and commit
the evidence separately. Do not adapt host replay inputs to RTL outputs.

A pass covers these exact seventeen commands and recorded delays, not arbitrary
malformed packets, partial remote faults, loader/storer protocol poison,
UInt32 origin/counter wrap, liveness or full safety. Those remaining matrix
and formal requirements stay visible in the status ledger.

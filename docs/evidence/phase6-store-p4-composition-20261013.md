# Store p4 checked composition — 2026-10-13

## Plan and claim boundary

Continue from `6cb4b6e`: original capture/lease p2 and produced-storage p3
pass scoped k-induction, while the physical-history payload transport remains
captured-read-basis guarded. This checkpoint targets the exact original
`lc_pending_and_dma_payload` p4, not a weaker conditional replacement.

Parallel source work separates three checked supports: latest-generation words
and eligibility versus physical capture/read history; operational Store
reservation and same-C overwrite exclusion through terminal PRE; and original
13-bit Store cursor, selected rectangle, fault and address composition. An
independent agent audits the premises and actual prepared models.

All support is asserted together with the selected conclusion. Keep original
production/transfer observer equations, projected DUT, both unknown-initialized
C memories and their real synchronous reads, four arbitrary arithmetic
producers, startup-only reset, and arbitrary later reset. No internal premise,
new control cut, SRAM initialization, hardware/API change or fairness premise
is authorized by this work.

Root serializes native compilation and pinned QEMU-only solver runs. Reuse the
existing private runner and one compiler cache outside evidence. Commit plan,
native-qualified inputs, actual engine results and final scoped ledger as
separate checkpoints. Preserve all unsuccessful attempts and sealed history;
do not retry unchanged failures. Phase6 and the full Store conjunction remain
open until their own required gates pass.

## Results

Five focused native tests pass, along with strict native warning checks,
`moon info`, formatting and the existing runner test. Public interfaces and
the user-owned codec file are unchanged.

Private source families contribute twenty reservation, seventeen cursor and
twelve generation/pending/DMA assertions. The original per-generation observer
already connects raw producer snapshots to actual SRAM and synchronous reads;
reuse that direct connection instead of introducing a second physical-history
observer. Original control and transfer observer equations remain byte-identical.

The selected tasks jointly check54 reservation assertions (including exact
original p1),70 reservation/cursor assertions,83 generation-basis assertions
(including original p3), and85 composition assertions (including original p1,
p3 and exact p4). Counts repeat support, not distinct properties. New support
includes legal active shapes, full13-bit cursor bounds, actual truncated-read
fault equivalence, exact physical C address, old-PRE selected-slot exclusion,
pending sampled-word identity, and unconditional generation basis at DMA grant.
Done is deliberately excluded from active cursor bounds and C reservation.

Inputs still require prepared/final-model qualification and actual pinned
engine outcomes. Generated configurations use the existing depth20 k-induction
policy with600-second timeout, not a lowered replacement for BMC256.

## Reservation pass and cursor induction gap

Inputs are committed at `fc2a38e`. The pinned AMD64 Yosys0.68/SBY0.68/
Bitwuzla0.9.1 image runs under QEMU in `colima-lunachip-validation`, with
Rosetta disabled. Container isolation and original source bindings are unchanged.

`store-p4-reservation` passes all54 assertions, including exact original p1,
by basecase0–19 and k-induction in77 wall seconds. Independent prepared-JNY and
final-SMT review confirms54 assertions and the sole startup premise. Both C
arrays and arithmetic producers prune from this control-only selected cone;
the unchanged source still retains them. Four original descriptor memories
retain unknown initialization. No payload theorem is inferred from this task.
Model source digest:
`0a2c8d07e606a838ea4d7e29a6b1675d6c5fa9a1cc7695bfda83e66f41beff56`.

`store-p4-cursor` is **TIMEOUT**, child8,601 wall seconds. Its basecase0–19
passes; induction fails at `lc_p4_cursor_read_fault`, then times out while
writing a217 KiB partial VCD. This is not a complete reachable counterexample
or accepted cursor proof. Source digest:
`7c3510aab9e98163a17c07922ea844097932596eeba7aaa93fc1b3743fb1bf81`.

Source review identifies a missing induction support in this narrower group:
original generation validity/shape used by the expected fault is not checked
equal to physical publication metadata. The already-prepared83/85 groups
jointly assert exact original p3, which includes that equality, and all70 cursor
relations. Run those planned stronger tasks before adding duplicate support.
Retain the unsuccessful task/model/partial trace untouched; do not retry it
unchanged or promote it because a stronger task later passes.

## Generation-basis and full-width cursor composition pass

Independent review of the partial cursor VCD finds complete frames0,10,20,
then an interrupted frame30. At frame0, slot0 ghost metadata is valid/2x1
while physical metadata is valid/1x2; expected fault is1 and actual fault0.
ReadAccept is0 there. This exhibits the missing induction-state link, not a
complete failing read episode or reachable/replay-qualified counterexample.

The planned `store-p4-generation-basis` passes all83 assertions by basecase0–19
and k-induction in125 wall seconds. Original p3 supplies the checked metadata
equality; every70 cursor relation is checked in the same task. No extra helper,
assumption, DUT change or unchanged failed-task retry is needed. Source digest:
`4616a8ed41282f51101f032680641441f2cb2446fd507d2cbde3342d84f78ff3`.

Prepared JNY and final SMT retain83 assertions, the sole startup assumption,
both complete C memories and real held synchronous reads, all four raw32-bit
producer cuts, and four original descriptor memories. All six memory INIT
values remain unknown. Copied source/config and HEAD/status before/after match.
Full13-bit active cursor bounds, generation eligibility, pending sampled-word
identity and unconditional grant basis are now accepted within this stronger
task. The narrower70 task remains TIMEOUT, not PASS.

Next run: exact original p4 with p1/p3 and all checked support together.

## Exact original p4 accepted

`store-p4-composition` passes all85 assertions by basecase0–19 and unbounded
k-induction in94 wall seconds. Exact original p1, p3 and p4 are jointly checked
with every selected supporting relation; no earlier theorem becomes an
assumption. Source digest:
`8cfb1eedaba928886f707cb2c5c8ae6fe4e8f602cd6fff395ff9d8f205845602`.

Independent final-SMT review confirms exact original p4 is a nonconstant
clock-sampled assertion over `lc_pending_and_dma_payload`, not a basis-guarded
replacement. It checks pending/response identity and fault, independently
sampled generation words, successful-read coverage and actual physical port
address, unconditional genuine-grant generation basis, original DMA snapshot,
and public write data/address/bytes/mask. Host address arithmetic remains the
original32-bit modular formula; the checked26-bit expression only qualifies
physical C indexing from the full13-bit Store cursor.

Prepared JNY/final SMT retain85 assertions, exactly one startup-reset premise,
both complete C arrays, actual held read state, all four arbitrary32-bit
production cuts and the four descriptor arrays. SRAM INIT and unreset data
snapshots remain unknown; arbitrary later reset is unchanged. Exact copied
source/config and HEAD/status before/after match for every attempt.

| Actual task | Assertions | Wall seconds | Accepted result |
| --- | ---: | ---: | --- |
| store-p4-reservation | 54 | 77 | k-induction PASS, original p1 |
| store-p4-cursor | 70 | 601 | TIMEOUT; base PASS, failed induction, partial trace |
| store-p4-generation-basis | 83 | 125 | k-induction PASS, original p3 and all cursor relations |
| store-p4-composition | 85 | 94 | k-induction PASS, exact original p1/p3/p4 |

All339 files are sealed under `artifacts/phase6-store-p4-20261013`, including
the failed induction/timeout and partial trace. The `files.sha256` inventory
digest is:
`30759c3a950ed54189cd732f3cbcb0d16f3ebab9193df6dd78323aeadc992698`.
The inventory verifies in full. Evidence occupies approximately73 MiB; the
shared compiler cache stays outside it at approximately652 MiB. No owned tool
containers/volumes remain; the dedicated QEMU-only validation VM is stopped.

Five focused native tests, strict native checking, generated-interface review,
format checks and the runner test pass. Changes are private MoonBit validation
adapters, runner selection and documentation; hardware/ABI/API and the user
codec file are unchanged. Four agents split three source supports and one
independent audit; native/tool execution stayed root-owned.

The exact p4 component is now closed for the original binary2x2/K2/host1024/q3
projection. This is preservation of captured arbitrary producers, not numerical
MatMul. Next compose exact original p5 cursor/progress/terminal and p6 complete
reset observers, then the full Store conjunction and memory bounds. Original
BMC256, overlap/sensitivity, other packet/fetched and explicit-fairness8x8 gates
remain required; no unchanged failed task is retried or reclassified. Phase6
remains open, with no new FPGA, full8x8 or aggregate gate claim.

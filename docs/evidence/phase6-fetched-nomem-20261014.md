# Memory mapped SMT encoding for the fetched Store cover

The full fetched 1×1/K2, host1024, ring4, queue2 useful Store cover remains
open. The prior input-guided array encoding ended in a kernel-confirmed solver
OOM at query832; its separate later-window run timed out before query839.
Both archives remain immutable. This experiment changes only the SMT memory
encoding of the later-window task, not the hardware or host contract.

## Encoding and semantic boundary

Use the pinned `smtbmc --nomem bitwuzla` flow. SBY maps the ten small memories
with `memory_map -formal`, then runs
`formalff -setundef -clk2ff -ff2anyinit` before SMT export. Keep the original
DUT, harness, eight host premises, nonconstant useful cover, input guidance,
clock/reset equations and full initialized transition prefix. Bound1024,
query skip839, timeout600 and the QEMU-only 4CPU/8GiB validation VM are unchanged.
No initial state, output, memory content or cover predicate may be assumed.

The actual memories contain640 physical storage bits: four two-word INT8
banks, two one-word INT32 C banks and four two-word 64-bit descriptor lanes.
All original memory and read initialization is unknown. Audit the generated
formal state rather than interpreting unknowns as zero. Preserve held reads,
clock sampling, simultaneous writes, reset behavior and original address
guards, including the unused second address of the one-word C banks.

## Implementation and qualification

Three agents separately implement the explicit runner variant, review
initialization/address mapping, and review input guidance/full witness
qualification. Root owns pinned tool execution and commits.

1. Add `prepare-nomem` without changing the existing array-encoding paths.
   Validate the exact configuration change and reject any source drift.
2. Inspect pinned mapping semantics and the actual generated model. Retain
   all original source identities, properties and state/read bindings; any
   necessary focused semantic probe must be separately identified.
3. Commit the runner before one frozen-source cover attempt. Preserve the
   actual status and model even for timeout or engine error. Do not enlarge
   resources or shorten the prefix in response to a failed run.
4. If a witness returns, independently check the complete initialized prefix,
   every guided input and known native output bit, all132 read accepts/ACKs,
   the four-byte Store at768 carrying−29, its owner ACK and four ordered
   repeated-ID success retirements with progress2,2,0,4. Seal unique evidence
   without compiler caches and commit the qualified result.

A valid witness establishes only the original existential useful Store cover.
Full fetched symbolic safety, explicit-fairness8×8 and the remaining Phase6
matrix/aggregate require their own results. A different encoding is not by
itself a memory-saving or equivalence claim.

## Runner checkpoint

The explicit `prepare-nomem` variant changes only the late839 engine line to
`smtbmc --nomem bitwuzla`. The old generated configurations remain unchanged.
Two focused deny-warning tests pass, including exact three-variant acceptance
and rejection of changed bounds, timeout, early mapped windows, zeroing and
unselected packed-state/unroll options. Formatting passes and interface
generation produces no public interface changes. Independent configuration
review accepts the single-line encoding delta.

The C banks already have zero address bits in prepared RTLIL. Their original
unsigned address comparisons against1 guard valid reads/writes; invalid reads
select distinct unconstrained values. The mapping audit will retain these
guards and all four original C-related 32-bit anyseq cells. The ten held read
outputs total352 bits; their unknown old-value samples are distinct from the
already-zero-initialized candidate samples created by the clock lowering.

## Mapped export error and qualified memory equations

The actual pinned SBY attempt on clean `7242f85` returns `ERROR 16 32`, child
exit16, wall29 seconds. Yosys stops with the internal SMT-export assertion
`GetSize(subexpr) == 1`; no SMTBMC engine runs and no trace exists. The SMT
file is empty. This is an exporter error, not OOM, safety failure or timeout.

A replay of the exact actual model pass script serializes mapped RTLIL/JSON
before the failed export. The mapped model preserves all12,074 original
non-memory cells/wires, attributes and initialization and every original
connection. Eighteen uninitialized anyinit words retain640 physical storage
bits. Independent equation checks cover640 per-bit write data/mask/address/
hold relations and704 read bits across twenty original read ports. Mapped
reads use final store-chain words, matching the original array SMT relation.
All original bounds, invalid-read sources, held-read, clock/reset and observer
logic remain intact. This qualifies the mapping checkpoint, not complete SMT.

The171-file archive `artifacts/phase6-fetched-nomem-20261014` is sealed by
inventory digest `df4c3a19bdb23ced23b9b19a50f44fe793b6cf871df1570bca55069c1b02bbc6`.
The failed export remains reproducible and is never relabeled as a pass.

## Focused decoder fold and standalone cover plan

The mapper introduces one shared equality decoder comparing two empty
addresses for the depth-one C banks. Equality of these zero-width vectors is
true; the original external address bounds still determine legal access.
Fold only this newly generated decoder with a selected `opt_expr -keepdc`.
Do not optimize the original graph or change any memory/read initialization.
Qualify the actual folded model before executing the solver: the only RTLIL
semantic change must be that decoder's removal and its output connected to
true; harmless serialization order changes do not alter state or equations.

Pinned SBY has no post-mapping user-script hook. A separately named standalone
`yosys-smtbmc` experiment can consume the qualified complete SMT model with the
same cover flags, twelve public input guidance pins, original eight premises,
initialized state0 prefix, query839..1023 and600-second deadline. Retain actual
exit/output and a complete source-bound witness if one returns. This is not
an original SBY or typed task receipt and cannot be inserted into the Phase6
aggregate as one. An independently qualified witness would establish the
narrow original existential reachability fact; aggregate integration and all
other Phase6 gates remain separate.

## Complete folded model accepted before execution

The focused474-line runner has a passing deny-warning test and formatting.
Generation runs on clean `eabaf6f`, exits0 and exports both original modules.
Independent review accepts only the selected decoder removal and constant-true
connection; all14,761 other mapped items/connections and the12,074 original
non-memory items remain unchanged. The original mapped read/write equation
checker passes against the folded model. All eighteen memory words retain640
symbolic initial bits, and all264 original initialization clauses match after
register-name normalization. The exact original eight-premise, zero-assertion,
one-cover roster and sampled useful-cover expression are preserved.

The complete SMT model SHA256 is
`160a6961d5e7972e5d05f1ec9c502f64694599c8c336a85677daff76543c7cb9`.
The private review report binds that digest before direct engine execution.
Generation and semantic review are separate from the600-second solver
deadline; no end-to-end speed or memory comparison is claimed. Configuration
and full-trace reviewers accept the original cover arguments and retain all
initialization/input/known-output/causal checks. The separately recorded
frozen-source solver outcome appears below.

## Folded cover timeout and packed state plan

The standalone solver ran on clean `273ee5b` with unchanged HEAD and full Git
status. The host's 600-second deadline expired after skipped state824, before
query839. The child exit is unavailable because the host wait timed out; the
owned runtime was stopped and its retained Docker state reports exit137 and
`OOMKilled=false`. No SAT/UNSAT result or trace exists. The final kernel capture
has no OOM record. One retained sample shows 4.247GiB, not peak memory or a
controlled comparison. The model remains qualified; reachability is unaccepted.

The 227-file archive `artifacts/phase6-fetched-folded-cover-20261014` is sealed
by inventory digest
`96fde202b2c38ff28a9f5e3a179c90627544b411f649d563761e70f27c07f41c`.
The original exporter error and all prior OOM/timeouts remain unchanged.

The subsequent experiment serializes the same qualified folded RTLIL with
`write_smt2 -stbv -wires`.
This changes representation only: no further memory mapping, optimization,
reset, address assumption, state cut or new hardware. Keep the original
Bitwuzla arguments, including `--unroll`, and the same bound1024, query839 and
600-second solver deadline. Captured pinned `smtio.py` forces unrolling for
Bitwuzla regardless of that flag, but expands functions only over recorded
uninterpreted `declare-sort` state sorts. Packed BitVec `define-sort` state
does not enter that expansion cache. This motivates the experiment; it is not
yet a measured speed or memory improvement.

Before execution, qualify every packed state field's width and distinct range,
all original initialization/transition/hierarchy/premise/cover functions and
the eighteen memory words' 640 unconstrained initial bits. Require unchanged
folded RTLIL and full initialized input/causal trace checks. Record packed
generation and solver outcomes separately, without an original SBY receipt.

## Packed model accepted before execution

Packed generation exits0 on clean `d4fe52c`. Its RTLIL and JSON are
byte-identical to the qualified folded model: no hardware, state equation,
address guard, read/write policy or initialization changes. Independent review
compares all 10,009 original functional definitions byte-for-byte, including
initialization, transitions, hierarchy, premises, sampled cover and helpers.
Every one of the 566 former storage declarations maps to complete, disjoint,
width-correct packed fields. The DUT state sort has7857 bits; the top sort has
9716 bits including its child state. All 264 initialization clauses and the
original register/anyinit/anyseq/witness/property metadata are unchanged. The
eighteen memory words retain640 unconstrained initial bits.

The accepted complete packed SMT model SHA256 is
`50cbbb2cb91dcaecc970ef5c4bc9994a329b2bb1715728d6df30669d43c81177`.
Two focused runner tests pass. Source-bound model and configuration review
accept the representation change; actual cover and full witness qualification
remain required. The packed run keeps the original21 solver arguments,
including `--unroll`, under the unchanged600-second solver deadline.

## Packed engine outcome and next formulation

The packed solver runs on clean `9da19ec` with unchanged HEAD and full Git
status. It builds the complete initialized state0..838 prefix and reaches
query839 in 4 seconds. It then waits for the solver and reports unexpected EOF
at 6:50, child exit1, without a host timeout. Docker records `OOMKilled=true`;
the final VM kernel capture identifies a global OOM kill of Bitwuzla pid3184
in the exact owned runtime, anonymous RSS7800524kB (about 7.44GiB). The retained
container timestamps span about 411 seconds. No SAT/UNSAT result or trace is
produced; this is an engine resource error, not a failed safety property or
evidence that the useful cover is unreachable.

The representations have distinct recorded outcomes:

| Encoding | Prefix or query behavior | Actual outcome |
|---|---|---|
| Original mapped SMT | Export stops before solver execution | SBY `ERROR 16 32`, wall 29s |
| Mapped SMT with one decoder folded | Unrolls through824, never queries839 | Host timeout 600s |
| Same folded hardware with packed state | Full prefix in 4s, queries839 | Child1; kernel-confirmed solver OOM, about 411s |

The 206-file packed archive `artifacts/phase6-fetched-packed-cover-20261014`
is sealed with inventory digest
`32754c9ee65c89171ac064366c875c14eaddf731b04987a62ba88434bd46c932`.
All three new archives total about 81MiB without compiler caches. Their complete
source/model/configuration reviews pass, but none has a witness to qualify.
The frontend bottleneck is reduced in the recorded packed run; its solver
query memory does not fit the 8GiB VM. This is not a general benchmark or a
memory-saving claim for the query itself.

The next formulation to investigate is field-split SMT: reconstruct each
state by concatenating its complete disjoint field variables, keeping the
same original functional definitions and proving the representation is
bijective. Insert literal values only for the existing twelve public input
constraints, never for outputs, private state, internal readiness, memory or
numeric results. Preserve all 264 initialization clauses, free initial memory words,
original address/read/write equations, hierarchy and full initialized prefix.
This may expose constant propagation before expensive solver expansion; it
is not yet implemented or qualified. Keep the 8GiB VM and original premises.

Four current focused runner tests and three narrow audit parser tests pass;
formatting and native interface generation pass without public API changes.
Three agents independently build runners and check model/initialization/address
semantics and outcome/trace qualification. MoonBit skills keep all automation
in `.mbtx`; the documentation skill keeps the evidence and claim boundaries in
this repository. Hardware and the user's codec file are unchanged. Owned
containers/volumes are cleared and the dedicated QEMU-only VM is stopped.
Useful formal cover, full fetched safety, explicit-fairness8×8 and remaining
Phase6 matrix/aggregate gates remain open.

## Field split plan

The next experiment checks only the original first late query at global
step839, with every state0..839 and all 839 transitions retained. It is not a
replacement for the entire query window839..1023. An UNSAT result at839 would
leave later reachability open; a SAT result requires an independently checked
full-prefix certificate before any useful-cover claim.

Construct each packed state from its complete disjoint storage fields in
descending bit order. Recursively construct the DUT child state rather than
leaving it as an opaque7857-bit variable. Every remaining leaf is a fresh
width-correct bit-vector; Boolean storage retains its original one-bit
encoding. This is a bijection with the original packed state before the
already approved public input constraints are applied. The same twelve
public inputs at states0..837 may be literal fields. All other fields,
including clock, reset history, held reads, initial memory and the free tail
at838/839, remain symbolic. Original hierarchy equations connect child inputs.

Copy the qualified packed model byte-for-byte. For each state, assert its
original `_u` and `_h`; retain `_i` and `_is` at0, `_t` between every adjacent
pair, and not-`_is` after0. Retain the explicit guidance equalities even when
the corresponding fields are literal. Query the unchanged original cover at
839. No native output, private-state value, numerical result or extra fairness
premise enters the formula. Request all full packed states as a candidate
certificate; parsing/model validation is not a safety theorem.

A focused MoonBit compiler validates field completeness, nesting, widths,
the exact input whitelist and pairing, original model hash and formula roster.
An independent review binds acceptance to the emitted query hash before
engine execution. A separate pinned direct Bitwuzla runner uses the existing
QEMU-only8GiB VM, 600-second host limit, immutable inputs and source freeze.
Its actual SAT/UNSAT/error/timeout and raw values remain standalone evidence,
never a fabricated SymbiYosys status or typed aggregate receipt. Owned runtime
resources are removed after recording their state; the VM stops at checkpoint.

## Field split implementation

`scripts/phase6-fetched-field-split.mbtx` emits the initialized first-query
formula from the sealed plain and packed models. Their inventories and
selected model/guidance hashes are checked before generation. All 565 leaf
fields cover9716 bits with no overlap or gap; the original Bool storage uses
Bool variables and `ite` when repacked. Original one-bit public inputs use
their exact BitVec1 storage and Bool aliases. The child-state container is
expanded without identifying duplicate child input fields.

The fresh `artifacts/phase6-fetched-field-split-20261014/query.smt2` has digest
`a14531f2e786c355f796ec23ea8118c8ebd44545d234a9b4dddecccc837d0db7`.
It retains10056 explicit input equalities and substitutes the same10056 field
occurrences; all other leaves remain fresh. The qualified original packed
model is a byte-identical prefix after the two SMT setup commands. `QF_BV`
describes this actual array-free, uninterpreted-function-free model; it is
not the former driver's conservatively inferred `QF_ABV` declaration.

`scripts/phase6-fetched-field-run.mbtx` runs the positional SMT file with the
pinned Bitwuzla CLI. It verifies the query inventory and independent review's
hash, records actual help/version, full source freeze, dedicated VM size,
kernel snapshots and runtime inspection, and preserves raw model values.
Three compiler tests exercise balanced concatenation and complete/invalid
input guidance; the runner's audit/argument test passes. Independent full
formula qualification and solver execution are still pending at this commit.

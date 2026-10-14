# Fetched input aliases and initialization

## Scope

This Phase6 experiment derives redundant input fields and specified initial
values from the original fetched Store model equations. It continues the
[qualified recurrence encoding](phase6-fetched-nomem-20261014.md), whose
first-query839 search ended in a kernel-confirmed solver OOM without a verdict.
The DUT, original address/read/write equations, host premises and initialized
prefix stay unchanged. The objective is an independently checked useful Store
cover, not a safety or fairness theorem.

The exact profile is fetched1×1/K2/host1024/ring4/q2 with its existing R1/H1/C1
host. The canonical IR, model and native trajectory remain those already
qualified. The original twelve public inputs are guided at states0..837;
states838/839 remain free. The formula retains all840 states,839 transitions,
eight original host premises,13417 assertions and the original sampled cover
at839. It checks only that first late query, not the whole839..1023 window.

## Original equations

The13 hierarchy input equalities determine44 child storage fields: twelve
singletons plus32 distinct producer bits ordered31 down to0. Derive each
field from its exact original equation and alias definition. Boolean storage
requires an equality-to-`#b1` conversion when its parent source is BitVec1;
clock and reset remain BitVec1. Producer fields use exact one-bit extracts of
the original full-width producer value, without truncation or reordering.

The initialization functions contain263 distinct field-to-constant equalities,
200 in the child and63 in the parent. The existing264-clause count includes
the parent invocation of child initialization. Replace only these263 state0
declarations with their specified constants, and retain both original
initialization functions and every original `_i`/`_is` assertion. Clock
initialization0 and its original `bvnot` recurrence may then expose parity;
no native clock values or private trace observations supply this substitution.

Keep18 independent unknown initial memory words640bits,11 undefined slices
166bits, all other uninitialized registers and original invalid-read anyseq
sources. Specified zero-valued held-read sample fields do not imply that their
memory words start at zero. Masking, disabled reads, address bounds and final
store-chain reads remain in the byte-identical original model.

## Construction order

Each child input definition references direct parent field symbols, or the
already approved public input literal, never the same-step whole state it
helps construct. The parent input and clock fields must exist before their
child aliases. Existing next-state recurrence helpers continue to reference
only the completed preceding state. This preserves an acyclic declaration
graph without a state cut.

Leave the30 parent output shadows unchanged. Replacing them is a separate
possible experiment: it requires building a complete7857-bit child state
before the9716-bit parent state to avoid a same-step definition cycle. Do not
include it in the initial input/initialization run.

## Implementation and review gates

1. Consume the sealed recurrence archive inventory
   `024fe2d75eb7d5e1c6e4535cbe9348e15ce172267c110c239c34f63338ad3ff4`.
   Require model digest
   `50cbbb2cb91dcaecc970ef5c4bc9994a329b2bb1715728d6df30669d43c81177`
   and baseline query digest
   `fe42575f151882a2ad5a9439f2d3d6650704d02c69c507094c7651cfee272b03`.
2. Implement a focused MoonBit `.mbtx` compiler deriving aliases and constants
   from original SMT syntax. Check exact widths/sorts, unique targets,
   complete producer inverse and declaration order. Preserve original model
   and every non-replaced query command. Expected changes are36960 input
   declarations plus263 initial declarations, leaving40542 fresh fields.
3. Independently parse the original equations and mechanically audit every
   replacement, unknown-state exclusions, original initialization, address
   semantics and full-prefix command sequence. Bind acceptance to the emitted
   query hash before running an engine. A separate reviewer checks certificate
   and claim boundaries.
4. Commit implementation and qualification checkpoints. Freeze full Git status
   and HEAD during the actual solver job; do not edit tracked files or commit
   while it runs. Preserve raw SAT/UNSAT/error/timeout, model values, kernel
   logs and owned-runtime inspection separately from model qualification.
5. If SAT returns, require all840 complete state values and independently
   validate them against the unmodified original model, original guidance and
   cover. Reconstruct original public aliases and audit native known-mask
   outputs,132 reads/ACKs, numeric Store−29 at768, owned write ACK and four
   ordinal retirements. Observing a certificate is not search guidance.
6. Seal unique inputs, models, audits and actual outcomes without caches.
   Reconcile status/formal ledgers and stop the dedicated VM at checkpoint.

## Resources and acceptance

Use the existing dedicated4CPU/8GiB/20GiB Colima profile, QEMU only, with pinned
AMD64 Bitwuzla0.9.1 from the existing toolchain image and a600-second host
deadline. Reuse the source-frozen direct solver runner. No Rosetta installation,
RAM increase, extra premise, output/native-private pin, initialization waiver
or shortened prefix is part of this experiment.

UNSAT at guided839 says nothing about later queries or unguided reachability.
SAT without a complete validated certificate is not an accepted cover. Direct
solver evidence must not fabricate an SBY status or original typed receipt.
Useful cover, full fetched safety, explicit-fairness8×8 and remaining Phase6
matrix/aggregate gates remain open until their own evidence passes.

MoonBit automation and repository-documentation skills keep this implementation
private, the equations explicit and the evidence in LunaChip. Three agents
separate implementation, equation/formula audit and unknown-state/certificate
review; the main agent owns execution, documentation and commits.

## Implementation

`scripts/phase6-fetched-alias-init.mbtx` parses the original child input alias
definitions, parent hierarchy equalities and initialization clauses. It
inverts the producer concatenation and typed singleton conversions, obtains
parent values from the qualified state constructors, and replaces only the
selected declarations with definitions. Existing recurrence helpers and all
original model/assertion/certificate commands stay unchanged. The serialized
query has one additional terminal blank line, not an extra SMT command.

The fresh query digest is
`352924e0027e2532d55e54487a1c6526beb13906dbe00c830a9f6cbb1a3eccd1`.
Its equation-bindings table digest is
`2f4748cc5a0d102d2084c7bec0f57ded5e985e4d2becf695274d28c933278c2e`.
Six prepared files bind the original model/layout/guidance, new query/table
and sealed baseline reference. Generation reports36960 input definitions,
263 state0 constants and40542 fresh declarations. The query checks839 only
and requests the same840 complete states plus original cover value.

Four focused tests pass under native deny-warning checking: token-exact AST
parsing, producer inverse/duplicate/sort rejection, Boolean versus BitVec1
conversion, and actual-model exclusion of unknown memories/address slices/
anyseq. Formatting and interface generation pass without public API changes.
Independent emitted-formula qualification is pending; no solver result is
accepted at this implementation checkpoint.

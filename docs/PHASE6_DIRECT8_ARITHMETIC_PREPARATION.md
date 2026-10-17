# Direct8 arithmetic preparation and induction isolation

Reduce proof-model preparation cost separately from qualifying command-age
invariants. The accepted checkpoint remains joint55; the earlier full60 and
age/potential59 timeouts remain immutable and do not identify a false predicate.

## Pointwise arithmetic substitution

The proof-only DUT retains sized add/sub helpers that elaborate per-bit
carry/borrow loops. Add an opt-in adapter replacing only those exact helper
bodies with same-width `a + b` or `a - b`. Discover operation/width pairs from
original typed IR, check complete original emitter bodies, and record both
body digests. Restore the exact previous DUT by reversing these replacements.
Ordinary production emission and all older task inputs remain byte-identical.

Before any adapted device measurement, require pinned Yosys SAT equivalence
for every helper over all defined binary operand assignments, including all
64 address bits. A high-bit-mutated 64-bit result must fail its selected proof
with an actual SAT model, not a parser/tool error. This is a pointwise binary
qualification, not four-state production equivalence or device progress.

The existing formal model already uses arbitrary binary assignments for
unknown initial storage. Keep every such assignment free: no memory cell or
read INIT is initialized, constrained, cut or replaced. Keep all 38 memories,
8,960 storage bits, address-knownness helpers, full UInt13 cursors, UInt64 DMA
arithmetic, payloads, clock/reset and original seven public premises unchanged.
Fixed-width modular overflow/underflow is preserved rather than narrowed.

## Separate measurements

Use a focused MoonBit diagnostic, not a new device-proof runner or receipt
framework. After pointwise qualification, prepare baseline and adapted versions
of the same age/potential59 selection sequentially through the same pinned
Yosys script. Retain full commands, versions, source hashes, logs, stage times
and memory-parameter inventories. Compare actual memory parameters including
unknown INIT/read INIT. A single pair is an observation, not a stable benchmark
or a causal explanation of earlier timing variability. Retain regressions too.

Then use the existing typed device task, standard runner and independent review
for two opt-in profiles, without changing any assertion body or observer state:

| Profile | Selection | Selected / actual assertions |
| --- | --- | --- |
| Arithmetic bounds and history | Accepted55 plus potential bounds and age history | 57 / 141 |
| Arithmetic age and potential | Accepted55 plus all four original age/potential groups | 59 / 143 |

All support remains asserted, never assumed. Run the first profile and at most
one distinct second profile, retaining original k-induction32 and 600-second
caps. Only the second can qualify all four age/potential groups. Neither selects
the explicit command-latency assertion, proves the 11,718-edge deadline or
waives remaining Phase6 gates. Timeouts do not diagnose a missing invariant.

## Commit and resource boundaries

Commit this plan privately during the peer's main/source and native/Docker
freeze. Implement and add exact-body, selection, regeneration and width/address
regressions without touching shared production work. After explicit release,
run targeted checks and fresh preflight in one cache, qualify helpers, measure
the preparation pair, and run at most two device jobs in a coordinated window.
Keep failed qualifications and actual outcomes; do not extend caps or run an
unchanged repeat. Commit implementation and input checks separately from final
reviewed results and sealed inventory pins. Release resources promptly after
the final model/receipt and protected-volume checks.

## Candidate checkpoint

On 2026-10-17, the private candidate passed the targeted native typecheck
(`validation/formal`, warnings denied, one process), format checks, and the
standalone Wasm diagnostic/fairness/reviewer tests (2/2, 2/2, 3/3).
These checks do not elaborate or qualify the device model. Native regressions,
pointwise SAT, the preparation pair and both device measurements remain pending
the coordinated source/native/Docker window release. No speedup, arithmetic
qualification or new induction result is claimed at this checkpoint.

The first fresh preflight passed all 82 tests, 26 typed fixture verifications
and 24 comparator audits. Qualification then stopped before SAT: the image's
Rust coreutils `chmod` stalled under AMD64 QEMU, and a separate `timeout` probe
panicked. Retain that attempt, including its verified-empty output cleanup.
Use the ordinary runner's pinned permission initializer, single-purpose
pinned-image byte-hash/directory queries, and MoonBit host process timeouts
instead. All loops, parsing and process orchestration remain in `.mbtx`.
These are diagnostic transport changes only; ordinary device runner caps,
the DUT and the original assumptions remain unchanged.

## Qualified preparation observation

On frozen `3b07994eb06022ea3e303cb8441ec48fd7d42999`, the corrected fresh
preflight again passed 82 tests, 26 typed fixture checks and 24 comparator
audits. Pinned Yosys SAT proved all 13 original/adapted helper pairs for all
defined binary inputs. The sole bit-63 mutation of the 64-bit adder produced
an actual SAT model and the expected `-verify` failure. Miter SHA-256:
`779392fc3cf03370279a50aff4e834a324ca0bee512ecbb7c68738a7e0215eb3`.

One sequential preparation pair used the same age/potential59 selection:

| Original helper bodies | Yosys reported time | Peak memory |
| --- | --- | --- |
| Baseline ripple carry/borrow | 92.14 s | 343.54 MB |
| Qualified same-width operators | 7.99 s | 159.48 MB |

This is an observed approximately 11.5x preparation difference, not a stable
benchmark or a causal explanation of earlier timing variability. Unrelated
host builds were observed earlier in the window; only the coordinated VM
workload and this task's own heavy builds were serialized.

Both prepared models retain exactly 38 memories and 8,960 unknown storage
initialization bits, with every read INIT unknown. The complete sorted memory
parameter inventories are byte-identical, SHA-256
`a04b7c2c72c8be717c3c9d5bf7069906ecc3339f407e41ebd7a208a68a1a522b`.
The DUT substitution reverses to the original source exactly; no address,
cursor, memory connection, observer or premise was narrowed or replaced.
Device induction outcomes remain separate from this qualification.

## Bounds and history induction

The first adapted task passed unbounded k-induction32 with its original
600-second cap: `PASS 0 458`, runner exit 0, SBY wall time 345 seconds.
Base steps 0–31 passed at 95 solver seconds; temporal induction succeeded
at 324 seconds and returned pass at 326. Independent review verified exact
compiled sources, clean unchanged private HEAD, seven original public premises,
141 actual assertions and original unknown-memory parameters.

This proves the accepted55 conjunction plus `d8l_potential_bounds` and
`d8l_age_history`: 57 selected groups. It is not the older 57-group full-latency
selection. It does not select potential-step, age-plus-potential, explicit
command latency or the 11,718-edge deadline. Result SHA-256:
`6b20d763756bad54aceaf4b0b44c32ae474c791d47d044e4dd5e32c6d750f8b3`;
receipt SHA-256:
`90d48f629cead41930c5e92ff6f27862faa8874cd2b26f80357dbe7844d0e59f`.
The distinct second job adds the remaining two original age/potential groups;
no repeat or cap extension is authorized by this experiment.

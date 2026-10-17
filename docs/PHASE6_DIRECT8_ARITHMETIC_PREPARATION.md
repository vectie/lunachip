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

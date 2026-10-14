# Fetched Store output shadow elimination

## Scope and construction

Derive the30 parent output shadows from the original hierarchy equations for
the existing fetched1×1/K2/host1024/ring4/q2 useful Store cover. The
[input alias and initialization checkpoint](phase6-fetched-alias-init-20261014.md)
qualified the complete original prefix but its actual solver search reached
query839 and timed out at600 seconds without a verdict. This experiment changes
only solver representation, not the DUT, host premises or hardware semantics.

At every state0..839, construct a separate complete7857-bit child value from
all458 child storage leaves, original layout13..470. Include child `_is`,
every unknown word/slice and all original held-read state. Convert stored Bool
leaves through their existing one-bit `ite` encoding. The full child value
must be defined after leaf470 and before the first parent output shadow471.
It cannot reference the full same-step parent state or any output shadow.

Parse the original parent `_h` equalities to derive exactly30 parent output
definitions, layout471..500: ten Bool and twenty BitVec fields totaling561 bits.
Each calls its unchanged original child output function on the completed child
value. Keep all original hierarchy equations/assertions and full parent-state
constructors. No native output, numeric Store value or private readiness is a
search assumption. Expected replacement is25200 fresh declarations, leaving
15342; variable counts alone do not establish solver performance.

## Semantic boundaries

Retain the original model byte for byte,264 initialization clauses,840 complete
states,839 transitions,13417 assertions, eight host premises, original sampled
cover839 and841 value requests. Keep prior equation-derived input/init and
recurrence substitutions unchanged. Twelve public inputs are guided only at
0..837; tail838/839 stays free. This checks the first late query, not the full
1024-state cover window.

All18 physical memory words640bits remain unknown at0, as do ten old held-read
samples352bits. All eleven undefined slices166bits and four invalid C-read
anyseq words stay free at every state. No memory zero fill, address narrowing,
guard removal, masked-write change, final-D read substitution, collision-policy
change or clock/reset priority change is permitted.

## Implementation and qualification plan

1. Verify every entry of the sealed predecessor inventory
   `cfdfcc28a338bd737c914cfcb61b156b027a6db96da97a3356c7ad86d051c426`.
   Pin original model
   `50cbbb2cb91dcaecc970ef5c4bc9994a329b2bb1715728d6df30669d43c81177`
   and predecessor query
   `352924e0027e2532d55e54487a1c6526beb13906dbe00c830a9f6cbb1a3eccd1`.
2. Implement a focused MoonBit `.mbtx` compiler deriving exact child layout and
   original output mappings/types. Test layout gaps/overlaps, Bool conversion,
   unique typed mappings and same-step dependency rejection. Emit only a fresh
   artifact root; keep all build/format caches under `_build/automation`.
3. Independently verify every child bit once in original order, declaration
   precedence, all25200 substitutions and every unchanged query command. A
   separate reviewer verifies unknown-state, initialized-prefix and certificate
   boundaries. Bind qualification to the actual emitted query digest.
4. Commit implementation and qualification separately, then freeze HEAD and
   full Git status during the actual pinned direct-solver job. Reuse the
   dedicated4CPU/8GiB/20GiB QEMU-only VM, exact pinned AMD64 Bitwuzla0.9.1 and
  600-second deadline; no Rosetta, resource increase or unchanged retry.
5. Retain actual process outcome, raw stdout/stderr, runtime inspection, kernel
   logs, selected profile and exact owned cleanup. SAT requires exit0 and all
  840 complete known9716-bit values, then an independent ground check against
   the untouched original model and causal/native known-mask/read/ACK/Store/
   ordinal-retirement validation before accepting a witness.
6. Independently review actual outcome, seal unique evidence without compiled
   caches, stop the dedicated VM and reconcile status/formal ledgers. Direct
   outcomes never fabricate an SBY status or original typed receipt.

The MoonBit automation and repository-documentation skills keep this change
private and documented in LunaChip. Three agents own compiler implementation,
equation audit and semantic/certificate review; the main agent owns execution
and stepwise commits. Useful cover, full fetched symbolic safety,
explicit-fairness8×8 and remaining matrix/aggregate stay open until their own
gates pass. Accepted Store/packet proofs are unchanged.

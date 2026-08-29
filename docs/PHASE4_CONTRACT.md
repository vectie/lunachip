# Phase 4 memory, synthesis, and formal contract

This contract fixes the semantic and evidence boundary for Phase 4. Canonical
IR and LunaWave remain normative. SystemVerilog, Yosys, SymbiYosys, and solver
results are independently identified evidence about emitted artifacts; no
external tool silently changes LunaChip semantics.

## Synchronous memory model

A memory is first-class module state with a stable memory ID, nonempty name,
data element type, positive depth, explicit bounds policy, ordered read and
write ports, read/write collision policy, and multi-write policy. It is not an
opaque foreign module or a collection of ambient simulator callbacks.

Phase 4 supports one exact rising-edge clock domain per memory. Every port of a
memory must use that domain. Multi-clock memories remain rejected until Phase
5 defines cross-domain ordering and CDC evidence.

Each read port declares:

- a stable read-port ID and name;
- an unsigned address of width `max(1, ceil(log2(depth)))`;
- an optional one-bit enable;
- exactly one cycle of synchronous latency;
- disabled behavior of either holding the prior read result or producing X;
- a unique typed read-result node.

Each write port declares:

- a stable write-port ID and name;
- the same exact address type;
- data exactly matching the element type;
- an optional one-bit enable;
- either a whole-element write or a mask whose granularity divides the element
  width exactly.

Cells and registered read results begin X. Phase 4 does not infer zeroed SRAM,
emit an `initial` block, or treat host allocation contents as hardware state.
Tests that compare known values must initialize the addressed cells through
declared writes.

## Edge and unknown semantics

At an active edge, every address, enable, mask, write datum, old cell, and old
read result is sampled from pre-edge state. All selected cell and read-result
updates commit simultaneously, followed by ordinary combinational settlement.

A known-zero enable disables its port and a known-one enable activates it. An
unknown enable merges the enabled and disabled outcomes bit by bit. A known-zero
mask bit preserves its granule, a known-one bit writes its granule, and an
unknown mask bit merges old and new granule values. Fully known out-of-range
addresses either raise the declared simulation fault/property failure or
produce X under the declared bounds policy. An address containing X cannot
select a cell and follows the same fail-closed policy.

When read and write ports access one address on the same edge:

- `ReadOld` loads the pre-edge cell value;
- `ReadNew` loads the final value after masks and deterministic write
  priority are resolved;
- `NoChange` holds the prior registered read result;
- `Undefined` loads X;
- `Reject` is rejected during construction when the configuration permits an
  unresolved collision.

Multiple writes to one address are invalid unless the memory declares a stable
port-priority rule. Phase 4 uses lower write-port ID as higher priority. The
rule applies independently to each mask granule; it is serialized and emitted,
never inferred from loop or container order.

The reference simulator records only addressed cell updates for an edge; it
does not clone a depth-sized cell array or allocate a depth-sized collision
table. The RTL backend likewise resolves multi-port priority only for words
named by active port addresses. It never emits a whole-memory combinational
copy or depth-wide clocked commit loop. This keeps edge work independent of
memory depth apart from intentional initialization, snapshots, and reads of
the persistent cell store. LunaWave preparation rejects either one memory or
the aggregate module memory capacity above 1,048,576 cells with a typed
resource-limit error during a preflight pass, before allocating any cell
arrays. Canonical IR and RTL emission are not restricted to that
reference-simulator limit.

## Library components

The first reusable components are:

- a synchronous FIFO with explicit depth, ready/valid ports, occupancy, and
  overflow/underflow prevention;
- a banked memory with explicit bank count, deterministic address split, and a
  declared same-bank arbitration rule.

The components elaborate through the public LunaWire memory API. They do not
reach into LunaWave internals or provide a second behavioral implementation.
Reference queue/array models may exist only in tests as independent oracles.

## Formal property model

Formal export covers assertion, assumption, and cover declarations with stable
property IDs, exact predicate mapping, one observation clock, and an optional
disable condition. The emitted harness and canonical task manifest bind:

- canonical design and RTL SHA-256 identities;
- property and assumption sets;
- tool, version, solver, engine, mode, and command;
- bound for bounded model checking or the exact induction/unbounded method;
- result, exit status, counterexample identity, and all output digests.

Result types keep bounded reachability separate from unbounded proof. A bounded
pass may be reported only as “passed through depth N.” Only a successful named
induction or other declared unbounded task may carry an unbounded-proof result.
Failure preserves a canonical counterexample artifact; unknown, timeout,
unsupported, and tool failure are distinct non-pass results.

## Phase gate

Phase 4 passes only when one fail-closed evidence command proves all of the
following against pinned, digest-addressed external tools:

1. strict canonical IR/codec tests retain byte-identical schema-1/2 artifacts
   and cover every schema-3 memory policy;
2. LunaWave and pinned Verilator agree for whole and masked writes, enable
   behavior, non-power-of-two bounds, every supported read/write policy, and
   deterministic multi-write priority;
3. pinned Yosys synthesizes every supported emitted memory form with warnings
   treated according to the locked policy and produces archived reports;
4. FIFO safety passes a declared bounded task and a separate selected
   induction/unbounded task;
5. deliberately broken FIFO, bounds, and protocol fixtures fail with the
   expected property and a retained counterexample;
6. all manifests, commands, versions, inputs, reports, counterexamples, and
   normalized comparisons are content-digested;
7. the full warning-strict native MoonBit gate and dependency-boundary checks
   pass.

The authoritative command is `scripts/phase4-gate.sh [EMPTY_RUN_ROOT]`. It
runs the focused codec gate, the full native phase gate, tool-boundary
self-tests, the LunaWave/Verilator memory differential gate, the Yosys
synthesis matrix, and the formal task matrix. The aggregate captures a
content manifest of every repository input before and after the run and fails
if either HEAD or any input byte changes. Its child evidence and all retained
logs, reports, RTL, normalized comparisons, executables, counterexamples, and
witnesses are covered by a second content manifest. A child `pass` marker is
never sufficient on its own: the aggregate rechecks the locked fixture counts,
cycle total, exact negative assertion labels, synthesis claim boundary, formal
result classes, witness identities, and source-drift receipts.

This gate supports only named synthesis and formal claims. It is not FPGA,
timing-closure, physical-design, fabrication, or silicon evidence.

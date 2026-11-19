# Phase 5 asynchronous-reset contract

This document freezes the first complete asynchronous-reset vertical slice.
It is additive to the existing synchronous-active-high API and schemas 1--3.

## Canonical representation

Schema 4 register records may carry either `synchronous` or `asynchronous`
mode and either `active_high` or `active_low` polarity. `ResetSpec::new` and
`ModuleBuilder::synchronous_reset` retain their exact synchronous-active-high
meaning. LunaWire exposes separate typed asynchronous-reset values and
register constructors; an asynchronous reset cannot be passed accidentally to
an existing synchronous-register constructor. Bit-synchronizer primitive
resets remain restricted to synchronous active-high by their own contract.

Schemas 1--3 are not extended. Decoding and re-encoding their artifacts keeps
the historical byte representation. Existing schema-4
`synchronous active_high` records also keep their exact bytes.

## Reference event semantics

Reset controls are one-bit four-state values. Active-low controls are inverted
before selection. At every atomic timestamp the simulator performs exactly:

1. validate the complete event without mutation;
2. apply all drives in canonical name order and settle combinational logic;
3. compute every asynchronous-reset register result from one shared pre-reset
   state, then commit all those results together;
4. settle again when asynchronous state changed;
5. compute every active-domain candidate from the shared post-asynchronous,
   pre-clock state, with reset above enable and next state;
6. commit all selected register, memory, and CDC state together and settle.

A known asserted asynchronous reset loads its declared value. A known
deasserted reset retains state when there is no edge. An unknown reset merges
the reset value with retained state bit by bit. On a coincident active clock
edge the same normalized reset instead selects between reset and the ordinary
edge candidate, so reset retains priority over enable and next state. Assertion
and deassertion therefore take effect before clock sampling. Event drive order,
domain order, and register declaration order cannot affect the result.

Snapshots contain the already committed state and current reset input value,
so restore and replay reproduce the same next atomic event without hidden
reset queues.

`Simulator::set_input` is deliberately a staging/debug API: even followed by
`settle`, it never changes sequential state or creates a hidden timestamp.
Drive-only reset transitions use the public `TimestampEvent::drives_only`
constructor and `apply_event`, preserving simultaneous multi-input batching.

## CDC and emitted RTL

An asynchronous reset is a special state-control sink, not ordinary sampled
data. The CDC pass admits it only when its complete provenance is exactly one
declared asynchronous source and rejects neutral, timed-domain, or mixed
provenance. Synchronous reset controls retain the exact destination-domain
rule. This digital rule does not claim recovery/removal timing closure or safe
physical reset release; implementation flows must still use a reviewed
per-domain reset-release strategy.

SystemVerilog lowering emits one `always_ff` per register. Asynchronous reset
uses `or posedge reset` or `or negedge reset` in the sensitivity list and a
matching highest-priority condition in the body. Synchronous active-low reset
uses only the clock edge and a negated highest-priority condition. Unsupported
backend combinations fail during canonical validation or CDC admission rather
than being rewritten.

### Observed backend conformance gap (2026-10-26)

The canonical semantics above remain the reference contract. Actual Vivado
2026.1 XSim testing found a pre-existing gap in the SystemVerilog backend for
unknown asynchronous reset transitions between clocks: when enable is high,
the emitted reset-edge process can merge the reset constant with next data,
while LunaWave merges it with retained state. This occurs in both reset
polarities, with X and Z (Z is mapped to unknown at the LunaWave boundary).

The synthesis compatibility correction adds an explicit constant asynchronous
reset branch and retains the previous ternary in its other branch. It preserves
the prior emitted behavior, including this gap. Thirty scoped events across
both polarities match LunaWave, and two separate diagnostic events reproduce
the gap for both the corrected and reconstructed previous forms. The baseline
DUT is a checked inverse of the new emission shape; it is not a separately
compiled historical emitter. Exact traces, source identities and reproduction
commands are in the [four-state evidence](../artifacts/pblaze3-reset4state-xsim-20261026-a1/receipt.json)
and [fixture guide](../validation/pblaze3_reset4state/README.md).

Universal four-state asynchronous-reset backend equivalence therefore remains
unqualified. The PBlaze3 reset counter's binary-fault replay, sampled-edge formal
proof, installed vendor XPM simulation and physical timing checks have separate
evidence and do not establish that broader claim.

## Gate

The slice is complete only when tests cover both polarities, known and unknown
controls, drive-only and coincident-edge events, enable/next priority, multiple
registers and domains, all event/domain/drive permutations, snapshot restore,
schema-2 replay execution, exact schema compatibility, and exact emitted
sensitivity/condition text.

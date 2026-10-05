# FluxTile two slot implementation plan

The next feature is real storage isolation for overlapping load, compute, and
store work. This document proposes the next implementation boundary; no
slotted generator, scoreboard, or decoupled engine is implemented yet. The
current fetched-ring device remains serial, with one A, B, and C slot.

Build and exercise storage ownership before extending descriptor bytes or
freezing the ABI. Reuse the existing compute controller and systolic array;
do not copy whole portable engines or introduce a general dependency runtime.

## Current constraints

| Current code | Constraint to remove in the new path |
| --- | --- |
| `execute_operand_banks` in `execute_banks.mbt` | One memory and initialized-prefix counter per lane; writes require execute Idle. |
| `build_execute_graph` in `execute_graph.mbt` | Constructs those banks directly around one shared array and controller. |
| `build_stored_graph` in `stored_execute.mbt` | One C SRAM/valid shape; loads require stored Idle; reads stop during compute/capture; pending reads block commands. |
| `PortableRegisters` and `portable_controller` | Singular A/B/C metadata and one load/compute/store state machine. |
| `queued_controller` | One active head remains occupied until its external completion is acknowledged. |

Adding slot selectors alone would not remove these restrictions or demonstrate
overlap. Draft descriptor 0.1 has no slot references and requires its flags
and reserved bytes to remain zero.

## First implementation boundary

Introduce a new provisional two-slot execute/storage generator with indexed
operand writes, a MatMul selecting A/B/C slots, and indexed held result reads.
Use two physical sets of A/B banks and two C SRAMs, but only one compute
controller, wavefront, accumulator array, and result-capture sequencer. Both
slots must contain real LunaWire memories and state, not host arrays.

Keep the existing constructors unchanged. Add a private operand-storage
construction hook at the existing bank-construction position in
`build_execute_graph`, following its existing completion-control hook. The
legacy branch creates exactly today's banks in today's order. The new branch
supplies selected bank data, initialized prefixes, and independently permitted
load writes. Factor result storage/admission similarly without copying the
compute algorithm or changing legacy node names and allocation order.

Latch A/B/C selections on accepted commands and the C selection on accepted
reads. Live input changes must not select a different bank for an in-flight
read, computation, capture, or held response. Initialization-prefix checks
remain per physical operand bank. Per-slot result validity and stored shape
have one authoritative owner in the new path.

## Proposed ownership rules

The first slice uses small explicit per-slot ownership state, not generic
generation tokens. A legal accepted MatMul reserves its selected A/B sources
and C destination. A load to either reserved source is backpressured; writes
to an unrelated operand slot remain possible during Run and capture. Initially
retain the source reservations through complete result capture and internal
terminal publication. Earlier release is a later measured optimization.

A rejected MatMul uses pre-edge initialization/dimension checks and returns a
checked completion without reserving slots or invalidating an existing C.
A same-edge operand write cannot repair a failed preflight check. A legal
accepted MatMul takes priority over newly offered conflicting operand writes
or C reads on that edge; unrelated operations may still transfer.

An older held C response retains its selected slot through acknowledgement,
including the acknowledgement edge. MatMul targeting that C waits until the
next edge; there is no same-edge release credit. A response for the other C
does not block computation/capture. Response payload and identity stay stable
until accepted.

Accepting a legal overwrite invalidates only its destination C. Only the last
successful capture write publishes that slot's valid shape. Other stored
results survive. Result reads must never expose a partially captured matrix.
Joint reset clears validity, reservations, pending responses, and execution;
it does not manufacture successful or aborted completions.

## Functional tests and commit order

First commit the private construction seams with unchanged legacy canonical
goldens. Then commit real two-slot banks and selected computation, followed by
independent ownership/readback integration tests. Test actual public ports:

- two distinct signed matrices produce two persistent, independently checked C slots;
- different-slot operand loads transfer while the first matrix is running;
- conflicting loads/read requests are backpressured without changing active results;
- a held C0 response remains immutable while computation/capture targets C1;
- selectors changed after acceptance cannot redirect work;
- rejected commands preserve previous C, and initialization does not leak across slots;
- same-edge conflict rules, varied Run stalls, and reset during ownership/capture behave as specified.

Use targeted native tests while implementing, then the existing module gate at
the coherent slice boundary. Reuse canonical emission checks and the matrix
oracle. Do not add a new formal/evidence framework before these contracts have
been exercised; the existing pinned-tool gates remain Phase 6 exit requirements.

## Subsequent device integration

Only after storage isolation works, introduce a separately versioned
provisional descriptor with explicit slot references. Preserve 0.1 bytes and
rejection rules rather than reinterpreting reserved bytes. A single
authoritative slot table then owns availability, shape, generations, and
engine reservations. Prefixes prove physical initialization; they do not by
themselves publish a successful host load or a dependency generation.

Separate dispatch from ordered retirement using bounded in-flight entries.
Host completion backpressure occupies a retirement entry, not the entire
engine frontend. Use internal admission identities because caller command IDs
may duplicate. A failed reload makes that generation unavailable; dependents
must terminate explicitly rather than consume old data or wait forever.

Extract shared transfer mechanics into distinct load and store sequencers,
then integrate them with the one compute engine. Keep one external memory
contract and one outstanding transaction initially. Review reader/load/store
arbitration when those clients exist; the current two-client arbiter is not a
frozen final topology. Preserve global tag validation, owner-specific faults,
committed progress, reset flushing, and ordered exactly-once retirement.

True overlap is established by observed simultaneous compute advances and
unrelated accepted transfers, not by slot count or a capability flag. ABI
freeze, capability publication, and named independent RTL/synthesis/formal
gates follow that integrated feature.

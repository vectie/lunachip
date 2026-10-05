# FluxTile provisional two-slot execution and storage

`slotted_execute_tile` now provides real storage isolation around one shared
compute engine. Its indexed loads, two persistent C results, and explicit
ownership rules are exercised through public ports in LunaWave. This is a
provisional standalone simulation contract, not a frozen device ABI, a
dependency scoreboard, or decoupled host load/store engines. The current
fetched-ring device still remains serial, with one A, B, and C slot. A separate
[serial host-connected variant](PHASE6_SLOTTED_PORTABLE.md) now addresses both
physical slots through direct latched command selectors; it does not dispatch
load/compute/store concurrently.
A separate [concurrent host-engine variant](PHASE6_CONCURRENT.md) now reuses
the same storage/core, with three independent command channels and whole-slot
leases. Its accepted host read/write transactions overlap Run and capture;
it is not yet a slot-bearing queued/ring device.

Build and exercise storage ownership before extending descriptor bytes or
freezing the ABI. Reuse the existing compute controller and systolic array;
do not copy whole portable engines or introduce a general dependency runtime.

## Legacy-path constraints

| Legacy/default path | Constraint removed in the standalone slotted path |
| --- | --- |
| `execute_operand_banks` in `execute_banks.mbt` | One memory and initialized-prefix counter per lane; writes require execute Idle. |
| `build_execute_graph` in `execute_graph.mbt` | Its default storage branch constructs one bank set; the private storage hook now permits selected banks around the same array and controller. |
| `build_stored_graph` in `stored_execute.mbt` | One C SRAM/valid shape; loads require stored Idle; reads stop during compute/capture; pending reads block commands. |
| `PortableRegisters` and `portable_controller` | Singular A/B/C metadata and one load/compute/store state machine. |
| `queued_controller` | One active head remains occupied until its external completion is acknowledged. |

Adding slot selectors alone would not remove these restrictions or demonstrate
overlap. Draft descriptor 0.1 has no slot references and requires its flags
and reserved bytes to remain zero.

## Implemented standalone boundary

The provisional two-slot execute/storage generator has indexed operand writes,
a MatMul selecting A/B/C slots, and indexed held result reads. It uses two
physical sets of A/B banks and two C SRAMs, but only one compute controller,
wavefront, accumulator array, and result-capture sequencer. Both slots contain
real LunaWire memories and state, not host arrays.

Existing constructors remain unchanged. A private operand-storage construction
hook sits at the existing bank-construction position in `build_execute_graph`,
following its existing completion-control hook. The
legacy branch creates exactly today's banks in today's order. The new branch
supplies selected bank data, initialized prefixes, and independently permitted
load writes. Result storage/admission shares the compute algorithm rather
than copying it, without changing legacy node names and allocation order.

A/B/C selections latch on accepted commands and the C selection on accepted
reads. Live input changes cannot select a different bank for an in-flight
read, computation, capture, or held response. Initialization-prefix checks
remain per physical operand bank. Per-slot result validity and stored shape
have one authoritative owner in the new path.

### Ports and storage

The selected first API is
`slotted_execute_tile(rows~, columns~, max_reduction~) -> @ir.Module`.
There are exactly two slots, selected by UInt1; no wider out-of-range slot
value can be represented. Shape/capacity validation retains the execute
generator's checked limits. This API is not a descriptor/device ABI extension.

All existing [stored-result ports](PHASE6_RESULT.md) are retained, adding:

| Ports | Type | Ownership meaning |
| --- | --- | --- |
| `load_a_slot`, `load_b_slot` inputs | UInt1 | Select the physical bank set for that accepted write |
| `command_a_slot`, `command_b_slot` inputs | UInt1 | Source sets latched on command acceptance |
| `command_c_slot` input | UInt1 | Destination latched on command acceptance |
| `completion_c_slot` output | UInt1 | Echo accepted destination, including faulting commands |
| `result_read_slot` input | UInt1 | C set latched on read acceptance |
| `result_response_slot` output | UInt1 | Held response's selected C set |

Each operand set has independent per-lane initialized prefixes. A write is
ready only for a valid lane, an index below capacity and no greater than its
prefix, and an unowned selected source slot. Frontier writes grow that bank's
prefix; existing cells may be overwritten; holes do not accept. Slots never
share initialization validity. A and B selectors are independent, so A0/B1
and A1/B0 are legal source combinations.

Result data uses two distinct synchronous SInt32 SRAMs with fixed physical
stride `row * elaboratedColumns + column`. Each C keeps its own valid active
shape. Reads use one shared pending response channel, with one-edge SRAM
latency and stable data/ID/fault/slot until acknowledgement. Fault priority
is invalid result 2, then full-width active-shape bounds 1, otherwise success 0;
faulting reads return zero without reading SRAM. A pending response blocks all
new reads but only blocks a command targeting that same C.

Execution faults remain dimensions 1, then missing source prefixes 2. A legal
command starts the one shared clear/run/capture sequence. `step_ready` pauses
Run but cannot pause capture. With `T=K+M+N-2`, unstalled terminal publication
is `1+T+M*N` edges after acceptance. Compute counters retain execute meanings;
`capture_cycles` counts the active result writes. No second array/controller
is introduced by adding storage slots.

## Ownership and same-edge rules

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

This older-response rule conservatively blocks same-C admission even for a
malformed command; the API promises no invalid-command bypass. An active C
destination blocks new reads even while its valid bit is zero. A newly
accepted legal command wins a newly offered conflicting read on the same
edge; an independent-C read may transfer alongside that command.
When no response is pending, a fresh read of an independent C may also accept
during active Run or capture. Its synchronous read edge does not stall the
wavefront or destination write. This is distinct from retaining an earlier
read response during compute.

Accepting a legal overwrite invalidates only its destination C. Only the last
successful capture write publishes that slot's valid shape. Other stored
results survive. Result reads must never expose a partially captured matrix.
Joint reset clears validity, reservations, pending responses, and execution;
it does not manufacture successful or aborted completions.

The conservative source lease releases immediately after the final successful
capture/publication edge, not after the host acknowledges completion. Writes
can therefore resume while completion is held. The lease still exists before
that final edge, so that edge does not also admit a conflicting source write.
Rejected commands acquire no source lease and preserve both C slots; an
otherwise legal same-edge source write can still accept, but cannot repair
the pre-edge command prefix check.

## Local verification and remaining gates

The reviewable build sequence is private construction seams with unchanged
legacy canonical goldens, then real two-slot banks and selected computation,
followed by independent ownership/readback integration tests. Public-port tests
exercise:

- two distinct signed matrices produce two persistent, independently checked C slots;
- different-slot operand loads transfer while the first matrix is running;
- conflicting loads/read requests are backpressured without changing active results;
- a held C0 response remains immutable while computation/capture targets C1;
- a fresh C0 read accepts during C1 Run/capture while the corresponding active or capture counter advances on that same edge;
- selectors changed after acceptance cannot redirect work;
- rejected commands preserve previous C, and initialization does not leak across slots;
- same-edge conflict rules, varied Run stalls, and reset during ownership/capture behave as specified.

These checks use real indexed SRAM loads/readback and the independent matrix
oracle, including mixed A/B slots, scalar/rectangular/8x8 signed values,
non-power-of-two capacities, smaller active shapes, failed preflight
preservation, prefix isolation, and reset in Clear/Run/capture/Done or with a
pending response. They do not implement a second hardware model in the host.
Artifact checks additionally require deterministic canonical round trips and
SystemVerilog, separate SRAM sets, and exactly one array's multiply nodes.
All such checks are local construction/simulation evidence; independent RTL,
synthesis, named formal, FPGA, and physical claims retain their later gates.
No new formal/evidence framework is introduced by this storage slice.

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

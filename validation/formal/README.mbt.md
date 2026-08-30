# Formal evidence bundles

The locked formal runner consumes phase-neutral, typed bundles. The Phase 4
FIFO family below retains its original canonical bytes. Phase 5 adds a timed
three-stage synchronizer family through the same regeneration, verification,
collection, and pinned-tool boundary; see
docs/PHASE5_SYNCHRONIZER_FORMAL.md.

The Phase 5 toggle-handshake family uses the same boundary for public-API
scalar and record designs at synchronizer stages two through four. Its atomic
ghost transport, six named assertions, three individual covers, six isolated
negative fixtures, generated completion bounds, and coordinated-reset claim
boundary are specified in `docs/PHASE5_TOGGLE_FORMAL.md`.

The Phase 5 asynchronous-FIFO family binds one public depth-4, 8-bit,
two-pointer-stage design to exact pointer, Gray, pipeline, flag, address,
backpressure, ordering, and bounded-consumption properties. Its fixture matrix
and claim boundary are specified in `docs/PHASE5_ASYNC_FIFO_FORMAL.md`.

## Phase 4 FIFO

This package turns the public `designs/memory.synchronous_fifo_module`
component into four isolated proof targets: the valid FIFO, corrupted response
data, corrupted response-valid protocol, and corrupted occupancy bounds. The
negative targets are separate bundles and therefore cannot weaken or pollute
the valid target.

The harness uses the Yosys global formal clock to drive a deterministic DUT
clock. An initialized saturating cycle counter constrains reset high for exactly
the first DUT edge and low thereafter. Consequently an always-reset trace is
not legal. A ghost two-entry queue independently checks occupancy, flags,
ready/valid behavior, and `ReadOld` FIFO ordering. Cover evidence requires real
traffic: a full FIFO must accept a simultaneous replacement push/pop and later
present a valid response.

Every execution binds these artifacts before SBY starts:

- canonical `design.lcir`;
- emitted DUT and formal harness digests;
- canonical property manifest and stable exported labels;
- bounded, cover, or unbounded task manifest;
- locked job and execution manifests;
- exact Yosys/SBY/Bitwuzla identity and runner policy.

The runner retains status, logs, traces, tool versions, predeclared expected
negative property, output digests, lock/image/config identity, and runner hash.
A bounded pass is only evidence through its finite bound. Only a successful
base plus induction task maps to `Proved`. A reachable base trace maps to a
counterexample; `trace_induct.vcd` maps to an inconclusive induction diagnostic
and retains its digest.

Bounded safety checks all five FIFO properties, including data ordering. The
unbounded task selects the four inductive structural properties: occupancy
bounds, flag/count agreement, ready behavior, and response-valid timing. It
does not claim an unbounded proof of the ghost reference-memory data relation;
that relation remains bounded evidence until a watched-token invariant exists.

The locked solver is two-state. `ADDRESS-KNOWNNESS
two-state-formal-all-binary` records that every formal address bit is binary;
unknown-address/X propagation is outside this proof and remains covered by the
LunaWave/four-state differential validation. Both the source-set and execution
manifest bind this semantic switch.

The global-clock and `multiclock on` setup follows the
[YosysHQ SBY formal extensions](https://yosyshq.readthedocs.io/projects/sby/en/latest/verilog.html#global-clock).
The distinction between a reachable base failure and an induction-only trace
follows the
[YosysHQ SBY FAQ](https://yosyshq.readthedocs.io/projects/ap011/en/latest/faq_sby.html#smtbmc-induction-failures-don-t-start-from-reset).

# LunaWire and LunaWave semantics

This document is normative for the initial stable language subset. Where an
emitter, optimized simulator, or external tool disagrees, this document and
the LunaWave reference conformance tests decide whether LunaChip has a defect.

## Elaboration versus hardware execution

A LunaWire design is built by executing a MoonBit elaboration program.
Elaboration may use normal MoonBit functions, loops, data structures, and
conditionals to choose hardware structure. It terminates by producing a finite
design graph.

Elaboration values are not hardware values. Host `if condition` selects which
graph is constructed; `mux(condition_signal, a, b)` constructs logic evaluated
during hardware execution. APIs must use distinct types so a host `Bool` cannot
silently stand in for a one-bit hardware value.

Elaboration is deterministic when supplied the same declared inputs. Time,
randomness, environment, filesystem ordering, process IDs, and hash iteration
must not affect semantic IDs or serialization. Tools may record such data only
in an evidence envelope excluded from the design digest.

## Values

### Width

A digital ground value has a statically resolved positive width. Width zero,
negative width, overflow while calculating a width, and unresolved width are
errors. Initial implementation limits may reject otherwise meaningful large
widths with a typed resource-limit diagnostic.

### Signedness

`Bits(w)` is uninterpreted bits, `UInt(w)` is unsigned, and `SInt(w)` is two's
complement signed. Signedness affects comparisons, extension, right shift, and
arithmetic interpretation. Reinterpretation between equal-width types is
explicit and preserves bits.

There is no implicit extension, truncation, or signedness conversion.
Operations require exact operand types except where their documented result
rule explicitly differs. Users invoke explicit zero extension, sign extension,
truncation, slice, or reinterpretation.

### Known and unknown bits

The semantic value is `(bits, known_mask)` at fixed width. A known-mask bit of
one means the corresponding value bit is known; zero means `X`. Value bits in
unknown positions are canonicalized to zero and have no observable meaning.

The stable subset has no internal high-impedance `Z`. Bidirectional physical IO
is represented by explicit input, output, and output-enable signals at the
boundary. A two-state fast mode is permitted only when its run manifest states
the assumption and the tested design cannot observe unknown-state behavior.

## Combinational operations

Combinational nodes are pure functions of operands. They have no hidden state
and exactly one definition. Signals that require connection are valid only
after exactly one driver is established; multiple drivers and undriven required
outputs are errors.

Arithmetic uses fixed-width modular bit results unless the operation explicitly
returns a wider result. The initial rules are:

- bitwise operations return the operand width;
- add and subtract require equal type and width and return that width;
- multiply has separate explicit low-width and full-width forms;
- equality returns one-bit `Bits` and compares all semantic bits;
- ordered comparison requires matching numeric types;
- shifts retain input width; shift amount is unsigned;
- overshift returns zero for logical shifts and sign fill for arithmetic right
  shift;
- slice bounds are elaboration-time constants and must be in range;
- concatenation orders the first operand as the most-significant segment;
- multiplex branches must have identical types.

Unknown propagation is conservative. An operation returns a known output bit
only when that bit is determined for every assignment of its unknown inputs.
Implementations may use more precise algebraic rules but must never mark an
indeterminate bit known. A mux with unknown select may retain any output bit
that is equal and known in both branches.

Division, modulo, dynamic part select, and variable rotation are excluded from
the first stable subset unless their exact zero/unknown behavior is added here.

## Connections and guarded assignment

Connections are structural, not ordered procedural assignments. The design
must resolve to one expression per driven sink.

Guarded assignment constructs an explicit priority or non-priority mux tree as
declared by the API. There is no implicit “last connect wins.” Incomplete
combinational assignment is rejected rather than inferring a latch. Latches may
be added later as an explicit state primitive with separate semantics.

## Combinational cycles

The canonical combinational dependency graph must be acyclic. Any strongly
connected component containing an operation dependency is rejected with a
cycle path and source spans. Registers, explicit memory latency, and supported
foreign sequential primitives break dependency paths. LunaWave does not use
iteration limits to guess the meaning of an illegal cycle.

## Clocks and resets

A clock domain defines a clock signal and active edge. Each register or
synchronous memory port names exactly one domain and carries its own explicit
optional reset and enable controls. There is no default or ambient
clock/reset. Keeping reset on the state element permits two registers in one
clock domain to have different reset values or no reset at all.

Initial stable execution supports rising edges. Falling edges are representable
only after reference tests define coincident-edge ordering. Clock values are
not ordinary data operands except through explicit clock-control primitives.
Generated or gated clocks are rejected initially.

The initial stable synchronous reset is active-high, sampled on the active
edge, and has priority over enable and next state. Any future polarity choice
must be represented explicitly. Asynchronous reset changes state when its active level is
observed, independently of a clock edge; its event ordering must be implemented
before asynchronous resets become stable. Reset values must exactly match the
state type.

Unreset state begins unknown. A simulator option that forces a value is an
explicit test assumption and cannot change the design artifact.

## Registers and edge commit

A register exposes its old committed value throughout pre-edge evaluation. On
an active edge, LunaWave computes its candidate update from that old global
state. All registers in the event commit simultaneously; no register observes
another register's new value during the same edge.

Priority is:

1. active reset value;
2. enabled next-state value;
3. retained old value.

After commit, combinational outputs settle before post-edge observations.

## Memories

A memory has explicit element type, positive depth, port definitions, and
behavioral policies. Each port declares domain, read/write role, latency,
enable behavior, and mask granularity.

Initial stable memories are synchronous-read with one-cycle latency and
synchronous writes. Out-of-range access is a simulation fault and property
failure; emitted hardware also receives an explicit bounds policy. Disabled
reads hold their registered output unless the port declares another supported
behavior.

Same-address read/write and multi-write behavior must be one of:

- `ReadOld`;
- `ReadNew` when target capability supports it;
- `NoChange`;
- `Undefined`, which produces unknown data in LunaWave;
- `Reject`, which makes the construction invalid.

Two writes to the same address on one edge are rejected unless the memory
declares a deterministic port priority. Backend capability validation fails if
a requested semantic policy cannot be preserved on the selected target.

## Hierarchy

Modules are immutable definitions and instances are named references to those
definitions. A module cannot instantiate itself directly or transitively.
Instance connections obey port direction and exact type. A canonical path is a
sequence of stable instance names ending in a port, signal, register, memory,
or property name.

Names are debug identity, not semantic connectivity. Renaming changes source
maps and serialized human identity but not operation behavior. Automatic names
derive from deterministic source/order information, never pointer identities.

## Ready/valid protocol

`ReadyValid[T]` is an interface convention, not magical simulator behavior. A
transfer occurs on an active edge exactly when both `ready` and `valid` are
known one. While `valid` is one and no transfer occurs, the producer must keep
payload stable. A consumer may change `ready` independently unless a stricter
interface contract is declared.

Protocol checkers are generated properties. Unknown `ready` or `valid` does
not count as a transfer and may trigger an initialization/property diagnostic
under strict checking.

## Time and event ordering

Simulated time is an unsigned integer number of design ticks. Event ordering at
one timestamp is deterministic:

1. externally scheduled input/reset changes;
2. combinational settlement;
3. clock-edge sampling ordered by stable domain ID when multiple edges coincide;
4. simultaneous state commit for all edges in that timestamp;
5. combinational settlement;
6. property observation and trace commit.

Cross-clock interactions at coincident edges observe pre-commit state. This is
a digital simulation convention, not metastability modeling. Any functional
CDC requires an explicit synchronizer, handshake, or asynchronous FIFO
primitive and associated properties.

## Properties

Properties are `Assert`, `Assume`, and `Cover` with an explicit observation
domain and optional disable condition. LunaWave treats a known-false assertion
as a failure. An unknown assertion result is a failure in strict mode and a
separately reported inconclusive result only in an explicitly selected
exploratory mode.

Assumptions constrain formal environments. In ordinary simulation, a violated
assumption reports an invalid test stimulus rather than proving the design
incorrect. Cover records reachability and never makes a passing proof claim.

Formal reports name each property, tool, engine, mode, depth or induction
method, target artifact digest, and result. A bounded pass is never described
as an unbounded proof.

## Trace and replay

Traces observe committed semantic values at defined event boundaries. VCD is an
export format; the native trace schema also records unknown masks, canonical
paths, source-map IDs, domains, and artifact digest.

A replay bundle contains canonical IR digest, simulator version, semantic
options, deterministic stimulus, stop condition, selected taps, and expected
result digest. It excludes undeclared host state. Failures should be reducible
to such a bundle.

## Foreign and black-box modules

Foreign modules are excluded from initial stable simulation. When introduced,
each must declare port types, clock/reset behavior, combinational paths,
latencies, statefulness, simulation model, synthesis representation, and digest.
An absent simulation model is a hard error for LunaWave, not a zero-valued
stub. A black box cannot bypass driver, cycle, or domain validation.

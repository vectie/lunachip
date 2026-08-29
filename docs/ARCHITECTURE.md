# LunaChip architecture

## Architectural shape

```text
MoonBit generator
      |
      v
LunaWire elaboration graph
      |
      v
validation -> canonical Core RTL IR -> deterministic serialization
                         |        |             |
                         |        |             +-> formal export
                         |        +-> SystemVerilog -> Verilator/Yosys/EDA
                         +-> Simulation IR -> LunaWave reference engine
                                            -> compiled engine (later)
```

The canonical Core RTL IR is the semantic center. LunaWire is one producer and
LunaWave is one consumer. Neither simulator implementation details nor
SystemVerilog syntax define the language.

## Package boundaries

The intended MoonBit package layout is:

```text
wire/                 public construction API and its public types
ir/                   public stable canonical IR types
ir/codec/             deterministic versioned serialization
passes/               validation and canonical lowering
semantics/             value and operation reference semantics
wave/                 public simulator, stimulus, result, and trace API
wave/reference/       interpreter/reference scheduler
wave/compiled/        optional accelerated backend
emit/sv/              SystemVerilog backend
emit/circt/           optional CIRCT interchange backend
formal/               property export and proof manifests
device/               public device ABI and capability types
designs/flux_tile/    reference accelerator
cmd/lunawire/         elaboration/inspection CLI
cmd/lunawave/         simulation/replay CLI
cmd/lunachip/         phase-gate and evidence CLI
internal/*            source maps, graph algorithms, codecs, helpers
```

Public concrete types live in their owning public package. `internal/*` must
not own concrete types that users are expected to construct, match, or call
methods on. Files are cohesive; MoonBit files do not create namespaces.

Allowed dependency direction:

```text
wire --------> ir <-------- wave
                ^            |
passes ---------|            +--> semantics
emit/* ---------|            |
formal ---------|            +--> trace
designs --------> wire
device (independent schema package)
cmd/* ---------> public packages
```

Forbidden dependencies include `ir -> wire`, `ir -> wave`, `passes -> emit`,
and any LunaFlux/LunaNexa import.

## LunaWire elaboration

LunaWire is an embedded MoonBit library. The host program executes once during
elaboration and calls builders that create hardware nodes. Generator loops and
conditionals are host behavior; resulting hardware is static.

The elaborator owns:

- unique design, module, value, instance, memory, domain, and property IDs;
- hierarchical lexical naming and stable source spans;
- construction-time type and direction checks;
- immutable module finalization;
- deterministic traversal independent of hash-map order;
- lowering aggregate `Bundle`/`Vec` interfaces to canonical ground values;
- recording parameter values as metadata, not runtime hardware state.

Builders use explicit `finish` operations that return validated immutable
values or checked diagnostics. A finalized module cannot be mutated. References
from another design, module, or expired builder scope are rejected.

## Canonical IR

### Design and hierarchy

`Design` records schema version, top module, modules, stable metadata, and
capability requirements. Modules contain ordered ports, domains, values,
instances, memories, properties, and source locations.

Module definitions remain hierarchical in Core RTL IR. Instance paths are
explicit. Backends may flatten into a derived Simulation or Netlist IR, but
flattening never mutates the canonical artifact.

### Types and operations

Core ground types are `Bits(width)`, `UInt(width)`, `SInt(width)`, `Clock`, and
`Reset`. Aggregates are elaboration/API conveniences that lower to ground
ports and values while retaining debug metadata.

Combinational operations are SSA-like: each result has exactly one defining
operation and references immutable operands. Operations include literals,
bitwise logic, comparisons, arithmetic, shifts, slices, concatenation,
extension, explicit truncation, multiplexing, and explicit reinterpretation.

Sequential nodes make clock, edge, reset mode, reset polarity, reset value,
enable, and next-state expression explicit. Memory nodes make dimensions,
ports, latency, enable behavior, byte/element masks, and same-address collision
policy explicit.

### Canonicalization

Canonicalization must not change behavior. It:

- resolves all widths and aggregate layouts;
- assigns stable IDs using deterministic design order;
- normalizes literals and commutative operands under documented rules;
- removes unreachable elaboration metadata while retaining source maps;
- sorts semantically unordered metadata by stable key;
- rejects unresolved capabilities or unknown semantic operations.

The serialized digest covers the semantic payload and declared schema, not
timestamps, absolute workspace paths, or tool-host details.

## Validation passes

The minimum ordered pipeline is:

1. schema and reference integrity;
2. name and hierarchy validation;
3. width and signedness resolution;
4. direction and driver analysis;
5. combinational dependency construction and cycle detection;
6. clock/reset domain validation;
7. memory port and collision-policy validation;
8. property type/domain validation;
9. target capability validation;
10. deterministic canonicalization and digest.

Diagnostics carry a stable code, severity, primary source span, related spans,
semantic path, and suggested correction. User errors are checked diagnostics;
internal invariant failures are product defects and must include replay data.

## LunaWave reference engine

LunaWave consumes validated canonical IR lowered to Simulation IR:

- hierarchy is flattened into stable signal and state slots;
- combinational dependencies are topologically scheduled;
- registers and memories occupy explicit state regions;
- clock edges and external input changes are deterministic events;
- trace taps map state slots back to canonical paths and source spans.

For a simple synchronous step, the engine:

1. applies input events at the current timestamp;
2. settles combinational logic to the scheduled fixed point (acyclic initially);
3. evaluates pre-edge properties;
4. computes all active-edge register and memory updates from old state;
5. commits updates simultaneously;
6. settles resulting combinational logic;
7. evaluates post-edge properties and records changed trace values;
8. advances to the next deterministic event.

Simulated time is integer ticks with a design timebase. Wall-clock tasks,
threads, and MoonBit async timing never define hardware ordering.

### State and performance model

The reference engine favors clarity:

- packed value bits plus packed known masks;
- contiguous state slots;
- immutable compiled schedule;
- reusable scratch buffers;
- no allocation in the steady-state cycle loop after model preparation;
- trace recording only for selected taps and only on changes.

The later compiled engine must implement the same conformance suite. It may
flatten more aggressively and compile transfer functions natively or through
CIRCT Arc/LLVM, whose documented purpose is fast simulation of flattened state
transfer functions. It is an optimization, never a second semantics.

## Standard-tool boundaries

### SystemVerilog

The SystemVerilog backend emits a deliberately conservative synthesizable
subset with stable names, explicit sizes, explicit casts, explicit sequential
blocks, and source-map comments. LunaChip does not parse arbitrary
SystemVerilog. Generated RTL is an interoperability artifact and independent
oracle input.

### CIRCT

CIRCT `hw`, `comb`, and `seq` interchange is optional. LunaChip retains its own
canonical IR so a CIRCT version or dialect change cannot redefine LunaWire.
The backend is conformance-tested like SystemVerilog.

### Formal and synthesis

Properties lower to supported SystemVerilog/Yosys formal constructs plus a
machine-readable proof manifest. Yosys and SymbiYosys are external pinned
tools. Their result is evidence about the emitted artifact, not execution
inside LunaWave.

## FluxTile-0 architecture

FluxTile-0 is host attached rather than a CPU extension:

```text
command ring -> descriptor frontend -> dependency scoreboard
                                      |       |       |
                                     load   execute  store
                                      |       |       |
host memory <-> DMA <-> banked scratchpad <-> systolic array
                                      |             |
                                      +-> accumulator SRAM
```

Initial parameters are an 8×8 array, signed INT8 operands, INT32 accumulators,
explicitly managed banked scratchpad, bounded descriptors, and a simple memory
request/response port. Load, execute, and store are decoupled so memory and
compute can overlap when dependencies permit.

The first command set is `LoadTile`, `MatMul`, `StoreTile`, and `Fence`.
`Vector` is added only after the matrix path is stable. Descriptors carry
version, opcode, flags, bounded addresses, dimensions, strides, dependency
tokens, and completion identity. Invalid or unsupported commands complete with
a typed fault; they never execute partially without a specified fault rule.

The first correctness oracle is a simple MoonBit matrix model. Performance
counters report cycles, active-array cycles, stall categories, bytes moved,
commands completed, and faults. Counter semantics are part of the device ABI.

## Deployment and security considerations

Generator input is executable MoonBit code and is trusted build input, not an
untrusted runtime payload. Serialized IR and stimuli are still validated before
use. File paths, foreign-module references, and emitted names cannot escape the
design workspace. Resource limits bound widths, nodes, hierarchy depth,
simulation ticks, queued events, trace volume, and memory allocation.

External tools run through pinned, isolated toolchain environments with
explicit input/output directories. Their logs and versions enter evidence
manifests; their exit status alone is insufficient evidence.


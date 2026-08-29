# Research and design basis

This is a design study, not a claim that LunaChip already implements or matches
the referenced systems. Sources are linked to official project documentation
or primary project repositories.

## Hardware construction languages

### Chisel

[Chisel](https://www.chisel-lang.org/docs.html) demonstrates the central model:
an embedded host-language program constructs a hardware graph. That validates
using MoonBit itself for LunaWire elaboration instead of first building a new
parser and language server. Chisel also demonstrates the value of retaining
high-level type/debug information through lowering; its documented debug
intrinsics carry aggregate and source concepts toward CIRCT.

LunaChip adopts:

- executable parameterized generators;
- hardware values distinct from host-language values;
- staged elaboration into explicit IR;
- standard RTL as an output boundary.

LunaChip deliberately avoids:

- inheriting Scala/JVM as a runtime/toolchain requirement;
- ambiguous connection precedence;
- making FIRRTL or a changing external compiler dialect its sole semantic
  source of truth;
- reproducing the complete feature and compatibility surface on day one.

### Amaranth

[Amaranth's simulator documentation](https://amaranth-lang.org/docs/amaranth/v0.5.0/simulator.html)
shows an approachable construction language can ship an integrated simulator,
testbench model, clocks, and VCD tracing. Its installation documentation also
shows how an HDL can use Yosys and FPGA-family tools rather than owning
synthesis and place-and-route.

LunaChip adopts the integrated construction/simulation experience and explicit
testbench stimulation. It differs by using MoonBit, defining a canonical
versioned IR, and specifying known-mask and event-order semantics before adding
broad IO or platform support.

## Hardware compiler infrastructure

### CIRCT

[CIRCT's dialect catalog](https://circt.llvm.org/docs/Dialects/) includes
hardware, combinational, sequential, SystemVerilog, verification, and
simulation-oriented IRs. This supports a multi-level lowering architecture.

[The Arc dialect](https://circt.llvm.org/docs/Dialects/Arc/) represents state
transfer functions, flattens hierarchy, schedules combinational work, and can
compile through LLVM for simulation. It is a useful future compiled LunaWave
backend and a source of architectural lessons.

LunaChip nevertheless keeps its canonical IR independent because:

- LunaWire semantics need a small stable contract;
- external dialect versions may evolve independently;
- a MoonBit reference implementation is needed to adjudicate backend bugs;
- users should be able to inspect and replay designs without an LLVM/C++ stack.

## Simulation

[Verilator](https://verilator.org/guide/latest/overview.html) compiles Verilog or
SystemVerilog into C++ or SystemC models and supports lint, coverage, and trace
generation. LunaChip uses pinned Verilator as an independent differential
oracle and speed baseline for emitted SystemVerilog.

LunaWave's initial target is not “faster than Verilator.” Its value is:

- exact LunaWire semantics without a text-RTL translation step;
- deterministic startup, snapshots, and replay;
- source-level paths and diagnostics;
- known-mask visibility;
- tight MoonBit unit and property testing.

Once correctness stabilizes, a compiled Simulation IR may narrow the speed gap.
The reference interpreter remains authoritative.

## Synthesis and formal verification

[Yosys](https://yosyshq.readthedocs.io/projects/yosys/en/v0.50/introduction.html)
is an open RTL-synthesis framework supporting the synthesizable Verilog-2005
subset and multiple research/FPGA/ASIC flows. LunaChip emits conservative RTL
and treats successful Yosys mapping as independent synthesis evidence.

[SymbiYosys](https://yosyshq.readthedocs.io/projects/sby/en/stable/) drives
Yosys-based bounded safety, unbounded safety, cover, and liveness flows. That
supports LunaChip's explicit `Assert`, `Assume`, and `Cover` model. Reports must
retain the distinction among bounded checks, induction/unbounded results,
reachability, assumptions, and actual test stimuli.

LunaChip does not implement its own synthesizer or SMT solver. Rebuilding those
would delay semantic validation and produce less independent evidence.

## Accelerator precedents

### Gemmini

[Gemmini](https://github.com/ucb-bar/gemmini) combines a systolic matrix array,
explicitly managed banked scratchpad, accumulator SRAM, DMA, and decoupled load,
execute, and store controllers. It also demonstrates elaboration-time
parameters and the importance of overlapping memory access with execution.

FluxTile-0 adopts those broad architectural lessons but starts smaller:

- host command ring instead of a RISC-V RoCC/custom-instruction dependency;
- fixed 8×8 INT8/INT32 first configuration;
- simple abstract memory port before AXI;
- matrix multiplication rather than a full DNN operator stack;
- explicit device ABI intended for an external LunaFlux adapter.

This reduces SoC integration and software-toolchain scope while still testing
the language, simulator, memories, flow control, and compute datapath.

### NVDLA

[NVDLA's hardware architecture](https://nvdla.org/hw/v1/hwarch.html) uses
independently configurable blocks, host configuration, DMA, interrupts,
pipelining, and double-buffered configuration groups. The lessons for LunaChip
are clear block contracts, configuration overlap, completion/fault reporting,
and parameterized resource sizing.

FluxTile-0 does not copy NVDLA's CNN-focused fixed-function breadth. Transformer
workloads and the project-validation goal favor a smaller command-driven tensor
tile.

## Physical-design research path

[OpenROAD Flow](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/blob/master/docs/user/UserGuide.md)
integrates Yosys for synthesis, OpenROAD for floorplanning through routing, and
KLayout for GDS merge and public-PDK DRC/LVS. It provides a credible research
path from emitted RTL to GDS without LunaChip owning physical-design software.

[The SKY130 open PDK repository](https://github.com/google/skywater-pdk) provides
design rules, tool support files, device models, and standard-cell resources,
while its documentation warns that documentation is a work in progress and
describes support limitations. Therefore a completed open flow is useful
research evidence, not automatically production signoff or fabrication.

Any future target must be selected based on current PDK/tool availability,
licenses, shuttle rules, memory and IO macro availability, and foundry
acceptance at that time. LunaChip's stable contract does not promise a specific
foundry.

## Alternatives considered

### Build a standalone HDL parser first

Rejected for the first release. It duplicates parsing, type checking, package
management, editor tooling, and metaprogramming already available in MoonBit.
A text syntax may be added later as a front end to the same canonical IR if a
real interoperability need appears.

### Use SystemVerilog as canonical IR

Rejected. Standard RTL is essential for interoperability but contains a much
larger and sometimes tool-dependent semantic space. Making it canonical would
force LunaWave either to implement broad SystemVerilog or defer semantics to
external tools.

### Depend entirely on CIRCT

Rejected as the initial architecture. CIRCT is strategically valuable but
LunaChip needs a small stable MoonBit-owned semantic core, fast reference
testing, and independent backends.

### Build synthesis, place-and-route, or a CPU

Rejected. These are mature disciplines and tools, and none is required to
prove a construction language, simulator, or tensor tile. A host-attached
device with a command queue gives a portable software boundary sooner.

### Begin with BF16 attention hardware

Rejected. BF16 arithmetic, reductions, approximation, memory bandwidth, and
attention control multiply verification scope. INT8 matrix multiplication with
INT32 accumulation is a better first synthesized datapath. BF16 begins as a
functional model and becomes a hardware claim only after numerical and RTL
evidence passes.

## Feasibility conclusion

The research supports four progressively harder but distinct outcomes:

1. MoonBit hardware construction language: feasible with a small team.
2. Deterministic reference simulator and RTL emitter: feasible, with independent
   differential validation essential.
3. Useful FPGA tensor accelerator: feasible after substantial memory, timing,
   verification, and driver work.
4. Small physical research test chip: possible with external EDA/PDK/shuttle
   infrastructure; not equivalent to a competitive inference ASIC.

A competitive LLM ASIC additionally requires modern memory interfaces,
advanced process access, licensed hard IP, physical design, design-for-test,
verification at much larger scale, packaging, boards, firmware, and production
operations. LunaChip should earn each evidence level rather than treating that
destination as an initial product promise.


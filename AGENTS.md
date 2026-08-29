# LunaChip implementation guide

LunaChip is a documentation-first MoonBit-native hardware construction and
simulation product. Read README.mbt.md, docs/PRODUCT_CONTRACT.md,
docs/ARCHITECTURE.md, docs/PLAN.md, and docs/SEMANTICS.md before implementation.

## Product boundary

LunaChip contains two version-locked components:

- LunaWire elaborates MoonBit hardware generators into canonical RTL IR.
- LunaWave simulates that IR deterministically and emits debug evidence.

LunaChip owns hardware construction, RTL semantics, simulation, standard RTL
emission, formal-property export, and reference accelerator designs. It does
not own model serving, fleet management, synthesis, place-and-route, PDKs, or
foundry services.

LunaFlux may consume a published LunaChip device contract through a LunaFlux
adapter. LunaChip must not import LunaFlux, LunaNexa, MoonGate, or another
MoonSuite product.

## Language and structure

- Write first-party elaboration, IR, simulation, diagnostics, and CLI code in
  MoonBit.
- Use moon.mod and focused packages with their own moon.pkg.
- Public concrete types belong to the public package that owns them.
- Keep the canonical IR independent of the construction API and simulator.
- Hardware time is deterministic simulation state, never wall-clock async time.
- Use checked errors for invalid widths, drivers, cycles, clocks, and states.
- Prefer files below 500 lines; files above 800 lines require an ADR.

## Semantic rules

- Exactly one driver per signal.
- No implicit width truncation, sign conversion, clock, or reset.
- Reject combinational cycles before simulation or emission.
- Register updates commit simultaneously on a clock edge.
- Memory read latency and collision policy are explicit.
- Every elaborated design and serialized IR is deterministic.
- SystemVerilog and CIRCT are backends, not the source of truth.

## Validation

Use targeted checks while working. At a completed phase boundary run:

~~~sh
moon info
moon fmt
moon check --target native --deny-warn
moon test --target native --deny-warn
~~~

Emission and simulator phases additionally require differential tests against
pinned Verilator, synthesis through pinned Yosys, and formal gates defined in
docs/PLAN.md.


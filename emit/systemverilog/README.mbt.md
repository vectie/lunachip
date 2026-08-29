# SystemVerilog emitter

This package turns a validated `vectie/lunachip/ir.Design` into deterministic
SystemVerilog-2017 and a canonical emitted-name manifest.

Use `emit_design`. Write each item in `EmittedDesign.modules()` to its exact
`filename()` for strict lint and independent simulation. The concatenated
`source()` is useful for review and golden tests but deliberately is not the
lint file boundary.

The backend fails closed when canonical input cannot satisfy its portable
synthesis and strict-lint contract. In backend version 1 that includes explicit
register initial values and nonempty modules containing nodes outside the
backward semantic closure of their outputs. Uninitialized registers have no
declaration initializer and retain normal four-state X behavior until the
design resets or updates them.

See [FORMAT.md](FORMAT.md) for the supported lowering, identifier grammar, and
manifest format.

# Formal SystemVerilog integration

This adapter closes the identity gap between canonical LunaChip properties and
the conservative SystemVerilog backend. It does not reconstruct, sanitize, or
predict an emitted name.

`TopModulePath::checked` accepts only the canonical design top name. Then
`derive_bindings` resolves:

- `PropertySignal::Node` through the exact `(top module ordinal, NodeId, Node)`
  entry in the emitted `NameManifest`;
- `PropertySignal::Named` through exactly one declared top-module input or
  output mapping with matching canonical IR identity.

An absent mapping fails. An input and output with the same source name are
ambiguous and fail. A signal carrying another module path fails. Clock,
predicate, and disable roles are checked against canonical IR types before any
SVA is produced.

`integrate` inserts `FormalExport::source` immediately before the one exact
`endmodule` line of the emitted top-module file. Missing or multiple markers
fail closed. Other module files retain their exact bytes.

The result exposes two content identities:

- `top_artifact` is the logical top `.sv` filename and SHA-256 of its exact
  post-insertion bytes;
- `source_set_identity` binds the top path, property-manifest digest,
  emitted-name-manifest digest, and every module filename/identifier/source
  digest. `source_set_sha256` addresses those bytes, and
  `source_set_artifact` makes that identity usable by a proof-task manifest.

This package prepares deterministic artifacts only. It does not invoke Yosys,
SymbiYosys, or a solver.

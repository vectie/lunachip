# External-tool lock manifest format

LunaChip records independent EDA inputs in
`lunachip.external-tools/v1` JSON documents. A lock manifest identifies exact
download artifacts and executable payloads; it is not evidence that any tool
was installed, executed, or passed a gate.

## Document roles

- `manifest_kind: "lock"` is a reproducibility input for a named host profile.
- `manifest_kind: "format-fixture"` exists only to test parsers and the schema.
  It must use fictional `.invalid` locations and must never be accepted as an
  installed-tool or validation record.
- Execution evidence is a separate future artifact. It must record the lock
  digest, observed executable digest, command, exit status, and output artifact
  digests. This format deliberately contains none of those claims.

The authoritative structural definition is
[`external-tools.schema.json`](external-tools.schema.json). The
[`example.external-tools.json`](fixtures/example.external-tools.json) document
is machine-readable test data, not a starter lockfile to rename.

## Pinning rules

Every tool entry has:

- a stable lowercase `id` used by LunaChip gates;
- the vendor's exact `version` string, without `latest` or version ranges;
- an exact `platform` profile;
- an immutable artifact URL and lowercase SHA-256 digest;
- at least one relative executable path and its lowercase SHA-256 digest;
- the capabilities for which the executable may be invoked.

An implementation must reject duplicate tool IDs, path traversal, unknown
schema versions, malformed digests, and a lock whose downloaded bytes do not
match the declared hashes. It must not search `PATH` as a substitute for a
missing locked executable.

## Determinism and compatibility

Manifests are UTF-8 JSON. Producers should emit two-space indentation, a final
newline, and tools sorted by `id`; consumers must not depend on object-member
order. A content digest covers the exact manifest bytes. Schema changes use a
new `schema_version`; unknown versions fail closed.

The manifest intentionally does not pin the MoonBit compiler used to build
LunaChip. Repository CI pins that bootstrap toolchain independently because it
is required before a MoonBit manifest reader can run.

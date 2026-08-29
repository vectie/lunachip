# LunaWave trace schema 1

The native trace is canonical UTF-8 text ending in one newline. Its signal
table is ordered by the UTF-8 bytes of `(path, name)`. A frame preserves the
simulation cycle, an event-boundary ordinal, and the event kind even when no
value changes. The first frame initializes every declared signal. Later frames
contain only changed signals in signal-table order.

Each `CHANGE` stores the signal index, canonical value bits, and known mask.
Widths live in the signal table and are restricted to the native LunaWave
logic-value range of 1 through 64 bits. Parsing rejects reordered tables,
duplicate or redundant changes, non-monotonic boundaries, noncanonical logic
masks, malformed UTF-8 hex, unsupported versions, extra lines, and missing
terminal newlines.

The VCD exporter assigns stable identifiers `s0`, `s1`, and so on. Reference
names contain only ASCII letters, digits, and underscores with path and signal
text represented as UTF-8 hex. VCD timestamp `n` means preserved trace frame
`n`; a deterministic comment retains the exact LunaChip cycle, boundary, and
event. Unknown bits are written as `x`.

## Trace source map schema 1

Source metadata is a separate canonical UTF-8 artifact headed by
`LUNACHIP-TRACE-SOURCE-MAP 1`. Keeping it separate preserves the native trace,
replay, and VCD byte formats. Every trace signal-table index occurs exactly
once and retains the full signal identity, a validated diagnostics
`SemanticPath`, and an optional half-open diagnostics `SourceSpan`. Positions
preserve one-based line and column values plus the exact zero-based byte
offset; the source ID and semantic strings are encoded as UTF-8 hex.

Each entry contains a `VCD sN` manifest line. The parser verifies that `sN`
matches the entry's canonical signal index, so tooling can join a VCD signal
identifier back to its trace identity and source metadata without heuristics.
Parsing rejects unknown, duplicate, or missing construction bindings;
noncontiguous or reordered indices; reordered signal identities; malformed
segments, spans, UTF-8, or VCD identifiers; unsupported versions; extra lines;
and noncanonical encodings.

`fixtures/golden.vcd` is the byte-for-byte artifact used for external viewer
compatibility checks.

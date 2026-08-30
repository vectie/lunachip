# LunaWave trace schemas

## Native trace schema 1

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

## Native trace schema 2

Schema 2 retains the canonical signal-table identities and changed-only value
encoding while binding the trace to a semantic version, canonical-IR digest,
normalized timebase, and explicit domain table:

```text
LUNACHIP-TRACE 2
SEMANTICS <utf8-hex>
IR <algorithm> <digest>
TIMEBASE <ticks-per-source-unit>
DOMAINS <count>
DOMAIN <id> <clock-name-hex>
SIGNALS <count>
SIGNAL <index> <width> <path-hex> <name-hex>
FRAMES <count>
TOTALS <drive-members> <domain-members> <changes>
FRAME <time> <boundary> <event> <argument> <drives> <domains> <changes>
DRIVE <input-name-hex>
ACTIVE <domain-id>
CHANGE <signal-index> <value-bits> <known-mask>
END
```

`TIMEBASE` is the positive integer scale of the already-normalized exact
rational schedule: the scheduler has computed a common denominator and every
frame time is therefore an integral normalized tick. No numerator or floating
point value remains to store in the trace. A timebase of `6`, for example,
means six normalized ticks per source time unit; it does not multiply frame
timestamps during replay or VCD export.

State-changing event and marker boundaries are strictly increasing. The
synthetic initial snapshot has canonical boundary zero and may share it only
with the first stored event when that event's actual replay boundary is zero.
Frame times are nondecreasing so an initial frame or trace-only marker may share an event time, but only one
state-changing atomic batch may occur at a timestamp. Same-time frames use the
canonical order initial, batch, retained legacy event, then marker. Batch drive
names are unique and sorted by UTF-8 bytes. Active domain IDs are unique,
increasing, and present in the domain table. The first frame is an initial
frame containing every signal; later empty-change event frames are retained.

Signal tables passed to schema-2 construction must already be canonical.
They are rejected rather than sorted because `TraceChange` indices already
refer to table positions and sorting could silently rebind values. Domain,
drive, active-domain, and change lists are canonicalized where their identity
is independent of positional signal indexing.

The parser applies per-table, per-frame, and aggregate `TOTALS` resource limits
before consuming declared payloads, then checks the declared totals against
the actual frames. Exact reserialization rejects reordered members,
noncanonical integers, redundant changes, unknown domains, extra fields, and
missing newlines.

`migrate_schema1` is pure and assigns each old frame its own time and boundary
on timebase 1. It retains the exact legacy event in a tagged schema-2 frame and
does not infer a domain, merge frames, or treat a legacy cycle counter as
physical time.

## Schema-2 VCD conversion

Schema-2 VCD timestamps are the frame's normalized `time` verbatim—not its
frame index, boundary, timebase, or a legacy cycle. Repeated-time marker frames
share the preceding VCD timestamp and remain deterministically ordered by
boundary. VCD syntax requires a timescale, so the exporter uses `1ps` solely as
a conventional viewer display unit and emits a header comment stating that
one VCD unit equals one normalized design tick and is not a physical
picosecond claim.

Every frame comment records actual time, boundary, event kind and argument,
sorted drive names, sorted active domains, and cumulative per-domain edge
counts. The header records the normalized timebase and canonical domain-clock
mapping. Signal identifiers remain `s0`, `s1`, and so on, preserving source-map
linkage.

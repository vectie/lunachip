# LunaWave replay schemas

A replay bundle carries the exact canonical IR text and its declared
`fnv1a-64` digest, the semantic contract version, canonical named options,
ordered named-input drive and rising-edge stimuli, one stop condition,
canonical selected taps, and the expected canonical-trace result digest.
Arbitrary text is encoded as lowercase UTF-8 hex, avoiding locale and escaping
ambiguities.

Drive records represent simultaneous input updates and sort their inputs by
UTF-8 name bytes. Stimulus boundaries must be strictly monotonic by
`(cycle, boundary)`. Options and taps are sorted and unique. Parsing checks the
embedded canonical IR with `ir/codec`, recomputes its digest, validates every
logic value, rebuilds the checked bundle, and finally requires byte-for-byte
canonical reserialization.

The executor resolves each tap against the canonical top module. `path` is the
top module name and `name` is either a public input or output name; ambiguous,
unknown, and width-mismatched taps are rejected. It records a complete initial
frame, applies each multi-input drive simultaneously, checks the declared
pre-action cycle, performs rising edges through LunaWave, and records one
changed-only frame per action. The result reports whether the stop condition
was reached and whether the resulting canonical trace digest matches the
bundle. A mismatch retains the trace and actual digest so the same failure can
be replayed and compared without losing evidence.

## Schema 2 atomic events

Schema 2 retains the schema-1 semantic version, canonical options, embedded
canonical IR plus digest, taps, stop condition, and expected-result digest.
It replaces `STIMULI`, `DRIVE`, and `EDGE` with an exact normalized timebase
and atomic timestamp events:

```text
LUNACHIP-REPLAY 2
SEMANTICS <utf8-hex>
OPTIONS <count>
OPTION <key-hex> <value-hex>
IR <algorithm> <digest> <canonical-ir-hex>
TIMEBASE <ticks-per-source-unit>
EVENTS <count>
EVENT <time> <boundary> <drive-count> <domain-count>
INPUT <name-hex> <width> <value-bits> <known-mask>
DOMAIN <domain-id>
STOP <condition>
TAPS <count>
TAP <width> <path-hex> <name-hex>
EXPECTED <algorithm> <digest>
END
```

The timebase is strictly positive. Event timestamps and boundaries are each
strictly increasing. Every event contains at least one drive or active domain.
Drives are sorted by UTF-8 name bytes and unique; domain IDs are increasing,
unique, and must belong to the embedded top module. Parsing reconstructs the
checked bundle and requires exact reserialization, rejecting reordered fields,
noncanonical integers, extra lines, unknown sections, and duplicate entries.

Schema-2 stop conditions are `after_boundary`, `at_cycle` for migrated legacy
artifacts, `at_time`, `at_domain_edge <domain-id> <count>`, and
`output_equals`. Execution converts each replay event to LunaWave's atomic
timestamp event and calls the simulator once, so coincident domains sample the
same pre-commit state.

`migrate_schema1` is pure: it retains the canonical IR, options, stop, taps,
expected digest, and every declared boundary. It assigns every legacy action
its own increasing timestamp on timebase 1. Separate schema-1 edges therefore
remain separate and are never represented as coincident. A legacy clock with
no canonical sequential domain is rejected explicitly because schema 2 does
not invent domain identity.

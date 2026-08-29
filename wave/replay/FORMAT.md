# LunaWave replay schema 1

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

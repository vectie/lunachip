# Differential validation core

This package is the normalized boundary between LunaWave and independent
simulators. It deliberately imports neither simulator nor the RTL emitter.
Backend adapters perform execution and translate their native values into the
types here; this package only canonicalizes, compares, serializes, and reduces.

## Adapter contract

- Values are MSB-first `0/1/X`. `NormalizedValue::from_planes` accepts separate
  bit and known planes and discards payload bits wherever the known plane is
  zero. Canonical artifacts spell each value as explicit `width`, `value_bits`,
  and `known_mask` fields, with zero payload for every unknown bit.
- A `DesignIdentity` fixes the LunaChip semantic version and canonical-design
  SHA-256. A `ResultIdentity` adds the exact stimulus artifact SHA-256. Both
  digests are exactly 64 lowercase hexadecimal digits; the schema never leaves
  the algorithm implicit.
- An observation key is `(event, cycle, phase, tap)`. `event` is the globally
  ordered simulation boundary; `cycle` is preserved as design metadata.
- `ObservationSet::checked` sorts observations by that key and rejects duplicate
  keys. `compare` rejects semantic-version, design-SHA-256, and
  stimulus-SHA-256 differences before examining values, then reports the same
  first mismatch regardless of the adapter's input-array order.
- Every generated stimulus sequence carries an explicit seed. Actions must be
  globally nondecreasing in both event and cycle. Every event has exactly one
  cycle. Drives within one coordinate form a simultaneous group: they are
  unique, sorted by UTF-8 bytes, and precede all edge/sample actions. An edge or
  sample terminates that group. Both adapters must apply the same grouping.
- `reduce_mismatch` never evaluates hardware. Its callback independently re-runs
  the candidate and returns a structured comparison; reduction continues only
  while the exact target `MismatchIdentity` remains. The result is a
  deterministic one-minimal subsequence.

## Canonical artifacts

`ObservationSet::to_canonical_text` and
`StimulusSequence::to_canonical_text` produce schema-versioned, newline-terminated
text. Names are lowercase UTF-8 hex, values are normalized `0/1/X`, observations
are in canonical key order, and stimulus ordinals preserve semantic order. A
reduced stimulus artifact is therefore suitable as the stimulus portion of a
LunaWave replay bundle or an external harness fixture.

`parse_observation_set` and `parse_stimulus_sequence` accept only this canonical
grammar, validate counts and ordinals, require explicit `sha256` algorithm
tokens, reconstruct checked values, and reject any input whose reserialization
does not reproduce the original bytes.

The external integration layer remains responsible for computing the embedded
SHA-256 values and recording LunaChip build identity, Verilator/toolchain lock
identity, selected taps, and expected mismatch/result digest around this
payload.

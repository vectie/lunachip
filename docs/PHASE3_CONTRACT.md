# Phase 3 SystemVerilog and differential-validation contract

This document fixes the integration contract between canonical LunaChip IR,
the conservative SystemVerilog emitter, the external Verilator process, and
the MoonBit differential comparator. It does not make SystemVerilog or
Verilator authoritative for LunaChip semantics; disagreement is a recorded
mismatch investigated against the normative semantics and independent tests.

## Artifact set

One emission produces three version-locked artifacts:

1. synthesizable SystemVerilog text;
2. a canonical emitted-name manifest mapping every module, port, and node ID
   to its generated identifier and source identity;
3. a harness contract listing top-level input/output widths, signedness, clock
   ports, and reset ports in canonical order.

All artifacts exclude timestamps, absolute workspace paths, pointer-derived
names, and host state. Identical canonical IR and emitter version must produce
identical bytes. Unsupported semantics fail with a checked diagnostic before
partial output is returned.

Emission also fails before artifacts when a nonempty module contains a node
outside the backward semantic closure of its outputs. The backend neither
silently performs dead-code elimination nor creates artificial sinks: every
node in the canonical module must remain truthfully represented in the emitted
name manifest.

## Conservative emitted subset

The initial backend emits one flat canonical module using SystemVerilog 2017:

- `logic`, with an explicit packed range for widths greater than one;
- `signed` only for canonical `SInt` values;
- ANSI input/output declarations;
- continuous assignments for combinational nodes;
- sized constants and explicit `$signed` interpretation where required;
- `always_ff @(posedge clock)` for registers;
- active-high synchronous reset, then enable, then implicit hold;
- no delays, event controls other than `posedge`, force/release, latches,
  implicit nets, unsized literals, wildcard ports, DPI, or vendor primitives.

Every stable combinational operation has one documented spelling. Width
extension, truncation, slicing, concatenation, and reinterpretation remain
visible; the backend never relies on implicit width growth to recover canonical
semantics. Signed comparison, arithmetic right shift, sign extension, and
signed full multiplication use explicit signed operands.

An explicit register initial value is a LunaWave startup contract, not a
portable ASIC-synthesizable construct. Phase 3 therefore rejects it rather
than emitting an `initial` block or silently dropping it. An unreset register
is emitted without initialization. Differential fixtures must reset all state
that they compare before the first observation.

## Stable names and source mapping

User names are debug identity, not trusted SystemVerilog identifiers. Emitted
identifiers use a fixed ASCII prefix plus canonical ordinal/UTF-8-hex identity;
they never use escaped identifiers. Keywords, punctuation, Unicode, case, and
user names beginning with generated prefixes cannot collide. The manifest is
the only supported translation back to canonical path/name/source metadata.

The encoded byte sequence begins directly after the canonical ordinal, so no
generated module or port name contains `__`, which is reserved in C++
implementations. Verilator therefore exposes the exact emitted port names as
C++ model members; the bridge has no second mangling or sanitizer layer.

Harnesses address top-level ports exclusively through this manifest. They must
not reconstruct or sanitize names independently.

## Independent execution profile

The selected tool is Verilator 5.050 (2026-07-01). The executable Phase 3 gate
uses the official OCI image pinned by the ARM64 platform-manifest digest
`sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`.
The separately locked Homebrew bottle has SHA-256
`161b3a7a2574d1f48d129b17962aba0844a857c7dab504f803194daa96ec5d51`,
and is limited to identity checks and lint because compilation would introduce
an unpinned host C++ toolchain. A lock is an input; an evidence record
separately captures observed tool version, commands, exit codes, and artifact
digests.

Lint policy begins with:

```text
--lint-only --Wall --Wpedantic --language 1800-2017
```

Warnings remain fatal. No `--bbox-*`, `-Wno-fatal`, broad warning suppression,
or implicit top selection is permitted. Any narrow waiver requires a reviewed
contract change and recorded reason.

Verilator is a two-state compiled oracle for this phase. Runs explicitly select
deterministic zero handling for unobservable startup X values, reset compared
state before observation, drive only fully known inputs, and reject any
LunaWave observation containing X from the two-state comparison set. This is a
declared validation profile, not a change to LunaWave's bit-precise X semantics.

## Stimulus and result bridge

Stimuli are canonical event records with an explicit design digest, semantic
version, seed, cycle, boundary, and simultaneous named input values. Clock
edges are separate records. The same stimulus bytes feed LunaWave and the C++
Verilated-model harness.

Results contain the same cycle/boundary plus canonical tap identities and
normalized `(width, value_bits, known_mask)` values. The Verilator bridge marks
every returned bit known. The comparator rejects design/stimulus identity
mismatch before comparing observations, then reports the first mismatch in
stable event/tap order without hiding later raw artifacts.

The harness manifest declares signedness for every port and a top-level reset
object with its port, active-high polarity, and synchronous timing. These are
required schema fields, not conventions inferred from names. Result TSV files
are independently self-identifying with the semantic version, design SHA-256,
and exact stimulus SHA-256 before any observation row is accepted.
Phase 3 harness ports are limited to 64 bits so the schema matches the bridge's
single-word parser; wider RTL must fail rather than truncate.

Random generation uses a specified algorithm and explicit seed; host library
random functions are prohibited. The Phase 3 gate aggregates at least 100,000
post-reset cycles across representative combinational, arithmetic, controlled
register, pipeline, LFSR, and ready/valid designs.

## Reduction and evidence

A mismatch reducer may remove stimulus chunks and individual events only when
a caller-provided independent failure predicate confirms the same stable
mismatch identity. It must terminate deterministically and emit a canonical
replay fixture. Reduction never rewrites values or invents a smaller semantic
operation.

The Phase 3 evidence record includes:

- canonical IR, RTL, manifest, harness, stimulus, and result digests;
- MoonBit compiler and LunaChip commit;
- external-tool lock digest and observed executable/version;
- exact lint/build/run commands and exit statuses;
- seed, cycle count, design list, comparison result, and reduced replay digest
  for every mismatch.

Remote Docker contexts may select the checked `volume` workspace transport.
Inputs are copied into an isolated labeled volume, mounted read-only for the
locked container, and outputs are copied back from a distinct writable volume.
The runner disables networking and ccache, uses a read-only root filesystem,
drops capabilities, applies `no-new-privileges`, and removes scoped containers
and volumes on both success and failure. Transport changes no provider,
semantic, lint, or comparison rule.

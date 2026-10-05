# FluxTile capability manifest

The fetched concurrent device needs a machine-readable capability contract that
an external adapter can consume without importing LunaWire or LunaWave. This
slice publishes the capabilities of the implemented draft 0.2 profile. It does
not promote the descriptor format to ABI v1 or claim that the independent
Phase 6 gates have passed. The stable ABI decision follows the contract audit
and independent device-boundary validation.

## Package and construction

`device/capabilities` owns a checked immutable `Capabilities` value, its error
type and deterministic manifest serialization. It imports only core packages;
it must not import hardware construction, simulation, model-serving or fleet
code. `Capabilities::new` takes explicit labeled rows, columns, maximum
reduction, host aperture, ring depth and queue depth. Public callers can inspect
the configuration but cannot construct an unchecked value.

The hardware package provides `ring_concurrent_from_capabilities` to elaborate
that same configuration through the existing fetched concurrent generator.
The resulting canonical IR must be byte-identical to the existing constructor
with the corresponding six arguments. This is a configuration bridge, not a
second graph, transport or command decoder.

## Manifest identity and scope

The manifest is a newline-terminated JSON object with a fixed field order.
Schema identity is `lunachip.flux-tile-capabilities/v1`; this version belongs to
the manifest schema, not the descriptor ABI. Device profile is
`fetched-concurrent-draft-0.2`, module is `FluxTileHostConcurrent`, and
`experimental` is true. Descriptor major/minor are explicitly 0/2. Consumers
must select that profile/version deliberately; this document promises no ABI
v1 compatibility or automatic translation from draft 0.1.

The manifest describes functional configuration and semantics, not evidence
status. It contains no timestamp, workspace path, tool version, artifact digest,
frequency, bandwidth, area, power or physical RAM claim. Independent gate
artifacts bind their own canonical-design digest using the existing evidence
machinery. There is no manifest parser in this publisher-only slice; consumers
own parsing and must reject unsupported required profiles and versions.

## Configuration and fixed capabilities

| Field | Meaning and allowed value |
|---|---|
| `rows`, `columns` | Physical array dimensions, each 1 through 8. |
| `max_reduction` | Physical operand-bank capacity, 1 through 4096. |
| `host_bytes` | Exclusive byte-aperture end, 1 through 4294967296. |
| `ring_depth` | Physical host descriptor slots, one of 2, 4, 8, 16. |
| `queue_depth` | Four-lane descriptor FIFO capacity, 2 through 16. |
| `retirement_depth` | Equal to queue depth; independent of FIFO occupancy. |
| `descriptor_bytes`, `ring_alignment_bytes` | Both 32. |
| `operand_slots`, `result_slots`, `arrays` | Two A slots, two B slots, two C slots, one array. `operand_slots` means slots per operand kind. |
| `operand_bits`, `accumulator_bits` | Signed INT8 and signed INT32, respectively. |
| `memory_address_bits`, `memory_tag_bits` | Both 32. |
| `memory_outstanding` | One globally outstanding transaction across all three clients. |
| `read_bytes`, `write_bytes` | One-byte reads and four-byte little-endian writes. |
| `command_id_bits` | 32; duplicate caller IDs are permitted. |
| `dispatch_heads`, `reader_packets` | One separate dispatch head and one held reader packet. |

The manifest also states little-endian encoding, opcodes
`LoadA`, `LoadB`, `MatMul`, `StoreC`, `Fence`, strict dispatch, ordered held
retirement, latest-writer dependency tracking, whole-slot leases and joint
device/transport reset. FIFO capacity is not the total accepted-command count:
the retirement table and head are additional owners; the reader's unadmitted
packet still owns its host ring slot. Consumer advancement means atomic queue
admission, not command dispatch or completion.

Counters are UInt32 modeled compute/capture counters. They reset on successful
inner-core issue, not outer descriptor acceptance; invalid preflight retains
the preceding values. Arithmetic overflow follows fixed-width wrap. The
manifest must not imply workload totals, wall-clock performance or an atomic
multi-register snapshot. Fault and reset semantics remain those of
[the fetched concurrent contract](PHASE6_RING_CONCURRENT.md).

## Validation and commit boundary

Public contract tests cover the checked example, supported endpoint values,
each rejected configuration field, deterministic serialization and exact fixed
profile semantics. Tests compare the manifest's configuration with actual
elaboration metadata and compare capability-driven elaboration with the
existing constructor's canonical bytes. Existing direct and queued canonical
goldens must remain unchanged. One completed-slice native gate is required.

Commit the pure contract and targeted tests first, then the hardware bridge and
its cross-checks, then the generated interfaces and evidence record. The
capability manifest makes the remaining external-gate work target an explicit
device profile; it does not replace that work or narrow the Phase 6 exit gate.

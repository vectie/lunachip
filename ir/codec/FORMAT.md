# LunaChip canonical IR text format

Schema version 3 extends the strict, line-oriented interchange format with
first-class synchronous memories and the checked Reset-to-`Bits(1)`
`reinterpret` used to gate reset-sensitive component requests. Designs that
use neither extension continue to emit schema 2 byte-for-byte, so Phase 4 does
not churn existing artifacts or digests. The parser strictly accepts canonical
schema 1, 2, and 3 documents; new serialization emits schema 3 when either
extension is present.

## Envelope

    LUNACHIP-IR <2-or-3>
    DESIGN <hex-name>
    TOP <hex-name>
    MODULES <decimal-count>
    <module>...
    END

Every record occupies one line, fields are separated by exactly one ASCII
space, decimal integers have no sign or leading zeroes except the value `0`,
and the document ends immediately after the newline following `END`.

Names are nonempty UTF-8 byte strings encoded as two lowercase hexadecimal
digits per byte. This makes whitespace, Unicode, and control characters
unambiguous without relying on locale or escaping rules.

Modules are ordered by the lexical order of their encoded name. A module is:

    MODULE <hex-name>
    NODES <decimal-count>
    <node>...
    MEMORIES <decimal-count>   # schema 3 only
    <memory>...                # schema 3 only
    OUTPUTS <decimal-count>
    <output>...
    ENDMODULE

Outputs are ordered by encoded name. Nodes remain in ascending validated
`NodeId` order because their ordinals are part of dependency references.

## Types and records

Signal types are `clock`, `reset`, `bits:<width>`, `uint:<width>`, or
`sint:<width>`.

    NODE <id> <type> input <hex-name>
    NODE <id> <type> const <u64>
    NODE <id> <type> add|sub|mul_low|mul_full|and|or|xor|eq|lt|le <lhs> <rhs>
    NODE <id> <type> not <value>
    NODE <id> <type> shl|lshr|ashr <value> <amount>
    NODE <id> <type> slice <value> <msb> <lsb>
    NODE <id> <type> concat <most-significant> <least-significant>
    NODE <id> <type> zext|sext|trunc|reinterpret <value>
    NODE <id> <type> mux <select> <true> <false>
    NODE <id> <type> reg <clock> <next> <reset> <reset-value> <enable> <initial>
    NODE <id> <type> memread <memory-id> <read-port-id>
    OUTPUT <hex-name> <type> <driver>

For a schema 2 register, each absent optional field is `-`. Reset is a pair:
both `<reset>` and `<reset-value>` must be present, or both must be `-`.
`<enable>` and `<initial>` are independently optional. The clock edge is rising
in this schema. For example, an uninitialized always-enabled register is
`reg 0 4 - - - -`; a resettable, enabled register initialized to zero is
`reg 0 4 1 0 2 0`.

Schema 1 used `reg <clock> <next> none` or
`reg <clock> <next> some <u64>`. Reading it creates a rising-edge domain with no
reset or enable. Memory-free serialization emits schema 2; schema 1 is retained
only as a strict compatibility reader.

## Schema 3 memories

A memory is first-class module state rather than an operation hidden inside a
node. Its read-result node is an explicit typed identity and a combinational
cycle break. Memory and port IDs stay in validated ascending ordinal order.

    MEMORY <id> <hex-name> <element-type> <depth> <clock> rising \
      <read-write-policy> <multi-write-policy> <bounds-policy>
    READS <count>
    READ <id> <hex-name> <clock> rising <address> <enable> one \
      <enable-behavior> <result-node>
    WRITES <count>
    WRITE <id> <hex-name> <clock> rising <address> <data> <enable> all
    WRITE <id> <hex-name> <clock> rising <address> <data> <enable> \
      granular <mask> <granularity>
    ENDMEMORY

`<depth>` is positive. The address signal is `UInt(max(1,
ceil(log2(depth))))`; wider or differently typed addresses are not silently
truncated. The element type is an explicit data type. The memory and every port
repeat one exact rising-edge clock domain; cross-domain memories are rejected
until the multi-clock phase. Each read has exactly `one` cycle of latency and
its result register, like every uninitialized cell, begins X.

An absent enable is `-`. Read-enable behavior is `hold_last` or `undefined`.
A whole-element write uses `all`. A granular write names a `Bits` mask with one
bit per contiguous granule; element width must be exactly divisible by the
positive granularity.

Read/write policies are `read_old`, `read_new`, `no_change`, `undefined`, and
`reject`. `read_new` observes the fully resolved masked-write value. Because
schema 3 has no static address-disjointness proof, `reject` is construction
invalid whenever a memory has both read and write ports. Multi-write policy is
`reject` or `lower_port_id_wins`; priority is resolved independently for each
written granule. A statically identical write-address node is rejected under
the former policy, while dynamic collisions remain a runtime fault/property.
Bounds policy is `fault` or `undefined`: faulting accesses produce a simulator
fault and property failure; undefined reads produce X and undefined writes are
suppressed.

Schema 3 with no memory is canonical only when at least one node converts a
Reset to `Bits(1)` through `reinterpret`. Schema 1/2 documents containing that
conversion are rejected with a typed version error. This keeps the legacy
schemas closed instead of silently expanding their type rules.

The parser rebuilds nodes, modules, and designs through the public checked IR
constructors. It then serializes the result and requires byte-for-byte equality
with the input. It therefore rejects unknown versions, malformed records,
invalid UTF-8, invalid IR, noncanonical ordering, alternate integer spellings,
extra whitespace, and trailing content instead of silently normalizing them.

## Bootstrap content digest

`content_digest` computes FNV-1a-64 over the exact UTF-8 bytes returned by
`serialize`. The fixed-width lowercase hexadecimal representation is stable
across runs and construction order.

FNV-1a-64 is intentionally a bootstrap, noncryptographic content digest. It is
appropriate for deterministic caches, fixture identity, and reproducibility
checks. It is not appropriate for signatures, untrusted collision resistance,
or security boundaries; those require a future versioned cryptographic digest.

# LunaChip canonical IR text format

Schema version 4 adds an explicit module-local clock-domain table and explicit
reset mode/polarity fields. It is selected only when a validated design has
more than one distinct domain or uses reset semantics not representable by the
legacy active-high synchronous form. One-domain designs retain their exact
schema-2 or schema-3 bytes and content digests.

Schema version 3 remains the memory and Reset-to-`Bits(1)` extension. The
parser strictly accepts canonical schema 1 through 4 documents, but a document
whose behavior requires a later schema is rejected with a typed version error
instead of silently broadening an older schema.

## Envelope

    LUNACHIP-IR <2-or-3-or-4>
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
    DOMAINS <decimal-count>    # schema 4 only
    <domain>...                # schema 4 only
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

## Schema 4 clock domains and resets

Schema 4 declares every used domain once before the node table:

    DOMAIN <domain-id> <clock-node> rising

For the rising-edge-only Phase-5 foundation, a canonical domain ID equals its
clock node ordinal. Domain records are ordered by this ID and duplicate exact
definitions are interned by LunaWire before module finalization. Unknown,
conflicting, negative, noncanonical, reordered, or non-clock definitions fail
closed. The explicit ID is the future event-scheduler identity; schema 4 does
not yet claim atomic coincident-edge execution.

Schema-4 registers reference the domain table and make reset semantics fully
explicit:

    NODE <id> <type> reg <domain-id> <next> <reset> <reset-value> \
      <reset-mode> <reset-polarity> <enable> <initial>

An absent reset is the exact quadruple `- - - -`. Present reset modes are
spelled `synchronous` or `asynchronous`; polarities are `active_high` or
`active_low`. The schema represents these choices now so later event semantics
do not require another structural migration. At this foundation milestone,
module validation accepts only `synchronous active_high`. Asynchronous and
active-low reset artifacts are rejected with typed unsupported-feature errors
until their simulator, emitter, replay, and differential semantics land
together.

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

When schema 4 is selected, the memory and each port replace their repeated
`<clock> rising` pair with one `<domain-id>` field while retaining every other
field and ordering rule:

    MEMORY <id> <hex-name> <element-type> <depth> <domain-id> \
      <read-write-policy> <multi-write-policy> <bounds-policy>
    READ <id> <hex-name> <domain-id> <address> <enable> one \
      <enable-behavior> <result-node>
    WRITE <id> <hex-name> <domain-id> <address> <data> <enable> all
    WRITE <id> <hex-name> <domain-id> <address> <data> <enable> \
      granular <mask> <granularity>

Memory ports must still use the memory's exact single domain. Schema 4 does not
silently turn the synchronous memory primitive into a mixed-clock memory.

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

# LunaChip canonical IR text format

Schema version 1 is a strict, line-oriented interchange format for validated
LunaChip IR. Its canonical UTF-8 bytes are suitable for reproducible golden
files and deterministic cache keys.

## Envelope

    LUNACHIP-IR 1
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
    NODE <id> <type> reg <clock> <next> none
    NODE <id> <type> reg <clock> <next> some <u64>
    OUTPUT <hex-name> <type> <driver>

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

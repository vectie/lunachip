# Provisional FluxTile descriptor codec

This pure native package owns the little-endian 32-byte descriptor syntax for
format **0.1**. It imports no hardware builder, simulator, serving engine, or
fleet-management product. The format is provisional, not device ABI v1.

| Bytes | Encoding |
|---|---|
| 0–3 | Major 0, minor 1, opcode 0..4, reserved zero |
| 4–7 | Completion identity UInt32 |
| 8–13 | Rows, columns, reduction, each UInt16 containing a UInt13 value |
| 14–15 | Flags, zero |
| 16–23 | Base and stride, each UInt32 |
| 24–31 | Reserved zero |

```mbt check
test {
  let command : @descriptor.Descriptor = {
    opcode: LoadA,
    id: 42U,
    rows: 2U,
    columns: 3U,
    reduction: 0U,
    base: 32U,
    stride: 8U,
  }
  let bytes = command.encode()
  assert_eq(bytes.length(), @descriptor.byte_length())
  assert_eq(@descriptor.decode(bytes[:]), command)
}
```

The codec rejects unknown versions, nonzero reserved bytes/flags, unknown
opcodes, and dimension values that cannot fit UInt13. It deliberately does not
validate device-dependent shapes, initialized operand/result slots, unused
command fields, stride, alignment, or host aperture; hardware validates those
before issuing work. Encoding never silently truncates dimensions.

The queued hardware shell accepts one complete packet through four 64-bit
lanes in one ready/valid handshake. It is not a host-memory DMA descriptor
fetcher or a partial-beat register interface. See
[the frontend contract](../../docs/PHASE6_FRONTEND.md) for the byte layout,
hardware fault mapping, capacity, ordered completion, and reset behavior.

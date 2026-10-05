# Slotted descriptor encoding 0.2

This pure native package owns the 32-byte little-endian syntax of encoding **0.2**.
It reuses the public opcode type from `device/descriptor` but accepts only 0.2.
The existing 0.1 package remains unchanged and rejects these newer packets.
The fetched concurrent profile binds these unchanged bytes through
[logical Device ABI 1.0](../../docs/PHASE6_DEVICE_ABI.md). Device and descriptor
versions are distinct: descriptor bytes remain major 0, minor 2. The codec owns
syntax, not device ownership or independent verification evidence.

| Bytes | Encoding |
| --- | --- |
| 0–3 | Major 0, minor 2, opcode 0..4, reserved zero |
| 4–7 | Caller completion identity UInt32 |
| 8–13 | Rows, columns, reduction: UInt16 containing UInt13 values |
| 14–15 | Flags, required zero |
| 16–23 | Base and stride: UInt32 each |
| 24, 25, 26 | A, B, C slot respectively in bit 0; upper seven bits zero |
| 27–31 | Reserved zero |

```mbt check
///|
test {
  let command : @slotted_descriptor.Descriptor = {
    opcode: MatMul,
    id: 42U,
    rows: 2U,
    columns: 3U,
    reduction: 4U,
    base: 0U,
    stride: 0U,
    a_slot: 1U,
    b_slot: 0U,
    c_slot: 1U,
  }
  let bytes = command.encode()
  assert_eq(bytes.length(), @slotted_descriptor.byte_length())
  assert_eq(@slotted_descriptor.decode(bytes[:]), command)
}
```

Decoding rejects length, version, reserved fields, opcode and dimension
representation in that order. Reserved fields are checked by ascending byte
offset. Encoding checks every dimension and selector before narrowing, even
when that field is unused by the operation. Caller IDs may duplicate.

The codec preserves syntax-valid operation-specific unused fields and selectors;
hardware rejects them with fault 2. It does not validate physical shapes,
dependencies, strides, alignment or aperture bounds. See
[the queued concurrent contract](../../docs/PHASE6_QUEUED_CONCURRENT.md) for
hardware dispatch, intended generations, ordered retirement and reset rules.
No builder, simulator or host-memory device model is imported here.

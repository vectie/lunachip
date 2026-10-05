///|
fn descriptor_rejection_configuration() -> @capabilities.Capabilities raise {
  @capabilities.Capabilities::new(
    rows=2,
    columns=2,
    max_reduction=2,
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=3,
  )
}

///|
// Canonical templates are syntax-valid. Semantic overrides and malformed raw
// bytes are applied separately, exactly as the committed descriptor table.
fn descriptor_rejection_template(
  position : Int,
) -> @slotted_descriptor.Descriptor raise {
  let empty : @slotted_descriptor.Descriptor = {
    opcode: Fence,
    id: (201 + position).reinterpret_as_uint(),
    rows: 0,
    columns: 0,
    reduction: 0,
    base: 0,
    stride: 0,
    a_slot: 0,
    b_slot: 0,
    c_slot: 0,
  }
  match position {
    0 | 6..=15 | 18 | 23 | 32..=34 | 42 | 77 | 82 =>
      { ..empty, opcode: LoadA, rows: 1, columns: 1, base: 512, stride: 1, }
    1 | 19 =>
      { ..empty, opcode: LoadB, rows: 1, columns: 1, base: 640, stride: 1, }
    2 | 20 | 28 | 35 | 43..=45 | 60 | 63..=67 | 70 | 78 | 79 | 83 =>
      { ..empty, opcode: MatMul, rows: 1, columns: 1, reduction: 1, }
    26 | 30 | 36 | 46 | 61 | 68 | 71..=76 | 80 | 84 =>
      { ..empty, opcode: StoreC, rows: 1, columns: 1, base: 1536, stride: 4, }
    3 =>
      {
        ..empty,
        opcode: LoadA,
        rows: 1,
        columns: 1,
        base: 768,
        stride: 1,
        a_slot: 1,
      }
    4 | 16 | 24 | 37..=39 | 47 =>
      {
        ..empty,
        opcode: LoadB,
        rows: 1,
        columns: 1,
        base: 896,
        stride: 1,
        b_slot: 1,
      }
    5 | 17 | 25 | 29 | 40 | 48 =>
      {
        ..empty,
        opcode: MatMul,
        rows: 1,
        columns: 1,
        reduction: 1,
        a_slot: 1,
        b_slot: 1,
        c_slot: 1,
      }
    21 | 27 | 31 | 41 | 49..=51 | 62 | 69 | 81 =>
      {
        ..empty,
        opcode: StoreC,
        rows: 1,
        columns: 1,
        base: 1792,
        stride: 4,
        c_slot: 1,
      }
    22 | 52..=59 | 85 => empty
    _ => fail("invalid descriptor-rejection packet position \{position}")
  }
}

///|
fn descriptor_rejection_packet(position : Int) -> Bytes raise {
  if position < 0 || position >= 86 {
    fail("invalid descriptor-rejection packet position \{position}")
  }
  let template = descriptor_rejection_template(position)
  let descriptor : @slotted_descriptor.Descriptor = match position {
    32 | 37 | 49 | 54 => { ..template, reduction: 1, }
    33 | 51 | 58 => { ..template, b_slot: 1, }
    34 | 39 | 59 => { ..template, c_slot: 1, }
    38 | 57 => { ..template, a_slot: 1, }
    44 => { ..template, base: 1, rows: 0, reduction: 0, }
    45 | 56 => { ..template, stride: 1, }
    50 => { ..template, a_slot: 1, rows: 0, base: 4095, stride: 0, }
    52 => { ..template, rows: 1, }
    53 => { ..template, columns: 1, }
    55 => { ..template, base: 1, }
    63 | 78 => { ..template, rows: 0, }
    64 => { ..template, rows: 3, }
    65 => { ..template, columns: 3, }
    66 => { ..template, reduction: 3, }
    67 => { ..template, reduction: 2, }
    68 | 80 => { ..template, base: 4095, stride: 0, }
    69 => { ..template, rows: 2, base: 4095, stride: 0, }
    71 => { ..template, base: 4095, stride: 3, }
    72 => { ..template, stride: 5, }
    73 => { ..template, base: 4095, }
    74 => { ..template, base: 4096, }
    75 => { ..template, base: 0xfffffffc, }
    77 => { ..template, rows: 2, base: 0xffffffff, stride: 1, }
    82 => { ..template, base: 1024, }
    84 => { ..template, base: 2048, }
    _ => template
  }
  let bytes = descriptor.encode().to_array()
  // These mutations bypass checked encoding only after a complete canonical
  // packet exists. Preserve all competing errors; never decode/re-encode it.
  match position {
    6 => {
      bytes[0] = b'\x01'
      bytes[1] = b'\x00'
      bytes[3] = b'\x01'
      bytes[2] = b'\xff'
      bytes[8] = b'\x00'
      bytes[9] = b'\x20'
    }
    7 => {
      bytes[3] = b'\x01'
      bytes[2] = b'\xff'
      bytes[8] = b'\x00'
      bytes[9] = b'\x20'
    }
    8 => bytes[14] = b'\x01'
    9 => bytes[15] = b'\x01'
    10..=14 => bytes[27 + position - 10] = b'\x01'
    15 => bytes[24] = b'\x02'
    16 => bytes[25] = b'\x03'
    17 => bytes[26] = b'\x03'
    18 => {
      bytes[2] = b'\x08'
      bytes[8] = b'\x00'
      bytes[9] = b'\x20'
    }
    19 => bytes[2] = b'\x09'
    20 => bytes[2] = b'\x0a'
    21 => bytes[2] = b'\x0b'
    22 => bytes[2] = b'\x0c'
    23 => {
      bytes[8] = b'\x00'
      bytes[9] = b'\x20'
    }
    24 => {
      bytes[10] = b'\x00'
      bytes[11] = b'\x20'
    }
    25 => {
      bytes[12] = b'\x00'
      bytes[13] = b'\x20'
    }
    _ => ()
  }
  Bytes::from_array(bytes[:])
}

///|
fn descriptor_rejection_install(
  memory : Array[Int],
  position : Int,
) -> Unit raise {
  if memory.length() != 4096 {
    fail("descriptor-rejection host memory must contain exactly 4096 bytes")
  }
  let bytes = descriptor_rejection_packet(position)
  for index in 0..<bytes.length() {
    memory[3072 + position % 4 * 32 + index] = bytes[index].to_int()
  }
}

///|
fn descriptor_rejection_memory() -> Array[Int] raise {
  let memory = Array::make(4096, 165)
  for (address, value) in [(512, 2), (640, 3), (768, 5), (896, 7), (1024, 9)] {
    memory[address] = value
  }
  // Refill installation belongs to the stimulus after pre-edge consumer credit.
  for position in 0..<3 {
    descriptor_rejection_install(memory, position)
  }
  memory
}

///|
// Exclusive ends. Each group is drained before any physical slot is reused.
fn descriptor_rejection_groups() -> Array[(Int, Int)] {
  [
    (0, 3),
    (3, 6),
    (6, 10),
    (10, 14),
    (14, 18),
    (18, 22),
    (22, 26),
    (26, 28),
    (28, 30),
    (30, 32),
    (32, 36),
    (36, 37),
    (37, 41),
    (41, 42),
    (42, 44),
    (44, 47),
    (47, 49),
    (49, 52),
    (52, 56),
    (56, 60),
    (60, 63),
    (63, 67),
    (67, 70),
    (70, 71),
    (71, 75),
    (75, 76),
    (76, 77),
    (77, 81),
    (81, 82),
    (82, 85),
    (85, 86),
  ]
}

///|
fn sparse_transport(
  alias_mask : UInt64,
  max_io : Int32,
) -> @pblaze3_host.Transport {
  let memory : Map[UInt64, Byte] = Map([])
  {
    read: (address, length) => {
      Bytes::makei(Int32::min(length, max_io), i => {
        memory.get((address + i.to_uint64()) & alias_mask).unwrap_or(0)
      })
    },
    write: (address, bytes) => {
      let count = Int32::min(bytes.length(), max_io)
      for i in 0..<count {
        memory[(address + i.to_uint64()) & alias_mask] = bytes[i]
      }
      count
    },
  }
}

///|
test "2GiB contract accepts upper memory and rejects overflow without transport access" {
  let m = @pblaze3_host.default_manifest()
  m.check_range(0x7ffffff0, 16)
  m.check_range(0x80000000, 0)
  for
    (address, length) in [
      (0x80000000UL, 1UL),
      (0x7ffffff0UL, 17UL),
      (0xffffffffffffffffUL, 1UL),
      (0UL, 0xffffffffffffffffUL),
    ] {
    try m.check_range(address, length) catch {
      InvalidRange(..) => ()
      _ => fail("wrong error")
    } noraise {
      _ => fail("out-of-range accepted")
    }
  }
  let invalid = { ..m, capacity_bytes: 0x100000000, }
  try invalid.validate() catch {
    InvalidManifest(field="capacity_bytes") => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("4GiB vendor contract accepted")
  }
  let called = [false]
  let transport : @pblaze3_host.Transport = {
    read: (_, _) => {
      called[0] = true
      b""
    },
    write: (_, _) => {
      called[0] = true
      0
    },
  }
  try @pblaze3_host.write_exact(m, transport, 0x7fffffff, b"bad") catch {
    InvalidRange(..) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("invalid write accepted")
  }
  assert_false(called[0])
}

///|
test "partial transport progress is accumulated exactly across high addresses" {
  let transport = sparse_transport(0xffffffffffffffff, 7)
  let m = @pblaze3_host.default_manifest()
  let address = 0x7fffff00UL
  let bytes = @pblaze3_host.pattern(address, 256, 19)
  @pblaze3_host.write_exact(m, transport, address, bytes)
  assert_eq(@pblaze3_host.read_exact(m, transport, address, 256), bytes)
  @pblaze3_host.memory_smoke(m, transport, 42)
}

///|
test "two-phase memory smoke detects 256MiB address alias" {
  try
    @pblaze3_host.memory_smoke(
      @pblaze3_host.default_manifest(),
      sparse_transport(0x0fffffff, 4096),
      42,
    )
  catch {
    DataMismatch(..) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("alias was missed")
  }
}

///|
test "zero progress, oversized return and transport failure are checked" {
  let m = @pblaze3_host.default_manifest()
  let zero : @pblaze3_host.Transport = {
    read: (_, _) => b"",
    write: (_, _) => 0,
  }
  try @pblaze3_host.read_exact(m, zero, 0, 4) catch {
    ShortIo(operation="read", ..) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("zero read accepted")
  }
  try @pblaze3_host.write_exact(m, zero, 0, b"test") catch {
    ShortIo(operation="write", ..) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("zero write accepted")
  }
  let over : @pblaze3_host.Transport = {
    read: (_, _) => b"extra",
    write: (_, _) => 5,
  }
  try @pblaze3_host.read_exact(m, over, 0, 4) catch {
    InvalidIoCount(..) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("oversized read accepted")
  }
  try @pblaze3_host.write_exact(m, over, 0, b"test") catch {
    InvalidIoCount(..) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("oversized write accepted")
  }
  let failure : @pblaze3_host.Transport = {
    read: (_, _) => raise TransportFailure(message="device removed"),
    write: (_, _) => 0,
  }
  try @pblaze3_host.read_exact(m, failure, 0, 4) catch {
    TransportFailure(message="device removed") => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("failure swallowed")
  }
}

///|
test "pattern survives arbitrary chunk splits and changes across high address bits" {
  let whole = @pblaze3_host.pattern(4093, 97, 0)
  let split = @pblaze3_host.pattern(4093, 7, 0) +
    @pblaze3_host.pattern(4100, 90, 0)
  assert_eq(whole, split)
  assert_false(
    @pblaze3_host.pattern(0, 4096, 42) ==
    @pblaze3_host.pattern(0x10000000, 4096, 42),
  )
}

///|
test "XDMA register access uses BAR offset and tool arguments stay separate" {
  let m = @pblaze3_host.default_manifest()
  let r = @pblaze3_host.register_command(m, "/dev/xdma0_user", 16, None)
  assert_eq(r.arguments[1], "0x10")
  assert_eq(r.arguments.length(), 3)
  try
    @pblaze3_host.register_command(m, "/dev/xdma0_user", 0x40000000, None)
  catch {
    InvalidRegister(..) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("AXI translated address accepted as BAR offset")
  }
  let d = @pblaze3_host.dma_command(
    m,
    write=true,
    "/dev/xdma0_h2c_0",
    0x7ffff000,
    4096,
    "with spaces;$().bin",
  )
  assert_eq(d.arguments[3], "0x7ffff000")
  assert_eq(d.arguments[9], "with spaces;$().bin")
}

///|
test "status rejects wrong image identity and decodes capability words" {
  let words : Array[UInt32] = [
    0x50423330, 0x10001, 5, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0x80000000, 0, 31, 1, 9,
  ]
  let status = @pblaze3_host.decode_status(words)
  assert_true(status.healthy && status.done && !status.busy && !status.fault)
  assert_true(status.provisional_board)
  words[0] = 0
  try @pblaze3_host.decode_status(words) catch {
    InvalidManifest(field="device_id") => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("wrong image accepted")
  }
}

///|
test "program and scratch plans enforce ABI windows and little endian words" {
  let m = @pblaze3_host.default_manifest()
  let bytes = b"\x01\x23\x45\x67" + Bytes::make(60, 0)
  let commands = @pblaze3_host.program_commands(m, "/dev/xdma0_user", bytes)
  assert_eq(commands.length(), 16)
  assert_eq(commands[0].arguments[1], "0x20000")
  assert_eq(commands[0].arguments[3], "0x67452301")
  assert_eq(commands[15].arguments[1], "0x2003c")
  let scratch = @pblaze3_host.scratch_commands(
    m, "/dev/xdma0_user", b"\x00\x00\x80\x3f",
  )
  assert_eq(scratch[0].arguments[1], "0x40000")
  assert_eq(scratch[0].arguments[3], "0x3f800000")
  let start = @pblaze3_host.start_commands(m, "/dev/xdma0_user", 2048)
  assert_eq(start[0].arguments[1], "0x14")
  assert_eq(start[1].arguments[1], "0x10")
  try @pblaze3_host.start_commands(m, "/dev/xdma0_user", 2049) catch {
    InvalidChunk(..) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("oversized program accepted")
  }
}

///|
test "FP32 checker applies original tolerance and rejects nonfinite or corrupt words" {
  let reference = b"\x00\x00\x80\x3f"
  let within = b"\x01\x00\x80\x3f"
  let summary = @pblaze3_host.compare_fp32(reference, within)
  assert_eq(summary.words, 1)
  assert_eq(summary.exact_words, 0)
  for actual in [b"\x00\x00\x00\x40", b"\x00\x00\x80\x7f", b"\x00\x00\xc0\x7f"] {
    try @pblaze3_host.compare_fp32(reference, actual) catch {
      FloatMismatch(..) | NonfiniteFloat(..) => ()
      _ => fail("wrong error")
    } noraise {
      _ => fail("invalid actual accepted")
    }
  }
  try @pblaze3_host.compare_fp32(b"\x00\x00\xc0\x7f", reference) catch {
    NonfiniteFloat(reference=true, ..) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("nonfinite reference accepted")
  }
}

///|
test "DDR smoke GPIO status requires calibration link and reset release" {
  assert_true(@pblaze3_host.decode_smoke_status(7).healthy)
  for word in [0U, 3U, 5U, 6U] {
    assert_false(@pblaze3_host.decode_smoke_status(word).healthy)
  }
  try @pblaze3_host.decode_smoke_status(8) catch {
    InvalidManifest(field="smoke_status_reserved") => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("reserved status bit accepted")
  }
}

///|
test "completion requires accepted next launch and verified count, including wrap" {
  let words : Array[UInt32] = [
    0x50423330, 0x10001, 5, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0x80000000, 0, 31, 1, 9,
  ]
  let status = @pblaze3_host.decode_status(words)
  assert_true(@pblaze3_host.check_launch(8, 1, status))
  assert_false(@pblaze3_host.check_launch(9, 1, status))
  assert_true(
    @pblaze3_host.check_launch(0xffffffff, 1, { ..status, launch_sequence: 0, }),
  )
  assert_false(@pblaze3_host.check_launch(8, 1, { ..status, busy: true, }))
  try
    @pblaze3_host.check_launch(9, 1, { ..status, launch_sequence: 0, })
  catch {
    InvalidManifest(field="unexpected_launch_sequence") => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("reset sequence accepted")
  }
  try @pblaze3_host.check_launch(7, 1, status) catch {
    InvalidManifest(field="unexpected_launch_sequence") => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("unexpected sequence accepted")
  }
  try @pblaze3_host.check_launch(8, 2, status) catch {
    InvalidManifest(field="completion_program_count") => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("wrong completed program count accepted")
  }
  words[1] = 0x10000
  try @pblaze3_host.decode_status(words) catch {
    InvalidManifest(field="abi_version") => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("old image ABI accepted")
  }
}

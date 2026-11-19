///|
fn configure(
  b : Bench,
  length : Int32,
  jobs : Int32,
  vectors : Int32,
) -> Unit raise {
  for
    (address, data) in [
      (20UL, 0x100000UL),
      (24UL, 0x200000UL),
      (28UL, 0x300000UL),
      (32UL, length.to_uint64()),
      (36UL, jobs.to_uint64()),
      (40UL, vectors.to_uint64()),
    ] {
    assert_eq(b.write(address, data), 0UL)
  }
}

///|
fn finish(
  b : Bench,
  count : Int32,
  length : Int32,
  cold : Bool,
  expected : Array[Array[UInt32]],
) -> Unit raise {
  for _ in 0..<500000 {
    if value(b.sim, "observe_done") == 1UL {
      break
    }
    assert_eq(value(b.sim, "observe_fault"), 0UL)
    b.step()
  }
  assert_eq(value(b.sim, "observe_done"), 1UL)
  assert_eq(b.read(12UL), 0UL)
  assert_eq(b.read(0x34UL), count.to_uint64())
  assert_eq(
    b.read(0x4cUL),
    (count * 16 + (if cold { 128 } else { 0 })).to_uint64(),
  )
  assert_eq(b.read(0x50UL), (count * 2).to_uint64())
  assert_eq(
    b.read(0x54UL),
    (count * 512 + (if cold { 4096 } else { 0 })).to_uint64(),
  )
  assert_eq(b.read(0x58UL), (count * 8192).to_uint64())
  assert_eq(b.read(0x40UL), (count * 8193).to_uint64())
  assert_eq(b.read(0x48UL), (count * (5 * length + 4)).to_uint64())
  assert_eq(
    b.read(0x38UL),
    b.read(0x3cUL) + b.read(0x40UL) + b.read(0x44UL) + count.to_uint64(),
  )
  for job in 0..<count {
    for lane in 0..<8 {
      assert_eq(
        b.memory[0x300000U + (job * 32 + lane * 4).reinterpret_as_uint()],
        expected[job % expected.length()][lane],
      )
    }
  }
}

///|
fn fixture_bench(source : String) -> Bench raise {
  assert_eq(
    @verilator.sha256_hex(source),
    "eecb0a30731ce6645ef53a897c97aaa50a3e1d94399387c89b3dae1cb799ed8c",
  )
  guard @json.parse(source) is Array(jobs) && jobs.length() == 24 else {
    fail("24 pinned jobs required")
  }
  let b = bench(recording=true)
  let expected : Array[Array[UInt32]] = []
  for vector in 0..<3 {
    let row : Array[UInt32] = []
    for lane in 0..<8 {
      guard jobs[vector * 8 + lane]
        is { "words": Array(words), "expected_bits": Number(golden, ..), .. } else {
        fail("missing job")
      }
      let codes = words.map(x => {
        match x {
          Number(n, ..) => n.to_uint()
          _ => abort("word")
        }
      })
      let mut cpu : Float = 0.0
      for word in codes {
        let product = Float::reinterpret_from_uint(word & 0xffff0000U) *
          Float::reinterpret_from_uint((word & 65535U) << 16)
        cpu = cpu + product
      }
      assert_eq(cpu.reinterpret_as_uint(), golden.to_uint())
      row.push(cpu.reinterpret_as_uint())
      for pair in 0..<512 {
        let w = (codes[pair * 2] >> 16) | (codes[pair * 2 + 1] & 0xffff0000U)
        let a = (codes[pair * 2] & 65535U) | (codes[pair * 2 + 1] << 16)
        if vector == 0 {
          b.memory[0x100000U + (lane * 2048 + pair * 4).reinterpret_as_uint()] = w
        }
        if lane == 0 {
          b.memory[0x200000U + (vector * 2048 + pair * 4).reinterpret_as_uint()] = a
        }
      }
    }
    expected.push(row)
  }
  assert_eq(b.write(0x10000000UL, 0x89abcdefUL, data_first=true, hold=3), 0UL)
  assert_eq(b.read(0x10000000UL, hold=4), 0x89abcdefUL)
  assert_eq(b.write(16UL, 1UL), 2UL)
  assert_eq(b.read(0x20000000UL, response=2UL), 0UL)
  configure(b, 1024, 3, 3)
  b.environment(stalled=true)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<12 {
    b.step()
  }
  assert_eq(b.write(0x10100000UL, 0UL), 2UL)
  b.environment()
  finish(b, 3, 1024, true, expected)
  assert_eq(b.write(16UL, 1UL), 0UL)
  finish(b, 3, 1024, false, expected)
  b
}

///|
pub fn replay_bundle(
  source : String,
  core~ : Bool = false,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let b = fixture_bench(source)
  let h = if core { b.core_hw } else { b.hardware }
  let semantic = if core {
    "bf16-fp32-parallel-dot/v1"
  } else {
    "prx100-floating-point-ddr-controller/v1"
  }
  let d = @ir.Design::single(semantic, h)
  let e = @systemverilog.emit_design(d)
  let ports = @verilator.collect_ports(h, e.manifest())
  let stimulus = if core {
    b.core_stimulus.to_string()
  } else {
    b.stimulus.to_string()
  }
  let p = @verilator.ResultProtocol::checked(
    "LUNACHIP-FPDDR-RESULT", "1", semantic,
  )
  let identity = @differential.ResultIdentity::checked(
    @differential.DesignIdentity::checked(
      semantic,
      @verilator.sha256_hex(@codec.serialize(d)),
    ),
    @verilator.sha256_hex(stimulus),
  )
  ReadOnlyArray::from_array([
    { path: e.modules()[0].filename(), content: e.source(), },
    { path: "design.lcir", content: @codec.serialize(d), },
    { path: "manifest.json", content: @verilator.harness_json(e, ports), },
    {
      path: "harness.cpp",
      content: @verilator.harness_cpp(ports, identity, p),
    },
    { path: "stimulus.tsv", content: stimulus, },
    {
      path: "expected.tsv",
      content: p.magic() +
      "\t1\t" +
      @verilator.utf8_hex(semantic) +
      "\tsha256\t" +
      identity.design().design_sha256() +
      "\tsha256\t" +
      identity.stimulus_sha256() +
      "\n" +
      (if core { b.core_expected.to_string() } else { b.expected.to_string() }),
    },
    { path: "cycles.txt", content: (b.cycle - 1).to_string() + "\n", },
  ])
}

///|
test "DDR stalls, errors, cache invalidation and reset block publication" {
  let b = bench(watchdog=256UL)
  configure(b, 1, 1, 1)
  b.environment(stalled=true)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<300 {
    b.step()
  }
  assert_eq(value(b.sim, "observe_fault"), 1UL)
  assert_eq(b.read(12UL), 6UL)
  assert_eq(b.read(0x34UL), 0UL)
  assert_eq(b.write(16UL, 1UL), 2UL)
  assert_eq(b.write(0x10100000UL, 0UL), 2UL)
  b.set("reset", 1, 1UL)
  b.step()
  b.set("reset", 1, 0UL)
  b.environment()
  b.step()
  assert_eq(value(b.sim, "observe_fault"), 0UL)
  assert_eq(value(b.sim, "observe_cache"), 0UL)
  configure(b, 1, 1, 1)
  b.environment(fault=3UL)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<100 {
    b.step()
  }
  assert_eq(value(b.sim, "observe_fault"), 1UL)
  assert_eq(b.read(12UL), 3UL)
  assert_eq(b.read(0x34UL), 0UL)
}

///|
priv struct Replay {
  hw : @ir.Module
  sim : @sim.Simulator
  inputs : Array[@v.HarnessPort]
  outputs : Array[@v.HarnessPort]
  stimulus : StringBuilder
  expected : StringBuilder
  masks : StringBuilder
  mut cycles : Int32
  mut random : UInt32
  job_limit : Int32
  parallel_rows : Int32
  packed_weights : Bool
  delivery : Bool
}

///|
fn Replay::set(
  r : Replay,
  name : String,
  width : Int32,
  value : UInt64,
) -> Unit raise {
  r.sim.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
fn Replay::get(r : Replay, name : String) -> UInt64 raise {
  let v = r.sim.output(name)
  guard v.is_fully_known() else { fail("unknown output " + name) }
  v.value_bits()
}

///|
fn Replay::step(r : Replay) -> Unit raise {
  r.sim.settle()
  let row = [r.cycles.to_string()]
  for port in r.inputs {
    let node = r.hw
      .nodes()
      .iter()
      .find_first(n => n.kind() is Input(name) && name == port.source_name())
      .unwrap()
    let v = r.sim.value(node.id())
    assert_true(v.is_fully_known())
    row.push(@v.padded_hex(v.value_bits(), port.width()))
  }
  r.stimulus.write_string(row.join("\t") + "\n")
  r.sim.rising_edge("clock")
  if r.cycles > 0 {
    let row = [r.cycles.to_string()]
    let masks = [r.cycles.to_string()]
    for port in r.outputs {
      let value = r.sim.output(port.source_name())
      let mut mask = @v.width_mask(port.width())
      if !value.is_fully_known() {
        guard (
            port.source_name() == "program_read_data" &&
            r.get("program_read_valid") == 0UL
          ) ||
          (
            port.source_name() == "scratch_read_data" &&
            r.get("scratch_read_valid") == 0UL
          ) else {
          fail("unexpected unknown " + port.source_name())
        }
        mask = 0UL
      }
      row.push(@v.padded_hex(value.value_bits() & mask, port.width()))
      masks.push(@v.padded_hex(mask, port.width()))
    }
    r.expected.write_string(row.join("\t") + "\n")
    r.masks.write_string(masks.join("\t") + "\n")
  }
  r.cycles += 1
}

///|
fn Replay::execute(
  r : Replay,
  parallel~ : Bool = false,
  abort_drain~ : Bool = false,
  fault_prefetch~ : Bool = false,
  wide~ : Bool = false,
  batch~ : Bool = false,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
) -> Unit raise {
  let pending : Array[(UInt64, Bool, Bool)] = []
  r.set("start", 1, 1UL)
  r.step()
  r.set("start", 1, 0UL)
  let mut count = 0
  let mut injected = false
  while r.get("busy") == 1UL && count < r.job_limit {
    r.random = r.random * 1664525U + 1013904223U
    let ready = pending.is_empty() && (r.random & 3U) != 0U
    r.set("ddr_request_ready", 1, if ready { 1UL } else { 0UL })
    r.set("ddr_response_valid", 1, 0UL)
    if !pending.is_empty() && (r.random & 4U) != 0U {
      let (value, last, native_wide) = pending.remove(0)
      r.set("ddr_response_valid", 1, 1UL)
      r.set("ddr_response_data", 32, value)
      if wide {
        for i in 1..<(if r.delivery { 8 } else { 4 }) {
          r.set(
            "ddr_response_data" + i.to_string(),
            32,
            if native_wide {
              value
            } else {
              0UL
            },
          )
        }
      }
      r.set("ddr_response_last", 1, if last { 1UL } else { 0UL })
      if fault_prefetch && r.get("state") == 20UL {
        r.set("ddr_response_fault", 2, 2UL)
        injected = true
      }
    }
    r.sim.settle()
    if ready && r.get("ddr_request_valid") == 1UL {
      let address = r.get("ddr_request_address")
      if r.get("ddr_request_write") == 1UL {
        assert_true(address >= 0x8000UL && address < 0x8010UL)
        pending.push((0UL, true, false))
      } else if r.get("ddr_request_burst") == 1UL {
        assert_true(
          address == 0x1000UL ||
          address == 0x1080UL ||
          (
            parallel &&
            address >= 0x10000UL &&
            address < 0x10000UL + r.parallel_rows.to_uint64() * 256UL &&
            address % 128UL == 0UL
          ),
        )
        let native_wide = wide && r.get("ddr_request_wide") == 1UL
        let grouped = batch && native_wide
        let raw_beats = if grouped {
          if sixteen_row {
            128
          } else if eight_row {
            64
          } else {
            32
          }
        } else if native_wide {
          8
        } else {
          32
        }
        let beats = if r.delivery && native_wide {
          raw_beats / 2
        } else {
          raw_beats
        }
        for i in 0..<beats {
          pending.push(
            (
              if address >= 0x10000UL {
                let row = (if r.packed_weights && grouped {
                    (address - 0x10000UL) / 4096UL * 16UL
                  } else {
                    (address - 0x10000UL) / 256UL
                  }) +
                  (if grouped {
                    (i / (if r.delivery { 4 } else { 8 })).to_uint64()
                  } else {
                    0UL
                  })
                let x : Float = Float::from_int(row.to_int() + 1) / 8.0
                let half = x.reinterpret_as_uint() >> 16
                (half | (half << 16)).to_uint64()
              } else if address == 0x1000UL {
                0x3f803f80UL
              } else {
                0x40004000UL
              },
              i == beats - 1,
              native_wide,
            ),
          )
        }
      } else {
        assert_true(address == 0x4000UL || address == 0x4004UL)
        pending.push(
          (
            if address == 0x4000UL {
              0x40400000UL
            } else {
              0x40800000UL
            },
            true,
            false,
          ),
        )
      }
    }
    r.step()
    count += 1
    if injected {
      assert_eq(r.get("fault"), 1UL)
      assert_eq(r.get("error"), 4UL)
      r.set("ddr_response_valid", 1, 0UL)
      r.set("ddr_response_fault", 2, 0UL)
      for _ in 0..<32 {
        r.step()
        assert_eq(r.get("fault"), 1UL)
        assert_eq(r.get("ddr_request_valid"), 0UL)
      }
      return
    }
    if abort_drain && r.get("state") == 21UL {
      r.set("memory_healthy", 1, 0UL)
      r.step()
      assert_eq(r.get("fault"), 1UL)
      r.set("memory_healthy", 1, 1UL)
      r.set("ddr_response_valid", 1, 0UL)
      for _ in 0..<32 {
        r.step()
        assert_eq(r.get("fault"), 1UL)
        assert_eq(r.get("ddr_request_valid"), 0UL)
      }
      return
    }
  }
  assert_false(
    abort_drain || fault_prefetch,
    msg="requested fault campaign must actually inject and return",
  )
  assert_true(count < r.job_limit)
  assert_eq(r.get("done"), 1UL)
  assert_eq(r.get("fault"), 0UL)
  assert_eq(r.get("error"), 0UL)
  r.set("ddr_response_valid", 1, 0UL)
  r.set("scratch_read", 1, 1UL)
  for
    address in [
      256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269, 270,
      272, 273, 280, 281, 290, 291, 292, 293, 294, 296, 297,
    ] {
    r.set("scratch_read_address", 15, address.to_uint64())
    r.step()
    assert_eq(r.get("scratch_read_valid"), 1UL)
  }
  r.set("scratch_read", 1, 0UL)
  if parallel {
    r.set("scratch_read", 1, 1UL)
    for row in 0..<r.parallel_rows {
      r.set("scratch_read_address", 15, (512 + row).to_uint64())
      r.step()
      let mut expected : Float = 0.0
      for i in 0..<128 {
        let x : Float = if i == 100 { 2.0 } else { Float::from_int(i) / 64.0 }
        expected = expected + x * (Float::from_int(row + 1) / 8.0)
      }
      assert_eq(
        r.get("scratch_read_data"),
        expected.reinterpret_as_uint().to_uint64(),
      )
    }
    r.set("scratch_read", 1, 0UL)
  }
}

///|
fn replay_bundle(
  root : String,
  parallel~ : Bool = false,
  overlap~ : Bool = false,
  wide~ : Bool = false,
  batch~ : Bool = false,
  throughput~ : Bool = false,
  compute~ : Bool = false,
  eight_row~ : Bool = false,
  short_unary~ : Bool = false,
  sixteen_row~ : Bool = false,
  minimum_cycles~ : Int32 = 100000,
  packed_weights~ : Bool = false,
  feedback~ : Bool = false,
  delivery~ : Bool = false,
  interleaved~ : Bool = false,
) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh replay root") }
  @fs.create_dir(root)
  let hw = if interleaved {
    @fp.interleaved_layer_machine()
  } else if feedback {
    @fp.feedback_layer_machine(delivery~)
  } else if packed_weights {
    @fp.contiguous_layer_machine()
  } else if sixteen_row {
    @fp.sixteen_row_layer_machine()
  } else if short_unary {
    @fp.short_unary_layer_machine()
  } else if eight_row {
    @fp.eight_row_layer_machine()
  } else if compute {
    @fp.compute_layer_machine()
  } else if throughput {
    @fp.throughput_layer_machine()
  } else if batch {
    @fp.batched_layer_machine()
  } else if wide {
    @fp.wide_layer_machine()
  } else if overlap {
    @fp.overlapped_layer_machine()
  } else if parallel {
    @fp.parallel_layer_machine()
  } else {
    @fp.layer_machine()
  }
  let design = @ir.Design::single("qwen-layer-machine/v1", hw)
  let emitted = @sv.emit_design(design)
  let ports = @v.collect_ports(hw, emitted.manifest())
  let r : Replay = {
    hw,
    sim: @sim.Simulator::prepare(hw),
    inputs: @v.input_ports(ports),
    outputs: @v.output_ports(ports),
    stimulus: StringBuilder(),
    expected: StringBuilder(),
    masks: StringBuilder(),
    cycles: 0,
    random: 0x98132badU,
    // The registered scalar fallback is intentionally slower on n<16 jobs.
    // Only the workload timeout changes;all outputs/programs remain checked.
    job_limit: if throughput {
      20000
    } else {
      10000
    },
    packed_weights,
    delivery,
    parallel_rows: if compute || packed_weights {
      32
    } else if throughput {
      16
    } else {
      8
    },
  }
  r.stimulus.write_string(@v.tsv_header(r.inputs))
  r.expected.write_string(@v.tsv_header(r.outputs))
  r.masks.write_string(@v.tsv_header(r.outputs))
  for port in r.inputs {
    r.set(port.source_name(), port.width(), 0UL)
  }
  r.set("reset", 1, 1UL)
  r.step()
  r.set("reset", 1, 0UL)
  r.set("memory_healthy", 1, 1UL)
  r.set("scratch_write", 1, 1UL)
  for i in 0..<128 {
    r.set("scratch_address", 15, i.to_uint64())
    let x : Float = if i == 100 { 2.0 } else { Float::from_int(i) / 64.0 }
    r.set("scratch_data", 32, x.reinterpret_as_uint().to_uint64())
    r.step()
  }
  r.set("scratch_write", 1, 0UL)
  let p : LayerProgram = {
    words: [],
    traces: [],
    assets: [],
    weights: Map([]),
    constants: Map([]),
    out_root: root,
    trace_offset: 0x04000000U,
    constant_offset: 0x03000000U,
  }
  p.emit(1U, 256, 0, 4)
  p.emit(2U, 260, 0, 4, imm=2.0, flags=2U)
  p.emit(3U, 264, 0, 4, b=100, flags=1U)
  p.emit(6U, 268, 0, 4)
  p.emit(7U, 269, 0, 4)
  p.emit(8U, 270, 0, 4)
  p.emit(5U, 272, 0, 2, b=4, k=4, br=4)
  p.emit(4U, 280, 0, 2, k=64, ddr=0x1000U)
  p.emit(9U, 290, 100, 1)
  p.emit(10U, 291, 100, 1)
  p.emit(11U, 292, 0, 1)
  p.emit(12U, 293, 1, 1)
  p.emit(13U, 294, 1, 1, b=100)
  p.emit(14U, 296, 0, 2, ddr=0x4000U)
  p.emit(15U, 0, 256, 4, ddr=0x8000U)
  if parallel {
    p.emit(
      4U,
      512,
      0,
      r.parallel_rows,
      k=128,
      ddr=0x10000U,
      flags=if packed_weights { 1U } else { 0U },
    )
  }
  p.emit(0U, 0, 0, 0)
  r.set("program_write", 1, 1UL)
  for i, word in p.words {
    r.set("program_address", 15, i.to_uint64())
    r.set("program_data", 32, word.to_uint64())
    r.step()
  }
  r.set("program_write", 1, 0UL)
  r.set("program_count", 12, (p.words.length() / 16).to_uint64())
  let mut campaigns = 0
  while campaigns == 0 || r.cycles < minimum_cycles + 1 {
    r.execute(parallel~, wide~, batch~, eight_row~, sixteen_row~)
    campaigns += 1
  }
  if parallel {
    r.execute(
      parallel=true,
      abort_drain=true,
      wide~,
      batch~,
      eight_row~,
      sixteen_row~,
    )
    r.set("reset", 1, 1UL)
    r.step()
    r.set("reset", 1, 0UL)
    r.step()
    assert_eq(r.get("busy"), 0UL)
    assert_eq(r.get("fault"), 0UL)
    assert_eq(r.get("error"), 0UL)
  }
  if overlap {
    r.execute(
      parallel=true,
      fault_prefetch=true,
      wide~,
      batch~,
      eight_row~,
      sixteen_row~,
    )
    r.set("reset", 1, 1UL)
    r.step()
    r.set("reset", 1, 0UL)
    r.step()
    assert_eq(r.get("busy"), 0UL)
    assert_eq(r.get("fault"), 0UL)
  }
  if interleaved {
    interleaved_replay(r)
  }
  let stimulus = r.stimulus.to_string()
  let protocol = @v.ResultProtocol::checked(
    "LUNACHIP-QWEN-LAYER-RESULT", "1", "qwen-layer-machine/v1",
  )
  let identity = @diff.ResultIdentity::checked(
    @diff.DesignIdentity::checked(
      "qwen-layer-machine/v1",
      @v.sha256_hex(@codec.serialize(design)),
    ),
    @v.sha256_hex(stimulus),
  )
  save(root, "design.lcir", @codec.serialize(design))
  save(root, "manifest.json", core_replay_sources(root, emitted, ports))
  save(root, "harness.cpp", @v.harness_cpp(ports, identity, protocol))
  save(root, "stimulus.tsv", stimulus)
  save(
    root,
    "expected.tsv",
    protocol.magic() +
    "\t1\t" +
    @v.utf8_hex("qwen-layer-machine/v1") +
    "\tsha256\t" +
    identity.design().design_sha256() +
    "\tsha256\t" +
    identity.stimulus_sha256() +
    "\n" +
    r.expected.to_string(),
  )
  save(root, "care-masks.tsv", r.masks.to_string())
  save(root, "cycles.txt", (r.cycles - 1).to_string() + "\n")
  save(
    root,
    "scope.json",
    (
      {
        "status": "PASS",
        "cycles": r.cycles - 1,
        "campaigns": campaigns,
        "scope": "All16 opcodes,repeated complete programs,seeded DDR request/response stalls,local/DDR matrix arithmetic,all nonlinear operators and synchronous scratch/program access. Only uninitialized raw memory-read DATA when its corresponding valid=0 may be masked;all other outputs and every valid memory read must be fully known. Native simulation here does not run the full1024/3072 Qwen layer.",
      } : Json).stringify(indent=2) +
    "\n",
  )
}

///|
fn arithmetic_replay(root : String) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh arithmetic replay root") }
  @fs.create_dir(root)
  let hw = @fp.arithmetic_pipeline()
  let semantic = "qwen-fp32-arithmetic/v1"
  let design = @ir.Design::single(semantic, hw)
  let emitted = @sv.emit_design(design)
  let ports = @v.collect_ports(hw, emitted.manifest())
  let r : Replay = {
    hw,
    sim: @sim.Simulator::prepare(hw),
    inputs: @v.input_ports(ports),
    outputs: @v.output_ports(ports),
    stimulus: StringBuilder(),
    expected: StringBuilder(),
    masks: StringBuilder(),
    cycles: 0,
    random: 0x9b7ec412U,
    job_limit: 10000,
    parallel_rows: 8,
    packed_weights: false,
    delivery: false,
  }
  r.stimulus.write_string(@v.tsv_header(r.inputs))
  r.expected.write_string(@v.tsv_header(r.outputs))
  r.masks.write_string(@v.tsv_header(r.outputs))
  for port in r.inputs {
    r.set(port.source_name(), port.width(), 0UL)
  }
  r.set("reset", 1, 1UL)
  r.step()
  r.set("reset", 1, 0UL)
  let edges = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x3f800000U, 0xbf800000U, 0x33800000U,
    0x3f800001U, 0x7f7fffffU, 0xff7fffffU, 0x7f800000U, 0xff800000U, 0x7fc00000U,
  ]
  for i in 0..<100000 {
    r.random = r.random * 1664525U + 1013904223U
    let a = if i < edges.length() * edges.length() * 2 {
      edges[i / 2 / edges.length()]
    } else {
      r.random
    }
    r.random = r.random * 1664525U + 1013904223U
    let c = if i < edges.length() * edges.length() * 2 {
      edges[i / 2 % edges.length()]
    } else if i % 3 == 0 {
      a ^ 0x80000000U
    } else {
      r.random
    }
    let operation = i % 2
    r.set("a", 32, a.to_uint64())
    r.set("b", 32, c.to_uint64())
    r.set("operation", 1, operation.to_uint64())
    r.step()
    let x = Float::reinterpret_from_uint(a)
    let y = Float::reinterpret_from_uint(c)
    let expected = if operation == 0 { x * y } else { x + y }
    assert_eq(
      r.get("result"),
      if expected.is_nan() {
        0x7fc00000UL
      } else {
        expected.reinterpret_as_uint().to_uint64()
      },
    )
  }
  let stimulus = r.stimulus.to_string()
  let protocol = @v.ResultProtocol::checked(
    "LUNACHIP-QWEN-ALU-RESULT", "1", semantic,
  )
  let identity = @diff.ResultIdentity::checked(
    @diff.DesignIdentity::checked(
      semantic,
      @v.sha256_hex(@codec.serialize(design)),
    ),
    @v.sha256_hex(stimulus),
  )
  save(
    root,
    emitted.modules()[0].filename(),
    normalize(optimized(emitted.source())),
  )
  save(root, "design.lcir", @codec.serialize(design))
  save(root, "manifest.json", @v.harness_json(emitted, ports))
  save(root, "harness.cpp", @v.harness_cpp(ports, identity, protocol))
  save(root, "stimulus.tsv", stimulus)
  save(
    root,
    "expected.tsv",
    protocol.magic() +
    "\t1\t" +
    @v.utf8_hex(semantic) +
    "\tsha256\t" +
    identity.design().design_sha256() +
    "\tsha256\t" +
    identity.stimulus_sha256() +
    "\n" +
    r.expected.to_string(),
  )
  save(root, "care-masks.tsv", r.masks.to_string())
  save(root, "cycles.txt", (r.cycles - 1).to_string() + "\n")
  save(
    root,
    "scope.json",
    (
      {
        "status": "PASS",
        "cycles": 100000,
        "scope": "100000 boundary/seeded raw-bit FP32 add/multiply edges,including cancellation,subnormals,infinities and canonicalNaNs. Every output bit known and also independently checked against native FP32. Exact same arithmetic generator functions as complete-layer machine.",
      } : Json).stringify(indent=2) +
    "\n",
  )
}

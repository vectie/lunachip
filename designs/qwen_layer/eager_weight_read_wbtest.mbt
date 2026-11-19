///|
// Exercise the production 64-bank network, including its actual row rotation,
// synchronous ReadOld ports and registered half-word/valid selectors.
fn eager_weight_fixture(eager_weight_reads : Bool) -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("weight_read_fixture")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  let m : Machine = {
    b,
    d,
    rs,
    reset: b.synchronous_reset(rs, 0UL),
    regs: Map([]),
    next: Map([]),
    order: [],
    row_lanes: 64,
    lane_width: 9,
    fast_arithmetic: true,
    short_unary: true,
    bf16_weights: true,
    packed_weights: true,
    feedback: true,
    delivery: true,
    wide512: true,
    banked64: true,
    prefetch256: true,
    interleaved: true,
    stream_unary: true,
    staged_decode: true,
    stream_reductions: true,
    paired_rows: true,
    full_rows: true,
    dual_read: true,
    indirect_bf16: true,
    bounded_add: true,
    deep_batch: true,
    strided_rows: true,
    group64_rows: true,
    stripe512: true,
    prefetch_row_blocks: true,
    staged_unary_inputs: true,
    staged_reduction_term: true,
    staged_scalar_add: true,
    staged_scalar_alignment: true,
    deep_fp32_add: true,
    compact_multiply_pack: true,
    staged_multiply_product: true,
    incremental_row_address: true,
    registered_multiply_inputs: true,
    eager_weight_reads,
    ordered_array: true,
    pipelined_vectors: true,
    memory: GiB2,
  }
  for
    (name, width) in [
      ("state", 5),
      ("p_lane", 9),
      ("p_index", 10),
      ("o_active", 1),
      ("ordered_slot", 3),
      ("o_bank", 1),
      ("packet_in_row", 3),
    ] {
    let state = m.reg(name, width)
    m.next[name] = b.input(name, state.signal_type())
  }
  let issue = all(b, [
    b.bit_not(b.reset_asserted(rs)),
    m.is_state(20UL),
    b.input("healthy", @wire.bits(1)),
    b.input("credit", @wire.bits(1)),
    b.bit_not(b.input("bad", @wire.bits(1))),
  ])
  let inputs : Map[String, @wire.Signal] = Map([])
  for i in 0..<32 {
    let name = "ddr_response_data" + (if i == 0 { "" } else { i.to_string() })
    inputs[name] = b.input(name, @wire.uint(32))
  }
  let words = banked_weights(
    m,
    inputs,
    b.input("accept", @wire.bits(1)),
    issue,
    b.register_in(d, bit(b, m.v("p_index"), 0), reset=m.reset),
  )
  for i, word in words {
    b.connect(b.output("weight" + i.to_string(), word.signal_type()), word)
  }
  let valid = b.register_in(d, issue, reset=m.reset)
  b.connect(b.output("valid", valid.signal_type()), valid)
  m.commit()
  b.finish()
}

///|
test "eager weight reads preserve valid words across stalls bank swaps collisions and reset" {
  let modules = [false, true].map(eager_weight_fixture)
  let units = modules.map(m => @sim.Simulator::prepare(m))
  fn put(name : String, width : Int32, value : UInt64) -> Unit raise {
    for s in units {
      s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
    }
  }
  for node in modules[0].nodes() {
    if node.kind() is Input(name) {
      put(name, node.signal_type().width().bits(), 0UL)
    }
  }
  fn edge() -> Unit raise {
    for s in units {
      s.rising_edge("clock")
    }
  }
  put("reset", 1, 1UL)
  edge()
  put("reset", 1, 0UL)
  // Populate every address in both banks and all eight slots/segments before
  // checking fully-known valid data. Controls are registered in this fixture.
  put("accept", 1, 1UL)
  for index in 0..<8194 {
    let i = if index < 8192 { index } else { 8191 }
    put("o_bank", 1, (i / 4096).to_uint64())
    put("p_lane", 9, (i / 512 % 8 * 64 + i % 64).to_uint64())
    put("packet_in_row", 3, (i / 64 % 8).to_uint64())
    for j in 0..<32 {
      put(
        "ddr_response_data" + (if j == 0 { "" } else { j.to_string() }),
        32,
        (i * 65537 + j * 1027 + 1).to_uint64(),
      )
    }
    edge()
  }
  let mut seed = 23U
  let mut valid_edges = 0
  let mut invalid_differences = 0
  let mut collisions = 0
  for tick in 0..<4096 {
    seed = seed * 1664525U + 1013904223U
    let index = (seed >> 5) & 511U
    let slot = (seed >> 14) & 7U
    let bank = (seed >> 18) & 1U
    let collide = tick % 3 == 0
    if collide {
      collisions += 1
    }
    put("reset", 1, if tick % 257 == 0 { 1UL } else { 0UL })
    put("state", 5, if tick % 11 == 0 { 21UL } else { 20UL })
    put("healthy", 1, if tick % 17 == 0 { 0UL } else { 1UL })
    put("credit", 1, if tick % 7 < 3 { 0UL } else { 1UL })
    put("bad", 1, if tick % 19 == 0 { 1UL } else { 0UL })
    put("o_active", 1, bank.to_uint64())
    put("ordered_slot", 3, slot.to_uint64())
    put("p_index", 10, index.to_uint64())
    put("o_bank", 1, (if collide { bank } else { bank ^ 1U }).to_uint64())
    put("p_lane", 9, ((slot << 6) | ((seed >> 20) & 63U)).to_uint64())
    put("packet_in_row", 3, (index >> 6).to_uint64())
    put("accept", 1, if tick % 5 == 0 { 0UL } else { 1UL })
    for j in 0..<32 {
      put(
        "ddr_response_data" + (if j == 0 { "" } else { j.to_string() }),
        32,
        (seed ^ (j.reinterpret_as_uint() * 2654435761U)).to_uint64(),
      )
    }
    edge()
    assert_eq(units[0].output("valid"), units[1].output("valid"))
    if units[0].output("valid").value_bits() == 1UL {
      valid_edges += 1
      for lane in 0..<64 {
        let port = "weight" + lane.to_string()
        let reference = units[0].output(port)
        assert_true(reference.is_fully_known(), msg="uninitialized weight")
        assert_eq(
          units[1].output(port),
          reference,
          msg="tick=\{tick} lane=\{lane}",
        )
      }
    } else if units[0].output("weight0") != units[1].output("weight0") {
      invalid_differences += 1
    }
  }
  assert_true(valid_edges > 1500)
  assert_true(invalid_differences > 100)
  assert_true(collisions > 1000)
}

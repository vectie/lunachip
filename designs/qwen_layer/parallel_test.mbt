///|
test "three-edge FP32 pipeline accepts raw-bit operands every edge" {
  for fast in [false, true] {
    let s = @sim.Simulator::prepare(@qwen_layer.pipelined_multiplier(fast~))
    fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
      s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
    }
    set("clock", 1, 0UL)
    set("reset", 1, 1UL)
    set("a", 32, 0UL)
    set("b", 32, 0UL)
    s.rising_edge("clock")
    set("reset", 1, 0UL)
    let edges = [
      0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x3f800000U, 0xbf800000U, 0x7f7fffffU,
      0x7f800000U, 0xff800000U, 0x7fc00000U,
    ]
    let pending : Array[UInt32] = []
    let mut seed = 0x6314de7bU
    for i in 0..<10002 {
      seed = seed * 1664525U + 1013904223U
      let a = if i < edges.length() * edges.length() {
        edges[i / edges.length()]
      } else {
        seed
      }
      seed = seed * 1664525U + 1013904223U
      let c = if i < edges.length() * edges.length() {
        edges[i % edges.length()]
      } else {
        seed
      }
      let expected = Float::reinterpret_from_uint(a) *
        Float::reinterpret_from_uint(c)
      pending.push(
        if expected.is_nan() {
          0x7fc00000U
        } else {
          expected.reinterpret_as_uint()
        },
      )
      set("a", 32, a.to_uint64())
      set("b", 32, c.to_uint64())
      s.rising_edge("clock")
      if pending.length() > 2 {
        let out = s.output("result")
        assert_true(out.is_fully_known())
        assert_eq(out.value_bits().to_uint(), pending.remove(0))
      }
    }
  }
}

///|
fn parallel_weight(row : Int32, col : Int32) -> Float {
  Float::from_int((row * 13 + col * 7) % 17 - 8) / 16.0
}

///|
fn parallel_case(
  n : Int32,
  k : Int32,
  fault~ : Int32 = 0,
  fault_response~ : Int32 = -1,
  dst~ : Int32 = 1024,
  reset_mid~ : Bool = false,
  overlap~ : Bool = false,
  wide~ : Bool = false,
  batch~ : Bool = false,
  throughput~ : Bool = false,
  compute~ : Bool = false,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
  packed_weights~ : Bool = false,
  packed_flag~ : Bool = true,
  feedback~ : Bool = false,
  delivery~ : Bool = false,
  wide512~ : Bool = false,
  rows64~ : Bool = false,
  banked64~ : Bool = false,
  prefetch256~ : Bool = false,
  memory~ : @qwen_layer.MemoryAperture = MiB256,
  ddr_base~ : UInt32 = 0x10000U,
  cycle_limit~ : Int32 = 20000,
) -> Unit raise {
  let hw = if wide512 {
    @qwen_layer.interleaved_layer_machine(
      wide512=true,
      rows64~,
      banked64~,
      prefetch256~,
      pipelined_vectors=true,
      memory~,
    )
  } else if feedback {
    @qwen_layer.feedback_layer_machine(delivery~, memory~)
  } else if packed_weights {
    @qwen_layer.contiguous_layer_machine(memory~)
  } else if sixteen_row {
    @qwen_layer.sixteen_row_layer_machine(memory~)
  } else if eight_row {
    @qwen_layer.eight_row_layer_machine(memory~)
  } else if compute {
    @qwen_layer.compute_layer_machine(memory~)
  } else if throughput {
    @qwen_layer.throughput_layer_machine(memory~)
  } else if batch {
    @qwen_layer.batched_layer_machine(memory~)
  } else if wide {
    @qwen_layer.wide_layer_machine(memory~)
  } else if overlap {
    @qwen_layer.overlapped_layer_machine(memory~)
  } else {
    @qwen_layer.parallel_layer_machine(memory~)
  }
  let s = @sim.Simulator::prepare(hw)
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn get(name : String) -> UInt64 raise {
    let x = s.output(name)
    assert_true(x.is_fully_known())
    x.value_bits()
  }
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      set(name, node.signal_type().width().bits(), 0UL)
    }
  }
  set("reset", 1, 1UL)
  s.rising_edge("clock")
  set("reset", 1, 0UL)
  set("memory_healthy", 1, 1UL)
  set("scratch_write", 1, 1UL)
  let activations : Array[Float] = []
  for i in 0..<k {
    let a = Float::from_int(i * 11 % 23 - 11) / 32.0
    activations.push(a)
    set("scratch_address", 15, i.to_uint64())
    set("scratch_data", 32, a.reinterpret_as_uint().to_uint64())
    s.rising_edge("clock")
  }
  set("scratch_write", 1, 0UL)
  let program : Array[Array[UInt32]] = []
  emit(
    program,
    4U,
    dst.reinterpret_as_uint(),
    0U,
    0U,
    n.reinterpret_as_uint(),
    k=k.reinterpret_as_uint(),
    ddr=ddr_base,
    flags=if packed_weights && packed_flag { 1U } else { 0U },
  )
  emit(program, 0U, 0U, 0U, 0U, 0U)
  set("program_write", 1, 1UL)
  for i, row in program {
    for j, x in row {
      set("program_address", 15, (i * 16 + j).to_uint64())
      set("program_data", 32, x.to_uint64())
      s.rising_edge("clock")
    }
  }
  set("program_write", 1, 0UL)
  set("program_count", 12, 2UL)
  let mut seed = 0x9d71a63bU
  let packed = packed_weights && packed_flag
  let stripe_columns = if prefetch256 &&
    !packed &&
    k % 256 == 0 &&
    ddr_base % 512U == 0U {
    256
  } else {
    64
  }
  let weight_memory = Array::make(n * k, 0U)
  for row in 0..<n {
    for col in 0..<k {
      let address = if packed {
        row / 16 * (16 * k) + col / 64 * 1024 + row % 16 * 64 + col % 64
      } else {
        row * k + col
      }
      weight_memory[address] = parallel_weight(row, col).reinterpret_as_uint() >>
        16
    }
  }
  for run in 0..<(if fault == 0 { 2 } else { 1 }) {
    set("start", 1, 1UL)
    s.rising_edge("clock")
    set("start", 1, 0UL)
    let pending : Array[(Array[UInt64], Bool)] = []
    let mut cycles = 0
    let mut responses = 0
    let mut requests = 0
    let mut early_group_requests = 0
    let mut reset_done = false
    let mut issues = 0
    let mut overlap_edges = 0
    let states : Map[UInt64, Int32] = Map([])
    let mut held : UInt64? = None
    while get("busy") == 1UL && cycles < cycle_limit {
      seed = seed * 1664525U + 1013904223U
      let ready = pending.is_empty() && (seed & 3U) != 0U
      set("ddr_request_ready", 1, if ready { 1UL } else { 0UL })
      set("ddr_response_valid", 1, 0UL)
      let delivered = !pending.is_empty() && (seed & 4U) != 0U
      if !pending.is_empty() && (seed & 4U) != 0U {
        let (data, last) = pending.remove(0)
        set("ddr_response_valid", 1, 1UL)
        set("ddr_response_data", 32, data[0])
        if wide {
          for
            i in 1..<(if prefetch256 {
              32
            } else if wide512 {
              16
            } else if delivery {
              8
            } else {
              4
            }) {
            set(
              "ddr_response_data" + i.to_string(),
              32,
              if i < data.length() {
                data[i]
              } else {
                0UL
              },
            )
          }
        }
        set(
          "ddr_response_last",
          1,
          if last ||
            (
              (fault == 2 || fault == 5) &&
              responses ==
              (if fault == 5 {
                if fault_response >= 0 {
                  fault_response
                } else if wide {
                  35
                } else {
                  135
                }
              } else {
                1
              })
            ) {
            1UL
          } else {
            0UL
          },
        )
        set(
          "ddr_response_fault",
          2,
          if (fault == 1 || fault == 4) &&
            responses ==
            (if fault == 4 {
              if fault_response >= 0 {
                fault_response
              } else if wide {
                35
              } else {
                135
              }
            } else {
              1
            }) {
            2UL
          } else {
            0UL
          },
        )
        responses += 1
      }
      s.settle()
      if get("state") == 20UL && delivered {
        overlap_edges += 1
      }
      if get("ddr_request_valid") == 1UL {
        let address = get("ddr_request_address")
        if held is Some(previous) {
          assert_eq(address, previous)
        }
        held = if ready { None } else { Some(address) }
        assert_eq(get("ddr_request_write"), 0UL)
        assert_eq(get("ddr_request_burst"), 1UL)
        assert_true(
          address >= ddr_base.to_uint64() &&
          address < ddr_base.to_uint64() + (n * k * 2).to_uint64(),
        )
        if ready {
          let first = ((address - ddr_base.to_uint64()) / 2UL).to_int()
          requests += 1
          if packed && first > 0 && first % (16 * k) == 0 {
            assert_true([20UL, 21UL, 22UL, 23UL].contains(get("state")))
            early_group_requests += 1
          }
          let grouped = batch && get("ddr_request_wide") == 1UL
          if grouped {
            assert_eq(
              get("ddr_request_data"),
              (if stripe_columns == 256 { 0xc0000000UL } else { 0x80000000UL }) +
              (if packed { 128 } else { k * 2 }).to_uint64(),
            )
          }
          let count = if wide && get("ddr_request_wide") == 1UL {
            if prefetch256 {
              32
            } else if wide512 {
              16
            } else if delivery {
              8
            } else {
              4
            }
          } else {
            1
          }
          let words = if grouped {
            if sixteen_row {
              16 * stripe_columns / 2
            } else if eight_row {
              256
            } else {
              128
            }
          } else {
            32
          }
          for beat in 0..<(words / count) {
            let data = Array::makei(count, w => {
              let address = first +
                (if grouped {
                  beat /
                  ((if grouped { stripe_columns / 2 } else { 32 }) / count) *
                  (if packed { 64 } else { k })
                } else {
                  0
                }) +
                (
                  beat %
                  ((if grouped { stripe_columns / 2 } else { 32 }) / count) *
                  count +
                  w
                ) *
                2
              let low = weight_memory[address]
              let high = weight_memory[address + 1]
              (low | (high << 16)).to_uint64()
            })
            pending.push((data, beat == words / count - 1))
          }
        }
      }
      let before = get("state")
      states[before] = states.get(before).unwrap_or(0) + 1
      s.rising_edge("clock")
      cycles += 1
      if fault == 3 && get("state") == 21UL {
        set("memory_healthy", 1, 0UL)
        s.rising_edge("clock")
        assert_eq(get("fault"), 1UL)
        set("memory_healthy", 1, 1UL)
        set("ddr_response_valid", 1, 0UL)
        for _ in 0..<8 {
          s.rising_edge("clock")
          assert_eq(get("fault"), 1UL)
          assert_eq(get("ddr_request_valid"), 0UL)
        }
        break
      }
      if get("state") == 20UL {
        issues += 1
      }
      if reset_mid && !reset_done && issues == 3 {
        set("reset", 1, 1UL)
        s.rising_edge("clock")
        assert_eq(get("busy"), 0UL)
        assert_eq(get("fault"), 0UL)
        assert_eq(get("error"), 0UL)
        set("reset", 1, 0UL)
        set("ddr_response_valid", 1, 0UL)
        pending.clear()
        set("start", 1, 1UL)
        s.rising_edge("clock")
        set("start", 1, 0UL)
        held = None
        reset_done = true
      }
    }
    assert_true(cycles < cycle_limit)
    if fault != 0 {
      assert_eq(get("fault"), 1UL)
      assert_eq(get("error"), if fault == 3 { 8UL } else { 4UL })
      for _ in 0..<8 {
        s.rising_edge("clock")
        assert_eq(get("ddr_request_valid"), 0UL)
        assert_eq(get("fault"), 1UL)
      }
    } else {
      if batch &&
        n % (if compute { 32 } else if throughput { 16 } else { 4 }) == 0 &&
        dst >= k &&
        !reset_mid {
        assert_eq(
          requests,
          n *
          k /
          (if sixteen_row {
            16 * stripe_columns
          } else if eight_row {
            512
          } else {
            256
          }),
        )
      }
      assert_eq(get("done"), 1UL)
      assert_eq(get("error"), 0UL)
      assert_eq(get("products"), (n * k).to_uint64())
      assert_eq(get("ddr_beats"), (n * k / 2).to_uint64())
      if packed && !reset_mid {
        assert_eq(early_group_requests, n / 16 - 1)
      }
      // Independently count every pre-edge state in the simulated hardware.
      // This validates residual stall attribution from physical total cycles:
      // 67 fetch/decode/retire edges, 134 fixed edges per K64/row-lane stripe,
      // n result writes, and the remaining edges waiting for a full stripe.
      if throughput &&
        overlap &&
        !reset_mid &&
        dst >= k &&
        n % (if compute { 32 } else { 16 }) == 0 {
        let rows = if wide512 {
          if packed || n % 32 != 0 {
            16
          } else if rows64 && n % 64 == 0 {
            64
          } else {
            32
          }
        } else if compute {
          32
        } else {
          16
        }
        let stripes = n * k / (stripe_columns * rows)
        assert_eq(
          states[20UL],
          (if feedback { stripe_columns } else { 127 }) * stripes,
        )
        assert_eq(states[21UL], (if feedback { 4 } else { 5 }) * stripes)
        assert_eq(states[22UL], stripes)
        assert_eq(states[23UL], n)
        let waiting = states[18UL] - stripes
        assert_true(waiting >= 0)
        assert_eq(
          cycles,
          67 +
          (if feedback { stripe_columns + 6 } else { 134 }) * stripes +
          n +
          waiting,
        )
        assert_eq(get("cycles_low"), cycles.to_uint64())
      }
      if overlap &&
        n % (if compute { 32 } else if throughput { 16 } else { 4 }) == 0 &&
        (k > stripe_columns || (prefetch256 && n > 64)) &&
        dst >= k {
        assert_true(overlap_edges > 0)
      }
      set("ddr_response_valid", 1, 0UL)
      set("scratch_read", 1, 1UL)
      for row in 0..<n {
        let mut expected : Float = 0.0
        for col in 0..<k {
          expected = expected + activations[col] * parallel_weight(row, col)
        }
        set("scratch_read_address", 15, (dst + row).to_uint64())
        s.rising_edge("clock")
        assert_eq(
          get("scratch_read_data"),
          expected.reinterpret_as_uint().to_uint64(),
          msg="matrix n=\{n} k=\{k} dst=\{dst} row=\{row}",
        )
        if dst + row < k {
          activations[dst + row] = expected
        }
      }
      set("scratch_read", 1, 0UL)
      if run == 0 {
        assert_eq(get("instructions"), 1UL)
      }
    }
  }
}

///|
test "wide DDR fills all subword banks with exact ordered FP32 sums and fallback" {
  parallel_case(8, 192, overlap=true, wide=true)
  parallel_case(4, 128, overlap=true, wide=true, reset_mid=true)
  parallel_case(4, 64, overlap=true, wide=true)
  parallel_case(3, 64, overlap=true, wide=true)
  parallel_case(4, 64, dst=0, overlap=true, wide=true)
}

///|
test "wide DDR rejects response faults early LAST and lost health without resurrection" {
  for fault in 1..<=5 {
    parallel_case(4, 128, overlap=true, wide=true, fault~)
  }
}

///|
test "four lanes preserve ordered sums across stripes rows stalls and warm starts" {
  parallel_case(8, 192)
  parallel_case(3, 64)
  parallel_case(4, 64, dst=0)
  parallel_case(4, 64, reset_mid=true)
}

///|
test "parallel weight response errors and malformed LAST fault without requests" {
  parallel_case(4, 64, fault=1)
  parallel_case(4, 64, fault=2)
  parallel_case(4, 64, fault=3)
}

///|
test "ping-pong DDR overlaps ordered four-lane compute and invalidates on reset" {
  parallel_case(8, 192, overlap=true)
  parallel_case(4, 128, overlap=true, reset_mid=true)
  parallel_case(4, 64, overlap=true)
  parallel_case(3, 64, overlap=true)
  parallel_case(4, 64, dst=0, overlap=true)
}

///|
test "overlapped loader faults and compute-drain health faults remain sticky" {
  parallel_case(4, 128, overlap=true, fault=1)
  parallel_case(4, 128, overlap=true, fault=2)
  parallel_case(4, 128, overlap=true, fault=3)
  parallel_case(4, 128, overlap=true, fault=4)
  parallel_case(4, 128, overlap=true, fault=5)
}

///|
fn canonical_float(x : Float) -> UInt32 {
  if x.is_nan() {
    0x7fc00000U
  } else {
    x.reinterpret_as_uint()
  }
}

///|
fn ordered_mac_replay(root : String) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh MAC replay directory") }
  @fs.create_dir(root)
  let hw = @fp.ordered_bf16_mac_lane()
  let taps = [0, 17, 63]
  let simulators = taps.map(_ => @sim.Simulator::prepare(hw))
  let slots = @fp.ORDERED_MAC_ROW_SLOTS
  let delay = @fp.ORDERED_MAC_EDGES
  let sums = Array::make(slots * 64, 0U)
  let history : Array[Array[UInt32]] = []
  let marks : Array[Bool] = []
  let txt = StringBuilder()
  let mut seed = 0xc19f73abU
  let mut accepted = 0
  let mut checks = 0
  let mut last_reset = 0
  // The first 1024 uninterrupted inputs traverse every BF16 bit pattern.
  for i in 0..<4096 {
    seed = seed * 1664525U + 1013904223U
    let reset = i == 0 || i == 1322 || i == 1323 || i == 2705
    let valid = i > 0 && (i <= 1024 || seed >> 28 > 2U)
    let first = i <= slots ||
      (i / slots % 11 == 0 && i > 1024) ||
      (i > 2705 && i <= 2705 + slots)
    let a = if i <= 1024 {
      (seed & 0x807fffffU) | ((i % 254 + 1).reinterpret_as_uint() << 23)
    } else if i >= 1700 && i < 1800 {
      [
        0U, 0x80000000U, 1U, 0x7fffffU, 0x00800000U, 0x3f800000U, 0xbf800000U, 0x7f7fffffU,
        0x7f800000U, 0xff800000U, 0x7fc00000U,
      ][i % 11]
    } else if i % 5 == 0 {
      seed
    } else {
      (seed & 0x807fffffU) | 0x3f000000U
    }
    if reset {
      sums.fill(0U)
      last_reset = i
    }
    let weights : Array[UInt32] = []
    let outputs : Array[UInt32] = []
    for lane in 0..<64 {
      let raw = ((i - 1) * 64 + lane).reinterpret_as_uint()
      let w = if i <= 1024 {
        (raw * 40503U + 17U) & 0xffffU
      } else if i >= 1700 && i < 1800 {
        [
          0U, 0x8000U, 1U, 0x7fU, 0x80U, 0x3f80U, 0xbf80U, 0x7f7fU, 0x7f80U, 0xff80U,
          0x7fc1U,
        ][(i + lane) % 11]
      } else {
        ((seed >> 16) + lane.reinterpret_as_uint() * 1031U) & 0xffffU
      }
      weights.push(w)
      let slot = i % slots * 64 + lane
      if valid && !reset {
        let prior = if first { 0U } else { sums[slot] }
        let rounded_product = canonical_float(
          Float::reinterpret_from_uint(a) *
          Float::reinterpret_from_uint(w << 16),
        )
        sums[slot] = canonical_float(
          Float::reinterpret_from_uint(prior) +
          Float::reinterpret_from_uint(rounded_product),
        )
      }
      outputs.push(sums[slot])
    }
    history.push(outputs)
    marks.push(valid && !reset)
    if valid && !reset {
      accepted += 1
    }
    let at = i - delay + 1
    let retire = at > last_reset && at >= 0 && marks[at]
    for j, lane in taps {
      let sim = simulators[j]
      for
        (name, width, v) in [
          ("clock", 1, 0UL),
          ("reset", 1, if reset { 1UL } else { 0UL }),
          ("valid", 1, if valid { 1UL } else { 0UL }),
          ("first", 1, if first { 1UL } else { 0UL }),
          ("activation", 32, a.to_uint64()),
          ("weight", 16, weights[lane].to_uint64()),
        ] {
        sim.set_input(name, @wave.LogicValue::from_uint64(width~, value=v))
      }
      sim.rising_edge("clock")
      let tagged = sim.output("result_valid")
      assert_true(tagged.is_fully_known())
      assert_eq(
        tagged.value_bits(),
        if retire {
          1UL
        } else {
          0UL
        },
        msg="valid edge \{i}",
      )
      if retire {
        let value = sim.output("result")
        assert_true(value.is_fully_known())
        assert_eq(
          value.value_bits(),
          history[at][lane].to_uint64(),
          msg="lane \{lane} output edge \{i}, accepted at \{at}",
        )
      }
    }
    if retire {
      checks += 64
    }
    txt.write_string(if reset { "1" } else { "0" })
    txt.write_string(if first { "1" } else { "0" })
    txt.write_string(if valid { "1" } else { "0" })
    txt.write_string(if retire { "1" } else { "0" })
    txt.write_string(@v.padded_hex(a.to_uint64(), 32))
    for k in 0..<64 {
      txt.write_string(@v.padded_hex(weights[63 - k].to_uint64(), 16))
    }
    for k in 0..<64 {
      txt.write_string(
        @v.padded_hex(
          if retire {
            history[at][63 - k].to_uint64()
          } else {
            0UL
          },
          32,
        ),
      )
    }
    txt.write_string("\n")
  }
  save(root, "vectors.hex", txt.to_string())
  let tb =
    #|module replay;
    #|  bit clock;
    #|  logic reset,first,valid,wanted;
    #|  logic [31:0] activation;
    #|  logic [1023:0] weights;
    #|  wire [2047:0] sums;
    #|  logic [2047:0] expected;
    #|  wire result_valid;
    #|  logic [3119:0] vectors[0:4095];
    #|  int checked;
    #|  mac_array dut(.*);
    #|  initial begin
    #|    $readmemh("vectors.hex",vectors);
    #|    for(int i=0;i<4096;i++) begin
    #|      {reset,first,valid,wanted,activation,weights,expected}= {vectors[i][3116],vectors[i][3112],vectors[i][3108],vectors[i][3104],vectors[i][3103:0]};
    #|      #1; clock=1; #1;
    #|      if (result_valid !== wanted || (wanted && sums !== expected)) $fatal(1,"array mismatch at %0d",i);
    #|      if (wanted) checked+=64;
    #|      clock=0; #1;
    #|    end
    #|    $display("PASS 64 lanes, %0d bit-exact FP32 sums",checked); $finish;
    #|  end
    #|endmodule
  save(root, "replay.sv", tb)
  save(
    root,
    "result.txt",
    "4096 edges; \{accepted} accepted waves; \{checks} checked lane sums; LunaWave taps 0,17,63; reset flush; 65536 BF16 encodings\n",
  )
}

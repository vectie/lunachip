///|
fn significand_replay(root : String) -> Unit raise {
  guard !@fs.path_exists(root) else {
    fail("fresh significand replay directory")
  }
  @fs.create_dir(root)
  let sim = @sim.Simulator::prepare(@fp.significand_product_pipeline())
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    sim.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  set("clock", 1, 0UL)
  let mut seed = 0x91a3c94dU
  let products : Array[UInt64] = []
  let vectors = StringBuilder()
  for i in 0..<8204 {
    seed = seed * 1664525U + 1013904223U
    let a = if i % 41 == 0 { 0xffffffUL } else { (seed >> 8).to_uint64() }
    let w = (i % 256).to_uint64()
    products.push(a * w)
    set("activation", 24, a)
    set("weight", 8, w)
    sim.rising_edge("clock")
    let expected = if i >= 12 {
      let actual = sim.output("result")
      assert_true(actual.is_fully_known())
      assert_eq(actual.value_bits(), products[i - 12])
      actual.value_bits()
    } else {
      0UL
    }
    vectors.write_string(
      @v.padded_hex((a << 40) | (w << 32) | expected, 64) + "\n",
    )
  }
  save(root, "vectors.hex", vectors.to_string())
  let tb =
    #|module replay;
    #|  bit clock;
    #|  logic [23:0] activation;
    #|  logic [7:0] weight;
    #|  wire [31:0] result;
    #|  logic [63:0] vectors [0:8203];
    #|  lane dut(.*);
    #|  initial begin
    #|    $readmemh("vectors.hex", vectors);
    #|    for (int i=0; i<8204; i++) begin
    #|      {activation, weight} = vectors[i][63:32];
    #|      #1; clock = 1; #1;
    #|      if (i >= 12 && result !== vectors[i][31:0]) $fatal(1,"product mismatch at %0d", i);
    #|      clock = 0; #1;
    #|    end
    #|    $display("PASS: 8192 consecutive LunaWave products matched"); $finish;
    #|  end
    #|endmodule
  save(root, "replay.sv", tb)
}

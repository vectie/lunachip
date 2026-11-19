///|
test "sixteen-row controller keeps ownership through packet127 and rejects premature last" {
  for delivery in [false, true] {
    for early in [false, true] {
      let hw = if delivery {
        @prx100_layer.delivery_controller()
      } else {
        @prx100_layer.sixteen_row_controller()
      }
      let packets = if delivery { 64 } else { 128 }
      let s = @sim.Simulator::prepare(hw)
      for node in hw.nodes() {
        if node.kind() is Input(name) {
          s.set_input(
            name,
            @wave.LogicValue::from_uint64(
              width=node.signal_type().width().bits(),
              value=0UL,
            ),
          )
        }
      }
      fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
        s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
      }
      fn get(name : String) -> UInt64 raise {
        let v = s.output(name)
        assert_true(v.is_fully_known())
        v.value_bits()
      }
      set("reset", 1, 1UL)
      s.rising_edge("clock")
      set("reset", 1, 0UL)
      set("memory_healthy", 1, 1UL)
      set("c_ddr_request_valid", 1, 1UL)
      set("c_ddr_request_line", 1, 1UL)
      set("c_ddr_request_burst", 1, 1UL)
      set("c_ddr_request_wide", 1, 1UL)
      set("c_ddr_request_data", 32, 0x80000100UL)
      s.rising_edge("clock")
      set("c_ddr_request_valid", 1, 0UL)
      set("ddr_request_ready", 1, 1UL)
      s.rising_edge("clock")
      set("ddr_request_ready", 1, 0UL)
      for i in 0..<packets {
        for lane in 0..<(if delivery { 8 } else { 4 }) {
          set(
            if lane == 0 {
              "ddr_response_data"
            } else {
              "ddr_response_data" + lane.to_string()
            },
            32,
            (i * 16 + lane).to_uint64(),
          )
        }
        set("ddr_response_valid", 1, 1UL)
        set(
          "ddr_response_last",
          1,
          if i == (if early { packets / 2 - 1 } else { packets - 1 }) {
            1UL
          } else {
            0UL
          },
        )
        s.settle()
        for lane in 0..<(if delivery { 8 } else { 4 }) {
          assert_eq(
            get(
              "ddr_response_data" +
              (if lane == 0 { "" } else { lane.to_string() }) +
              "_to_core",
            ),
            (i * 16 + lane).to_uint64(),
          )
        }
        if !early || i < packets / 2 - 1 {
          assert_eq(get("memory_healthy_to_core"), 1UL)
        }
        s.rising_edge("clock")
        if early && i == packets / 2 - 1 {
          assert_eq(get("memory_healthy_to_core"), 0UL)
          break
        }
      }
      set("ddr_response_valid", 1, 0UL)
      set("ddr_response_last", 1, 0UL)
      s.rising_edge("clock")
      assert_eq(get("memory_healthy_to_core"), if early { 0UL } else { 1UL })
    }
  }
}

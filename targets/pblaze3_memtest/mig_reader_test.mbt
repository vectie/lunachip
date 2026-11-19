///|
test "MIG reader counts accepted beats and holds ordered burst addresses across stalls" {
  for mode in 0..<4 {
    let sim = @sim.Simulator::prepare(@pblaze3_memtest.mig_reader(log_beats=12))
    fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
      sim.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
    }
    fn get(name : String) -> UInt64 raise {
      let v = sim.output(name)
      assert_true(v.is_fully_known())
      v.value_bits()
    }
    set("clock", 1, 0UL)
    set("mode", 2, mode.to_uint64())
    set("calibrated", 1, 1UL)
    set("sample", 32, 0UL)
    set("rid", 1, 0UL)
    set("rresp", 2, 0UL)
    set("reset", 1, 1UL)
    for name in ["start", "arready", "rvalid", "rlast"] {
      set(name, 1, 0UL)
    }
    sim.rising_edge("clock")
    set("reset", 1, 0UL)
    set("start", 1, 1UL)
    sim.rising_edge("clock")
    set("start", 1, 0UL)
    let len = if mode == 1 { 64 } else { 8 }
    let stripes = if mode == 2 { 2 } else { 3 }
    let mut issues = 0
    let mut beats = 0
    let mut cycles = 0
    let mut checksum = 0UL
    let mut stalled_addr : UInt64? = None
    while beats < 4096 && cycles < 9000 {
      let ready = cycles % 7 < 4
      let available = beats / len < issues && cycles % 11 != 3
      set("arready", 1, if ready { 1UL } else { 0UL })
      set("rvalid", 1, if available { 1UL } else { 0UL })
      set("rlast", 1, if beats % len == len - 1 { 1UL } else { 0UL })
      set("sample", 32, beats.to_uint64())
      // Inject a response error during the last mode.
      set("rresp", 2, if mode == 3 && beats == 99 { 2UL } else { 0UL })
      let v = get("arvalid") == 1UL
      if stalled_addr is Some(old) {
        assert_true(v)
        assert_eq(get("araddr"), old)
      }
      stalled_addr = if v && !ready { Some(get("araddr")) } else { None }
      if v && ready {
        let offset = if mode < 2 {
          issues * len * 64
        } else {
          let group = issues / (64 * stripes)
          let stripe = issues / 64 % stripes
          let row = issues / 4 % 16
          ((group * 16 + row) * stripes + stripe) * 2048 + issues % 4 * 512
        }
        assert_eq(get("araddr"), offset.to_uint64())
        assert_eq(get("arlen"), (len - 1).to_uint64())
        issues += 1
      }
      if available {
        assert_eq(get("rready"), 1UL)
        checksum = checksum ^ beats.to_uint64()
        beats += 1
      }
      assert_true(issues - beats / len <= 16)
      sim.rising_edge("clock")
      cycles += 1
    }
    assert_eq(get("beats"), 4096UL)
    assert_eq(get("cycles"), cycles.to_uint64())
    assert_eq(get("requests"), (4096 / len).to_uint64())
    assert_eq(get("requests"), get("bursts"))
    assert_eq(get("checksum"), checksum)
    assert_eq(get("flags") & 15UL, if mode == 3 { 14UL } else { 10UL })
  }
}

///|
test "staged scratch writes preserve the first and last W payload on immediate commit" {
  for staged_fill in [false, true] {
    let hw = @axi.bridge(
      streaming=true,
      wide512=true,
      wide1024=true,
      store_bursts=true,
      staged_fill~,
    )
    let sim = @sim.Simulator::prepare(hw)
    for node in hw.nodes() {
      if node.kind() is Input(name) {
        set(sim, name, node.signal_type().width().bits(), 0UL)
      }
    }
    let mut time = 0UL
    fn edge() -> Unit raise {
      sim.apply_event(
        @sim.TimestampEvent::checked(
          @sim.SimulationTime::from_uint64(time),
          [],
          [@ir.ClockDomainId::new(0)],
        ),
      )
      time += 1UL
    }
    fn word(pass : Int32, i : Int32) -> UInt64 {
      ((pass + 1) * 65537 + i * 259).to_uint64()
    }
    set(sim, "reset", 1, 1UL)
    edge()
    set(sim, "reset", 1, 0UL)
    set(sim, "calibrated", 1, 1UL)
    for pass in 0..<3 {
      for i in 0..<64 {
        set(sim, "request_fill_index", 6, i.to_uint64())
        set(sim, "request_fill_valid", 1, 1UL)
        set(sim, "request_fill_data", 32, word(pass, i))
        edge()
        if i % 11 == 3 {
          set(sim, "request_fill_valid", 1, 0UL)
          set(sim, "request_fill_data", 32, 0xabdef012UL)
          edge()
        }
        if pass == 0 && i == 31 {
          set(sim, "reset", 1, 1UL)
          edge()
          set(sim, "reset", 1, 0UL)
          break
        }
      }
      set(sim, "request_fill_valid", 1, 0UL)
      set(sim, "request_fill_data", 32, 0xbaadf00dUL)
      set(sim, "request_valid", 1, 1UL)
      set(sim, "request_write", 1, 1UL)
      set(sim, "request_line", 1, 1UL)
      set(sim, "request_burst", 1, 1UL)
      set(sim, "request_address", 32, pass.to_uint64() * 256UL)
      sim.settle()
      assert_eq(value(sim, "request_ready"), 1UL)
      edge()
      set(sim, "request_valid", 1, 0UL)
      if pass == 0 {
        sim.settle()
        assert_eq(value(sim, "response_valid"), 1UL)
        assert_eq(value(sim, "response_fault"), 1UL)
        assert_eq(value(sim, "m_axi_awvalid"), 0UL)
        assert_eq(value(sim, "m_axi_wvalid"), 0UL)
      } else {
        // AW completes independently. Each W beat stalls for three edges.
        set(sim, "m_axi_awready", 1, 1UL)
        sim.settle()
        assert_eq(value(sim, "m_axi_awvalid"), 1UL)
        assert_eq(value(sim, "m_axi_awlen"), 1UL)
        for beat in 0..<2 {
          for stall in 0..<4 {
            set(sim, "m_axi_wready", 1, if stall == 3 { 1UL } else { 0UL })
            sim.settle()
            assert_eq(value(sim, "m_axi_wvalid"), 1UL)
            assert_eq(value(sim, "m_axi_wlast"), beat.to_uint64())
            for lane in 0..<32 {
              assert_eq(
                value(sim, "m_axi_wword" + lane.to_string()),
                word(pass, beat * 32 + lane),
              )
            }
            edge()
          }
        }
        set(sim, "m_axi_bvalid", 1, 1UL)
        edge()
        set(sim, "m_axi_bvalid", 1, 0UL)
        sim.settle()
        assert_eq(value(sim, "response_valid"), 1UL)
        assert_eq(value(sim, "response_fault"), 0UL)
      }
      set(sim, "response_ready", 1, 1UL)
      edge()
      set(sim, "response_ready", 1, 0UL)
    }
  }
}

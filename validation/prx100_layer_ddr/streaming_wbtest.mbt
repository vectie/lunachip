///|
test "streaming bridge preserves strided packets faults resets and held responses" {
  for staggered in [false, true] {
    for period in [2, 3, 4, 7] {
      let b = bridge_bench(
        wide=true,
        batch=true,
        streaming=true,
        period~,
        staggered~,
      )
      assert_eq(b.joined.length(), 8)
      // Keep later native rows pending at the existing packet-prefix fault
      // injection. The faster bridge can otherwise finish all native reads
      // before the deliberately backpressured source consumes that prefix.
      b.read_delay = 60
      batch_bridge_replay(b)
      wide_bridge_replay(b)
    }
  }
}

///|
test "streaming response FIFOs sustain consecutive edges and wrap together" {
  for period in [2, 3, 7] {
    let b = bridge_bench(wide=true, batch=true, streaming=true, period~)
    for line in 0..<b.memory.length() {
      for word in 0..<4 {
        b.memory[line][word] = (line * 4 + word).reinterpret_as_uint()
      }
    }
    for _ in 0..<9 {
      set(b.sim, "request_wide", 1, 1UL)
      b.begin_line(0UL, burst=true, header=0x80000100UL)
      set(b.sim, "response_ready", 1, 0UL)
      for _ in 0..<500 {
        b.step()
      }
      set(b.sim, "response_ready", 1, 1UL)
      let mut received = 0
      let mut previous : Int32? = None
      for _ in 0..<400 {
        if b.tick % period == 0 && value(b.sim, "response_valid") == 1UL {
          if previous is Some(t) {
            assert_eq(b.tick - t, period)
          }
          previous = Some(b.tick)
          let base = (received / 8 * 64 + received % 8 * 4).to_uint64()
          for lane in 0..<4 {
            assert_eq(
              value(
                b.sim,
                if lane == 0 {
                  "response_data"
                } else {
                  "response_data" + lane.to_string()
                },
              ),
              base + lane.to_uint64(),
            )
          }
          assert_eq(value(b.sim, "response_fault"), 0UL)
          assert_eq(
            value(b.sim, "response_last"),
            if received == 31 {
              1UL
            } else {
              0UL
            },
          )
          received += 1
        }
        b.step()
        if received == 32 {
          break
        }
      }
      assert_eq(received, 32)
      b.result = None
    }
  }
}

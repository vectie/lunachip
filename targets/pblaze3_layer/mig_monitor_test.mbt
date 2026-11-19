///|
fn monitor_harness() -> Harness raise {
  let hw = @pblaze3_layer.mig_monitor()
  let sim = @sim.Simulator::prepare(hw)
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      sim.set_input(
        name,
        @wave.LogicValue::from_uint64(
          width=node.signal_type().width().bits(),
          value=0UL,
        ),
      )
    }
  }
  let h = Harness::{ sim, }
  h.set("reset", 1, 1UL)
  h.tick()
  h.set("reset", 1, 0UL)
  h
}

///|
test "MIG observer independently reconciles read credits, scope CDC and stalled channels" {
  let h = monitor_harness()
  let counts = Array::make(23, 0)
  let sync = Array::make(3, false)
  let mut tap = Array::make(7, false)
  let mut pending = 0
  let mut peak = 0
  let queue : Array[Int32] = []
  let mut head = 0
  let mut seed = 0x3e719bUL
  for cycle in 0..<6000 {
    seed = seed * 1664525UL + 1013904223UL
    let active = cycle < 1000
    let available = head < queue.length()
    let av = active && (seed & 7UL) < 3UL
    let ar = (seed & 24UL) != 8UL
    let rv = available && (!active || (seed & 96UL) != 32UL)
    let rr = !active || (seed & 384UL) != 128UL
    let last = available && queue[head] == 1
    let other = !available && active && cycle % 17 == 0
    let raw = [av || other, ar, !other, rv || other, rr, !other, last || other]
    let scope = active && cycle % 97 < 65
    if av && ar {
      queue.push(((seed >> 9) & 7UL).to_int() + 2)
    }
    if rv && rr {
      queue[head] -= 1
      if queue[head] == 0 {
        head += 1
      }
    }
    let accept = tap[0] && tap[1] && tap[2]
    let read = tap[3] && tap[4] && tap[5]
    let complete = read && tap[6]
    let blocked = tap[3] && tap[5] && !tap[4]
    let arblocked = tap[0] && tap[2] && !tap[1]
    for i, event in [accept, complete, read, blocked, arblocked] {
      if event {
        counts[i] += 1
      }
    }
    if pending > peak {
      peak = pending
    }
    let events = [
      true,
      accept,
      complete,
      read,
      blocked,
      !tap[3] && pending > 0,
      !tap[3] && pending == 0,
      tap[3] && !tap[5],
      arblocked,
      pending == 0 && !tap[0],
      pending == 1,
      pending >= 2 && pending <= 4,
      pending >= 5 && pending <= 8,
      pending >= 9 && pending <= 16,
      pending > 16,
    ]
    for i, event in events {
      if sync[2] && event {
        counts[8 + i] += 1
      }
    }
    if accept {
      pending += 1
    }
    if complete {
      pending -= 1
    }
    assert_true(pending >= 0 && pending < 512)
    for prefix in ["mig", "narrow", "wide"] {
      for
        i, name in [
          "arvalid", "arready", "arselect", "rvalid", "rready", "rselect", "rlast",
        ] {
        h.set(prefix + "_" + name, 1, if raw[i] { 1UL } else { 0UL })
      }
    }
    h.set("weight_scope", 1, if scope { 1UL } else { 0UL })
    h.tick()
    sync[2] = sync[1]
    sync[1] = sync[0]
    sync[0] = scope
    tap = raw
  }
  assert_eq(pending, 0)
  counts[5] = pending
  counts[6] = peak
  assert_true(peak > 16)
  assert_true(counts[3] > 0 && counts[4] > 0)
  assert_eq(
    counts[8],
    counts[11] + counts[12] + counts[13] + counts[14] + counts[15],
  )
  assert_eq(h.read(0UL), (0UL, 0x4d494731UL))
  assert_eq(h.read(4UL), (0UL, 200000000UL))
  assert_eq(h.read(8UL), (0UL, 0UL))
  for base in [0x100UL, 0x200UL, 0x300UL] {
    for i, expected in counts {
      assert_eq(h.read(base + 4UL * i.to_uint64()), (0UL, expected.to_uint64()))
    }
  }
  assert_eq(h.read(0x15cUL), (2UL, 0UL))
  assert_eq(h.read(1UL), (2UL, 0UL))
  assert_eq(h.write(0UL, 0UL), 2UL)
}

///|
test "MIG observer reports credit underflow and reset clears it" {
  let h = monitor_harness()
  for key in ["rvalid", "rready", "rselect", "rlast"] {
    h.set("mig_" + key, 1, 1UL)
  }
  h.tick()
  for key in ["rvalid", "rlast"] {
    h.set("mig_" + key, 1, 0UL)
  }
  h.tick()
  assert_eq(h.read(0x11cUL), (0UL, 1UL))
  h.set("reset", 1, 1UL)
  h.tick()
  h.set("reset", 1, 0UL)
  assert_eq(h.read(0x11cUL), (0UL, 0UL))
  assert_eq(h.read(0x114UL), (0UL, 0UL))
}

///|
test "MIG observer preserves simultaneous credits at the occupancy limit" {
  let h = monitor_harness()
  for key in ["arvalid", "arready", "arselect"] {
    h.set("mig_" + key, 1, 1UL)
  }
  for _ in 0..<511 {
    h.tick()
  }
  for key in ["rvalid", "rready", "rselect", "rlast"] {
    h.set("mig_" + key, 1, 1UL)
  }
  h.tick()
  h.tick()
  h.set("mig_arvalid", 1, 0UL)
  h.set("mig_rvalid", 1, 0UL)
  h.tick()
  h.tick()
  assert_eq(h.read(0x114UL), (0UL, 511UL))
  assert_eq(h.read(0x11cUL), (0UL, 0UL))
  h.set("mig_arvalid", 1, 1UL)
  h.tick()
  h.set("mig_arvalid", 1, 0UL)
  h.tick()
  assert_eq(h.read(0x114UL), (0UL, 0UL))
  assert_eq(h.read(0x118UL), (0UL, 511UL))
  assert_eq(h.read(0x11cUL), (0UL, 1UL))
}

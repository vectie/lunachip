///|
fn shape_reload_read_allowed(address : Int32) -> Bool {
  (address >= 3072 && address < 3200) ||
  array8_rectangle(address, 512, 3, 17, 23) ||
  array8_rectangle(address, 768, 17, 5, 11) ||
  array8_rectangle(address, 1152, 8, 1, 5) ||
  array8_rectangle(address, 1280, 1, 8, 16)
}

///|
fn shape_reload_write_allowed(address : Int32) -> Bool {
  (array8_rectangle(address, 1536, 3, 20, 28) && (address - 1536) % 4 == 0) ||
  (array8_rectangle(address, 2048, 8, 32, 44) && (address - 2048) % 4 == 0)
}

///|
fn shape_reload_assert_completion(
  actual : CompletionSnapshot,
  ordinal : Int32,
) -> Unit raise {
  let progress : Array[UInt64] = [
    51UL, 85UL, 0UL, 0UL, 8UL, 8UL, 0UL, 60UL, 256UL, 0UL,
  ]
  if ordinal >= progress.length() ||
    actual.id != (501 + ordinal).to_uint64() ||
    actual.fault != 0UL ||
    actual.bytes != progress[ordinal] ||
    actual.address != 0UL {
    fail("unexpected shape-reload completion at ordinal \{ordinal}")
  }
}

///|
fn shape_reload_assert_compute(
  simulator : @sim.Simulator,
  second : Bool,
) -> Unit raise {
  let steps = if second { 15UL } else { 23UL }
  for
    (name, expected) in [
      ("accepted_steps", steps),
      ("active_cycles", steps),
      ("elapsed_cycles", steps + 1UL),
      ("stall_cycles", 0UL),
      ("capture_cycles", if second { 64UL } else { 15UL }),
    ] {
    if output_value(simulator, name) != expected {
      fail("shape-reload compute counter \{name} did not equal \{expected}")
    }
  }
}

///|
fn shape_reload_read_class(address : Int32) -> Int32 raise {
  if address >= 3072 && address < 3200 {
    0
  } else if array8_rectangle(address, 512, 3, 17, 23) {
    1
  } else if array8_rectangle(address, 768, 17, 5, 11) {
    2
  } else if array8_rectangle(address, 1152, 8, 1, 5) {
    3
  } else if array8_rectangle(address, 1280, 1, 8, 16) {
    4
  } else {
    fail("shape-reload read an unowned byte \{address}")
  }
}

///|
fn shape_reload_write_class(address : Int32) -> Int32 raise {
  if shape_reload_write_allowed(address) {
    if address < 2048 {
      0
    } else {
      1
    }
  } else {
    fail("shape-reload wrote padding or an unowned word \{address}")
  }
}

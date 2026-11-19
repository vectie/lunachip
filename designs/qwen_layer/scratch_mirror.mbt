///|
priv struct ScratchMirror {
  ram : @wire.Memory
  word : @wire.Signal
}

///|
fn Machine::word_ram(m : Machine, name : String) -> @wire.Memory raise {
  m.b.synchronous_memory(
    name,
    @wire.uint(32),
    32768,
    m.d,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
  )
}

///|
// Give each operand its own 1R1W block-RAM leaf. Both observe the same
// committed host, DMA, matrix and vector writes. The complementary address
// mapping preserves separate physical write-address nets for the two leaves.
fn scratch_mirror(m : Machine) -> ScratchMirror? raise {
  if !m.dual_read {
    return None
  }
  let b = m.b
  let ram = m.word_ram("scratch_b")
  let word = b.memory_read(
    ram,
    "b",
    b.bit_not(b.truncate(m.v("bi"), 15)),
    enable=b.bit_and(m.is_state(29UL), b.bit_not(b.reset_asserted(m.rs))),
    enable_behavior=HoldLast,
  )
  Some({ ram, word, })
}

///|
fn write_scratch(
  m : Machine,
  ram : @wire.Memory,
  mirror : ScratchMirror?,
  address : @wire.Signal,
  data : @wire.Signal,
  enable : @wire.Signal,
) -> Unit raise {
  m.b.memory_write(ram, "write", address, data, enable~)
  if mirror is Some(other) {
    m.b.memory_write(other.ram, "write", m.b.bit_not(address), data, enable~)
  }
}

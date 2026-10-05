///|
fn capacity_wrap_host() -> Host raise {
  {
    kind: CapacityWrap,
    memory: capacity_wrap_memory(),
    pending: None,
    held: None,
    next_tag: 0UL,
    requests: 0,
    reads: 0,
    writes: 0,
    stalls: 0,
  }
}

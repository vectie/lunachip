///|
// State 4 primes the synchronous scratch port. State 17 streams a complete
// 256-byte block. A successful B response grants a second pass, allowing
// the existing scalar argmax to observe exactly the words committed to DDR.
fn store_burst_path(
  m : Machine,
  scratch : @wire.Signal,
  store : @wire.Signal,
  response : @wire.Signal,
  bad : @wire.Signal,
  healthy : @wire.Signal,
) -> Unit raise {
  let b = m.b
  let group = m.v("store_group")
  let committed = m.v("store_committed")
  let lane = m.v("store_lane")
  let begin = all(b, [
    m.is_state(4UL),
    store,
    b.equal(field(b, m.v("ext"), 7, 0), u(b, 8, 0UL)),
    b.greater_equal(b.sub(m.v("n"), m.v("i")), u(b, 32, 64UL)),
  ])
  let stream = all(b, [m.is_state(17UL), healthy])
  let end_pass = all(b, [stream, b.equal(lane, u(b, 6, 63UL))])
  m.jump(begin, 17UL)
  m.set("store_group", begin, 1UL)
  m.set("store_lane", begin, 0UL)
  m.put("store_cursor", begin, b.add(b.truncate(m.v("ai"), 15), u(b, 15, 1UL)))
  increment(m, "store_lane", stream, 1UL)
  increment(m, "store_cursor", stream, 1UL)
  m.jump(b.bit_and(end_pass, b.bit_not(committed)), 9UL)
  let ok = all(b, [response, store, group, b.bit_not(bad), healthy])
  m.jump(ok, 4UL)
  m.set("store_committed", ok, 1UL)
  increment(m, "ddr_beats", ok, 64UL)
  let finish = b.bit_and(end_pass, committed)
  m.set("store_group", finish, 0UL)
  m.set("store_committed", finish, 0UL)
  increment(m, "ai", finish, 64UL)
  increment(m, "i", finish, 64UL)
  increment(m, "ext", finish, 256UL)
  m.put(
    "state",
    finish,
    b.mux(
      b.equal(b.add(m.v("i"), u(b, 32, 64UL)), m.v("n")),
      u(b, 5, 13UL),
      u(b, 5, 4UL),
    ),
  )
  for
    (name, value) in [
      ("store_fill_valid", b.bit_and(stream, b.bit_not(committed))),
      ("store_fill_index", lane),
      ("store_word", scratch),
      ("store_commit_valid", b.bit_and(stream, committed)),
      (
        "store_commit_address",
        cat(b, field(b, m.v("ext"), 31, 8), cat(b, lane, u(b, 2, 0UL))),
      ),
    ] {
    let p = b.output(name, value.signal_type())
    b.output_timing(p, ProducedIn(m.d.id()))
    b.connect(p, value)
  }
}

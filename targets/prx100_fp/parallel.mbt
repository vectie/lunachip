///|
/// BRAM-only FP experiment; separate ABI from the integer DDR projection.
pub fn parallel_controller() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("Prx100FloatingPointParallelControl")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  let a = axi_begin(b, d, reset)
  let c : Map[String, @wire.Signal] = Map([])
  for p in @fp.parallel_dot_product().outputs() {
    let x = b.input("c_" + p.name(), p.signal_type())
    b.input_timing(x, SampledIn(d.id()))
    c[p.name()] = x
  }
  let idle = b.bit_not(c["busy"])
  let shape = eq(b, a.strobe, 15UL)
  let aligned = eq(b, b.slice(a.address, 1, 0), 0UL)
  let operand = both(b, [
    b.greater_equal(a.address, n(b, 32, 0x1000UL)),
    b.less_than(a.address, n(b, 32, 0x9000UL)),
  ])
  let load = both(b, [a.write, shape, aligned, operand, idle])
  let length = b.register_state_in(d, @wire.uint(11), reset~)
  let legal_length = both(b, [
    b.greater_equal(a.data, n(b, 32, 1UL)),
    b.less_equal(a.data, n(b, 32, 1024UL)),
  ])
  let set_length = both(b, [
    a.write,
    shape,
    eq(b, a.address, 12UL),
    idle,
    legal_length,
  ])
  update(b, length, set_length, b.truncate(a.data, 11))
  let start = both(b, [
    a.write,
    shape,
    eq(b, a.address, 16UL),
    eq(b, a.data, 1UL),
    idle,
    b.greater_equal(length.value(), n(b, 11, 1UL)),
  ])
  out(b, "load", load)
  out(
    b,
    "write_lane",
    b.truncate(
      b.sub(b.logical_shift_right(a.address, n(b, 4, 12UL)), n(b, 32, 1UL)),
      3,
    ),
  )
  out(b, "write_address", u(b, b.slice(a.address, 11, 2)))
  out(b, "write_data", a.data)
  out(b, "start", start)
  out(b, "length", length.value())
  let status = u(b, b.concat(c["error"], b.concat(c["done"], c["busy"])))
  axi_finish(b, a, any(b, [load, set_length, start]), [
    (0UL, n(b, 32, 0x46504231UL)),
    (4UL, n(b, 32, 0x00010001UL)),
    (8UL, status),
    (12UL, length.value()),
    (32UL, c["result_0"]),
    (36UL, c["result_1"]),
    (40UL, c["result_2"]),
    (44UL, c["result_3"]),
    (48UL, c["result_4"]),
    (52UL, c["result_5"]),
    (56UL, c["result_6"]),
    (60UL, c["result_7"]),
    (24UL, c["cycles"]),
  ])
  b.finish()
}

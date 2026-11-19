///|
priv struct Axi {
  write : @wire.Signal
  address : @wire.Signal
  data : @wire.Signal
  strobe : @wire.Signal
  aw_pending : @wire.RegisterHandle
  w_pending : @wire.RegisterHandle
  b_valid : @wire.RegisterHandle
  b_response : @wire.RegisterHandle
  r_valid : @wire.RegisterHandle
  r_response : @wire.RegisterHandle
  r_data : @wire.RegisterHandle
  ar_address : @wire.Signal
  read : @wire.Signal
  b_ready : @wire.Signal
  r_ready : @wire.Signal
  aw_accept : @wire.Signal
  w_accept : @wire.Signal
}

///|
fn axi_begin(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> Axi raise {
  let aw_address = input(b, d, "s_axi_awaddr", 32)
  let aw_valid = input(b, d, "s_axi_awvalid", 1)
  let w_data = input(b, d, "s_axi_wdata", 32)
  let w_strobe = input(b, d, "s_axi_wstrb", 4)
  let w_valid = input(b, d, "s_axi_wvalid", 1)
  let b_ready = input(b, d, "s_axi_bready", 1)
  let ar_address = input(b, d, "s_axi_araddr", 32)
  let ar_valid = input(b, d, "s_axi_arvalid", 1)
  let r_ready = input(b, d, "s_axi_rready", 1)
  let aw_pending = b.register_state_in(d, @wire.bits(1), reset~)
  let w_pending = b.register_state_in(d, @wire.bits(1), reset~)
  let b_valid = b.register_state_in(d, @wire.bits(1), reset~)
  let b_response = b.register_state_in(d, @wire.uint(2), reset~)
  let r_valid = b.register_state_in(d, @wire.bits(1), reset~)
  let r_response = b.register_state_in(d, @wire.uint(2), reset~)
  let r_data = b.register_state_in(d, @wire.uint(32), reset~)
  let address = b.register_state_in(d, @wire.uint(32), reset~)
  let data = b.register_state_in(d, @wire.uint(32), reset~)
  let strobe = b.register_state_in(d, @wire.uint(4), reset~)
  let aw_ready = b.bit_not(any(b, [aw_pending.value(), b_valid.value()]))
  let w_ready = b.bit_not(any(b, [w_pending.value(), b_valid.value()]))
  let aw_accept = b.bit_and(aw_valid, aw_ready)
  let w_accept = b.bit_and(w_valid, w_ready)
  let write = both(b, [
    aw_pending.value(),
    w_pending.value(),
    b.bit_not(b_valid.value()),
  ])
  update(b, address, aw_accept, aw_address)
  update(b, data, w_accept, w_data)
  update(b, strobe, w_accept, w_strobe)
  out(b, "s_axi_awready", aw_ready)
  out(b, "s_axi_wready", w_ready)
  out(b, "s_axi_bvalid", b_valid.value())
  out(b, "s_axi_bresp", b_response.value())
  out(b, "s_axi_arready", b.bit_not(r_valid.value()))
  out(b, "s_axi_rvalid", r_valid.value())
  out(b, "s_axi_rresp", r_response.value())
  out(b, "s_axi_rdata", r_data.value())
  {
    write,
    address: address.value(),
    data: data.value(),
    strobe: strobe.value(),
    aw_pending,
    w_pending,
    b_valid,
    b_response,
    r_valid,
    r_response,
    r_data,
    ar_address,
    read: b.bit_and(ar_valid, b.bit_not(r_valid.value())),
    b_ready,
    r_ready,
    aw_accept,
    w_accept,
  }
}

///|
fn axi_finish(
  b : @wire.ModuleBuilder,
  a : Axi,
  write_ok : @wire.Signal,
  registers : Array[(UInt64, @wire.Signal)],
) -> Unit raise {
  b.connect_next(
    a.aw_pending,
    b.mux(
      a.write,
      n(b, 1, 0UL),
      b.mux(a.aw_accept, n(b, 1, 1UL), a.aw_pending.value()),
    ),
  )
  b.connect_next(
    a.w_pending,
    b.mux(
      a.write,
      n(b, 1, 0UL),
      b.mux(a.w_accept, n(b, 1, 1UL), a.w_pending.value()),
    ),
  )
  b.connect_next(
    a.b_valid,
    b.mux(
      a.write,
      n(b, 1, 1UL),
      b.mux(a.b_ready, n(b, 1, 0UL), a.b_valid.value()),
    ),
  )
  update(b, a.b_response, a.write, b.mux(write_ok, n(b, 2, 0UL), n(b, 2, 2UL)))
  let mut data = n(b, 32, 0UL)
  let mut valid = n(b, 1, 0UL)
  for (address, value) in registers {
    let select = eq(b, a.ar_address, address)
    let value = u(b, value)
    let value = if value.signal_type().width().bits() < 32 {
      b.zero_extend(value, 32)
    } else {
      value
    }
    data = b.mux(select, value, data)
    valid = b.bit_or(valid, select)
  }
  b.connect_next(
    a.r_valid,
    b.mux(
      a.read,
      n(b, 1, 1UL),
      b.mux(a.r_ready, n(b, 1, 0UL), a.r_valid.value()),
    ),
  )
  update(b, a.r_data, a.read, data)
  update(b, a.r_response, a.read, b.mux(valid, n(b, 2, 0UL), n(b, 2, 2UL)))
}

///|
priv struct Axi {
  write : @wire.Signal
  address : @wire.Signal
  data : @wire.Signal
  strobe : @wire.Signal
  read : @wire.Signal
  ar_address : @wire.Signal
  aw_pending : @wire.RegisterHandle
  w_pending : @wire.RegisterHandle
  ar_pending : @wire.RegisterHandle
  b_valid : @wire.RegisterHandle
  b_response : @wire.RegisterHandle
  r_valid : @wire.RegisterHandle
  r_response : @wire.RegisterHandle
  r_data : @wire.RegisterHandle
  aw_accept : @wire.Signal
  w_accept : @wire.Signal
  ar_accept : @wire.Signal
  b_ready : @wire.Signal
  r_ready : @wire.Signal
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
  let ar_pending = b.register_state_in(d, @wire.bits(1), reset~)
  let b_valid = b.register_state_in(d, @wire.bits(1), reset~)
  let b_response = b.register_state_in(d, @wire.uint(2), reset~)
  let r_valid = b.register_state_in(d, @wire.bits(1), reset~)
  let r_response = b.register_state_in(d, @wire.uint(2), reset~)
  let r_data = b.register_state_in(d, @wire.uint(32), reset~)
  let address = b.register_state_in(d, @wire.uint(32), reset~)
  let data = b.register_state_in(d, @wire.uint(32), reset~)
  let strobe = b.register_state_in(d, @wire.uint(4), reset~)
  let read_address = b.register_state_in(d, @wire.uint(32), reset~)
  let aw_ready = b.bit_not(any(b, [aw_pending.value(), b_valid.value()]))
  let w_ready = b.bit_not(any(b, [w_pending.value(), b_valid.value()]))
  let ar_ready = b.bit_not(any(b, [ar_pending.value(), r_valid.value()]))
  let aw_accept = b.bit_and(aw_valid, aw_ready)
  let w_accept = b.bit_and(w_valid, w_ready)
  let ar_accept = b.bit_and(ar_valid, ar_ready)
  update(b, address, aw_accept, aw_address)
  update(b, data, w_accept, w_data)
  update(b, strobe, w_accept, w_strobe)
  update(b, read_address, ar_accept, ar_address)
  for
    (name, value) in [
      ("s_axi_awready", aw_ready),
      ("s_axi_wready", w_ready),
      ("s_axi_arready", ar_ready),
      ("s_axi_bvalid", b_valid.value()),
      ("s_axi_bresp", b_response.value()),
      ("s_axi_rvalid", r_valid.value()),
      ("s_axi_rresp", r_response.value()),
      ("s_axi_rdata", r_data.value()),
    ] {
    out(b, name, value)
  }
  {
    write: both(b, [
      aw_pending.value(),
      w_pending.value(),
      b.bit_not(b_valid.value()),
    ]),
    address: address.value(),
    data: data.value(),
    strobe: strobe.value(),
    read: b.bit_and(ar_pending.value(), b.bit_not(r_valid.value())),
    ar_address: read_address.value(),
    aw_pending,
    w_pending,
    ar_pending,
    b_valid,
    b_response,
    r_valid,
    r_response,
    r_data,
    aw_accept,
    w_accept,
    ar_accept,
    b_ready,
    r_ready,
  }
}

///|
fn axi_finish(
  b : @wire.ModuleBuilder,
  a : Axi,
  write_done : @wire.Signal,
  write_ok : @wire.Signal,
  read_done : @wire.Signal,
  read_ok : @wire.Signal,
  read_data : @wire.Signal,
) -> Unit raise {
  for
    (pending, accept, done) in [
      (a.aw_pending, a.aw_accept, write_done),
      (a.w_pending, a.w_accept, write_done),
      (a.ar_pending, a.ar_accept, read_done),
    ] {
    b.connect_next(
      pending,
      b.mux(done, n(b, 1, 0UL), b.mux(accept, n(b, 1, 1UL), pending.value())),
    )
  }
  b.connect_next(
    a.b_valid,
    b.mux(
      write_done,
      n(b, 1, 1UL),
      b.mux(a.b_ready, n(b, 1, 0UL), a.b_valid.value()),
    ),
  )
  b.connect_next(
    a.r_valid,
    b.mux(
      read_done,
      n(b, 1, 1UL),
      b.mux(a.r_ready, n(b, 1, 0UL), a.r_valid.value()),
    ),
  )
  update(
    b,
    a.b_response,
    write_done,
    b.mux(write_ok, n(b, 2, 0UL), n(b, 2, 2UL)),
  )
  update(b, a.r_response, read_done, b.mux(read_ok, n(b, 2, 0UL), n(b, 2, 2UL)))
  update(b, a.r_data, read_done, b.mux(read_ok, read_data, n(b, 32, 0UL)))
}

///|
/// Read-only MIG UI probe. Each run reads 64 MiB at the default size. Modes
/// select sequential 512 B, sequential 4 KiB, or sixteen-row groups of 2 KiB
/// fragments with 4/6 KiB row pitches. Offset zero is only read.
pub fn mig_reader(log_beats~ : Int32 = 20) -> @ir.Module raise {
  guard log_beats >= 12 && log_beats <= 23 else { raise InvalidGeometry }
  let b = @wire.ModuleBuilder::new("pblaze3_mig_reader")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  fn state(width : Int32) -> @wire.RegisterHandle raise {
    b.register_state_in(
      d,
      if width == 1 {
        @wire.bits(1)
      } else {
        @wire.uint(width)
      },
      reset~,
    )
  }
  fn port(name : String, width : Int32) -> @wire.Signal raise {
    input(b, d, name, width)
  }
  let start = port("start", 1)
  let previous = b.register_in(d, start, reset~)
  let cmd = port("mode", 2)
  let cal = port("calibrated", 1)
  let ready = port("arready", 1)
  let valid = port("rvalid", 1)
  let last = port("rlast", 1)
  let resp = port("rresp", 2)
  let id = port("rid", 1)
  let data = port("sample", 32)
  let busy = state(1)
  let done = state(1)
  let fault = state(1)
  let mode = state(2)
  let addr = state(31)
  let clocks = state(32)
  let beats = state(32)
  let sent = state(32)
  let returned = state(32)
  let pending = state(5)
  let stripe = state(2)
  let checksum = state(32)
  let arm = all(b, [start, b.bit_not(previous), b.bit_not(busy.value()), cal])
  let long_burst = eq(b, mode.value(), 1UL)
  let goal = 1UL << log_beats
  let arlen = b.mux(long_burst, n(b, 8, 63UL), n(b, 8, 7UL))
  let requests = b.mux(long_burst, n(b, 32, goal / 64UL), n(b, 32, goal / 8UL))
  let arv = all(b, [
    busy.value(),
    b.not_equal(sent.value(), requests),
    b.less_than(pending.value(), n(b, 5, 16UL)),
  ])
  let issue = b.bit_and(arv, ready)
  let beat = b.bit_and(busy.value(), valid)
  let ret = b.bit_and(beat, last)
  let final_beat = b.bit_and(beat, eq(b, beats.value(), goal - 1UL))
  let expected_last = b.mux(
    long_burst,
    eq(b, b.slice(beats.value(), 5, 0), 63UL),
    eq(b, b.slice(beats.value(), 2, 0), 7UL),
  )
  let bad = b.bit_or(
    all(b, [busy.value(), b.bit_not(cal)]),
    all(b, [
      beat,
      any(b, [
        id,
        b.bit_not(eq(b, resp, 0UL)),
        b.bit_xor(last, expected_last),
        eq(b, pending.value(), 0UL),
      ]),
    ]),
  )
  b.connect_next(mode, b.mux(arm, cmd, mode.value()))
  b.connect_next(
    busy,
    b.bit_or(arm, b.bit_and(busy.value(), b.bit_not(final_beat))),
  )
  b.connect_next(
    done,
    b.bit_and(b.bit_not(arm), b.bit_or(done.value(), final_beat)),
  )
  b.connect_next(fault, b.bit_and(b.bit_not(arm), b.bit_or(fault.value(), bad)))
  fn cleared(
    r : @wire.RegisterHandle,
    fire : @wire.Signal,
    next : @wire.Signal,
  ) -> Unit raise {
    let x = r.value()
    b.connect_next(
      r,
      b.mux(arm, b.constant(x.signal_type(), 0UL), b.mux(fire, next, x)),
    )
  }
  fn count(r : @wire.RegisterHandle, fire : @wire.Signal) -> Unit raise {
    cleared(r, fire, b.add(r.value(), n(b, 32, 1UL)))
  }
  count(clocks, busy.value())
  count(sent, issue)
  count(returned, ret)
  count(beats, beat)
  cleared(checksum, beat, b.bit_xor(checksum.value(), data))
  cleared(
    pending,
    b.bit_xor(issue, ret),
    b.mux(
      issue,
      b.add(pending.value(), n(b, 5, 1UL)),
      b.sub(pending.value(), n(b, 5, 1UL)),
    ),
  )
  let end_group = eq(b, b.slice(sent.value(), 5, 0), 63UL)
  let end_row = eq(b, b.slice(sent.value(), 1, 0), 3UL)
  let pitch6 = eq(b, mode.value(), 3UL)
  let last_stripe = b.mux(
    pitch6,
    eq(b, stripe.value(), 2UL),
    eq(b, stripe.value(), 1UL),
  )
  cleared(
    stripe,
    b.bit_and(issue, end_group),
    b.mux(last_stripe, n(b, 2, 0UL), b.add(stripe.value(), n(b, 2, 1UL))),
  )
  let row_delta = b.mux(pitch6, n(b, 31, 4608UL), n(b, 31, 2560UL))
  let wrap_delta = b.mux(
    pitch6,
    n(b, 31, 0x80000000UL + 512UL - 15UL * 6144UL),
    n(b, 31, 0x80000000UL + 512UL - 15UL * 4096UL),
  )
  let group_delta = b.mux(last_stripe, n(b, 31, 512UL), wrap_delta)
  let step = b.mux(
    long_burst,
    n(b, 31, 4096UL),
    b.mux(
      all(b, [b.slice(mode.value(), 1, 1), end_row]),
      b.mux(end_group, group_delta, row_delta),
      n(b, 31, 512UL),
    ),
  )
  cleared(addr, issue, b.add(addr.value(), step))
  for
    (name, x) in [
      ("arvalid", arv),
      ("araddr", addr.value()),
      ("arlen", arlen),
      ("rready", busy.value()),
      ("cycles", clocks.value()),
      ("beats", beats.value()),
      ("requests", sent.value()),
      ("bursts", returned.value()),
      ("checksum", checksum.value()),
      (
        "flags",
        b.concat(
          mode.value(),
          b.concat(
            cal,
            b.concat(fault.value(), b.concat(done.value(), busy.value())),
          ),
        ),
      ),
    ] {
    out(b, d, name, x)
  }
  b.finish()
}

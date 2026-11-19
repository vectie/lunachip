///|
fn bridge_native_outputs(
  b : @wire.ModuleBuilder,
  fast : @wire.ClockDomain,
  request : @wire.Signal,
  line_index : @wire.Signal,
  command : @wire.Signal,
  wdf : @wire.Signal,
  writing : @wire.Signal,
  full_write : @wire.Signal,
  lane : @wire.Signal,
  write_word : @wire.Signal,
  collected : Array[@wire.RegisterHandle],
  state : @wire.Signal,
  poisoned : @wire.Signal,
) -> Unit raise {
  out_in(
    b,
    fast,
    "app_addr",
    b.zero_extend(
      b.add(
        u(b, b.concat(b.slice(request, 59, 36), n(b, 3, 0UL))),
        b.shift_left(b.zero_extend(line_index, 27), n(b, 2, 3UL)),
      ),
      28,
    ),
  )
  out_in(b, fast, "app_cmd", b.mux(writing, n(b, 3, 0UL), n(b, 3, 1UL)))
  out_in(b, fast, "app_en", command)
  out_in(b, fast, "app_wdf_wren", wdf)
  out_in(b, fast, "app_wdf_end", wdf)
  let mask_shift = u(b, b.concat(lane, n(b, 2, 0UL)))
  out_in(
    b,
    fast,
    "app_wdf_mask",
    b.mux(
      full_write,
      n(b, 16, 0UL),
      b.bit_xor(n(b, 16, 0xffffUL), b.shift_left(n(b, 16, 15UL), mask_shift)),
    ),
  )
  for i in 0..<4 {
    out_in(
      b,
      fast,
      "app_wdf_word" + i.to_string(),
      if i == 0 {
        write_word
      } else {
        b.mux(full_write, collected[i - 1].value(), write_word)
      },
    )
  }
  out_in(b, fast, "bridge_state", state)
  out_in(b, fast, "bridge_poisoned", poisoned)
}

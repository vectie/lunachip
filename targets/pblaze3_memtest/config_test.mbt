///|
test "memory tester geometry includes highest legal line without wrap" {
  assert_eq(
    @pblaze3_memtest.controller(beats=1U, base_address=0x7ffffff0U).name(),
    "Pblaze3Memtest",
  )
  assert_eq(@pblaze3_memtest.controller(), @pblaze3_memtest.controller())
  for
    (beats, base_address) in [
      (0U, 0U),
      (1U, 1U),
      (2U, 0x7ffffff0U),
      (1U, 0x80000000U),
      (1U, 0xfffffff0U),
      (134217729U, 0U),
    ] {
    let rejected = try {
      ignore(@pblaze3_memtest.controller(beats~, base_address~))
      false
    } catch {
      @pblaze3_memtest.InvalidGeometry => true
      _ => false
    }
    assert_true(rejected)
  }
  let hw = @pblaze3_memtest.controller()
  for name in ["completed_writes", "checked_reads"] {
    let ports = hw.outputs().filter(p => p.name() == name)
    assert_eq(ports.length(), 1)
    assert_eq(ports[0].signal_type().width().bits(), 28)
  }
}

///|
fn equality_fixture() -> (@ir.Module, String) raise {
  let b = @wire.ModuleBuilder::new("Prx100EqualityNormalization")
  let left = b.input("left", @wire.uint(4))
  let right = b.input("right", @wire.uint(4))
  let result = b.equal(left, right)
  let port = b.output("result", result.signal_type())
  b.connect(port, result)
  let hardware = b.finish()
  let emitted = @systemverilog.emit_design(
    @ir.Design::single("equality", hardware),
  )
  (hardware, emitted.modules()[0].source())
}

///|
test "native equality normalization rejects backend and signature drift" {
  let (hardware, source) = equality_fixture()
  assert_true(
    native_equality(source, hardware).contains("lc_fn_eq_w4 = (a == b);"),
  )
  for
    invalid in [
      "unsupported backend",
      source
      .split("    input logic [3:0] a,")
      .map(s => s.to_owned())
      .to_array()
      .join("    input logic [2:0] a,"),
      source + source,
    ] {
    try native_equality(invalid, hardware) catch {
      MissingMapping(_) => ()
      _ => fail("unexpected normalization error")
    } noraise {
      _ => fail("malformed normalization input accepted")
    }
  }
}

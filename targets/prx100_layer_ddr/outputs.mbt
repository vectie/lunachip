///|
fn out_in(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  name : String,
  x : @wire.Signal,
) -> Unit raise {
  let p = b.output(name, x.signal_type())
  b.output_timing(p, ProducedIn(d.id()))
  b.connect(p, x)
}

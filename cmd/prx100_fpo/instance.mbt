///|
fn instance(
  hw : @ir.Module,
  e : @sv.EmittedDesign,
  label : String,
  net : (String) -> String,
) -> String raise {
  let con : Array[String] = []
  for n in hw.nodes() {
    if n.kind() is Input(name) {
      con.push("." + mapped(e, name, InputPort) + "(" + net(name) + ")")
    }
  }
  for p in hw.outputs() {
    con.push("." + mapped(e, p.name(), OutputPort) + "(" + net(p.name()) + ")")
  }
  "  " +
  e.modules()[0].identifier() +
  " " +
  label +
  "(" +
  con.join(",") +
  ");\n"
}

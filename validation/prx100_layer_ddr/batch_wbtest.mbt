///|
test "four-row batch owns strided data and drains every reset and fault prefix" {
  let b = bridge_bench(wide=true, batch=true)
  batch_bridge_replay(b)
}

///|
test "native-width packets preserve every lane backpressure reset and fault ownership" {
  for period in [2, 4, 7] {
    wide_bridge_replay(bridge_bench(wide=true, period~))
  }
}

///|
test "CLI portable demo completes real load execute store and fence through external bytes" {
  inspect(
    run_command(["portable-demo"]),
    content=(
      #|LunaWave FluxTile portable demo: LoadA -> LoadB -> MatMul -> StoreC -> Fence
      #|host C=[-44, 12, 66; -2005, 2328, 715] oracle=match
      #|5 successful completions; requests=21 read_bytes=15 write_bytes=24; padding preserved
      #|modeled compute cycles=7 active=6 capture=6; transport backpressure and delayed responses exercised
      #|Simulation only; provisional serial transport, not a frozen device ABI.
    ),
  )
}

///|
test "CLI byte memory decodes independently seeded signed little endian words" {
  let host = DemoHost::new()
  for
    (address, value) in [
      (100, 255),
      (101, 255),
      (102, 255),
      (103, 255),
      (104, 0),
      (105, 0),
      (106, 0),
      (107, 128),
    ] {
    host.memory[address] = value
  }
  assert_eq(host.word(100), -1)
  assert_eq(host.word(104), -2147483648)
  host.seed(200, 8, 2, 2, [-128, 127, -1, 0])
  assert_eq(host.memory[200], 128)
  assert_eq(host.memory[201], 127)
  assert_eq(host.memory[208], 255)
  assert_eq(host.memory[209], 0)
  assert_eq(host.memory[202], 165)
}

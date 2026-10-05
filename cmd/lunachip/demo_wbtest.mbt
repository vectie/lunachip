///|
test "CLI default and explicit counter retain bootstrap smoke output" {
  inspect(
    run_command([]),
    content="LunaChip bootstrap: FluxTile control cycle=4 value=4",
  )
  assert_eq(run_command(["counter"]), run_command([]))
}

///|
test "CLI matmul demo executes signed banked hardware and modeled stalls" {
  inspect(
    run_command(["matmul-demo"]),
    content=(
      #|LunaWave FluxTile execute demo: signed INT8 M=2 N=3 K=3
      #|C=[-44, 12, 66; -2005, 2328, 715]
      #|completion id=42 fault=0 oracle=match
      #|modeled execution cycles=9 active=6 stalls=2; completion held for 2 cycles
      #|Simulation only; provisional execute slice, not a complete device ABI.
    ),
  )
}

///|
test "CLI help and invalid requests have a precise usage contract" {
  let usage = "Usage: lunachip [counter | matmul-demo | portable-demo | ring-demo | concurrent-demo | ring-concurrent-demo | help]"
  for name in ["help", "--help", "-h"] {
    assert_eq(run_command([name]), usage)
  }
  for
    args in [
      ["unknown"],
      ["counter", "extra"],
      ["matmul-demo", "extra"],
      ["portable-demo", "extra"],
      ["ring-demo", "extra"],
      ["concurrent-demo", "extra"],
      ["ring-concurrent-demo", "extra"],
    ] {
    try run_command(args) catch {
      DemoError::Usage(actual) => assert_eq(actual, usage)
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("invalid command must raise a usage error")
    }
  }
}

///|
test "CLI concurrent demo observes queued DMA compute overlap and ordered duplicate IDs" {
  let result = run_command(["concurrent-demo"])
  assert_true(
    result.contains("C0=[-44, 12, 66; -2005, 2328, 715]; C1=8x8 oracle=match"),
  )
  assert_true(
    result.contains(
      "10 ordered successful completions with duplicate caller ID=42",
    ),
  )
  assert_true(result.contains("read_edges="))
  assert_true(result.contains("write_edges="))
  assert_true(
    result.contains(
      "requests=277 read_bytes=207 write_bytes=280; all 1024 host bytes checked",
    ),
  )
  assert_true(
    result.contains(
      "Simulation only; provisional queued concurrent engine, not hardware performance.",
    ),
  )
}

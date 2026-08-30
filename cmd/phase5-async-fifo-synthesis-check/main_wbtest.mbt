///|
test "final synthesis check CLI parses the exact five-path contract" {
  assert_eq(
    parse_async_fifo_synthesis_check_command([
      "checker", "check", "inventory.json", "pre-map.json", "pre-map.rtlil", "lock.json",
      "evidence-out",
    ]),
    Check(
      "inventory.json", "pre-map.json", "pre-map.rtlil", "lock.json", "evidence-out",
    ),
  )
  assert_eq(
    async_fifo_evidence_output_path("evidence-out"),
    "evidence-out/async-fifo-synthesis-evidence.json",
  )
}

///|
test "final synthesis check CLI rejects argument drift" {
  for
    arguments in [
      ["checker"],
      ["checker", "matrix", "out"],
      ["checker", "check", "inventory", "json", "rtlil", "lock"],
      ["checker", "check", "inventory", "json", "rtlil", "lock", "out", "extra"],
    ] {
    try parse_async_fifo_synthesis_check_command(arguments) catch {
      _ => ()
    } noraise {
      _ => fail("argument drift must be rejected")
    }
  }
}

///|
test "final synthesis check CLI refuses an existing output directory" {
  try create_new_output_directory("toolchain/yosys") catch {
    _ => ()
  } noraise {
    _ => fail("existing output must never be overwritten")
  }
}

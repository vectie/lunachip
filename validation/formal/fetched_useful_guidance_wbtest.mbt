///|
fn fetched_useful_guidance_test_roster() -> String {
  let text = StringBuilder()
  for edge in 0..<419 {
    for (name, width) in fetched_useful_guidance_pins() {
      let bits = StringBuilder()
      for _ in 0..<width {
        bits.write_string(if name == "reset" && edge == 0 { "1" } else { "0" })
      }
      text.write_string("PRE \{edge} \{name} \{bits}\n")
    }
  }
  text.to_string()
}

///|
fn fetched_useful_guidance_test_reject(roster : String) -> Unit raise {
  try fetched_useful_guidance(roster) catch {
    InvalidFormalBundleIdentity(_) => ()
    error => fail("unexpected guidance error: \{Repr(error)}")
  } noraise {
    _ => fail("invalid fetched input guidance accepted")
  }
}

///|
test "fetched input guidance whitelist is bound to unchanged original DUT and harness" {
  let design = flux_tile_formal_design()
  guard design.top_module() is Some(hardware) else { fail("fetched top") }
  let actual = hardware
    .nodes()
    .filter_map(node => {
      match node.kind() {
        Input(name) if name != "clock" =>
          Some((name, node.signal_type().width().bits()))
        _ => None
      }
    })
  assert_eq(actual, fetched_useful_guidance_pins())
  let bundle = generate_fetched_useful_bundle()
  let harness = fetched_useful_test_artifact(bundle, "formal-harness.sv")
  assert_eq(
    sha256_hex(harness),
    "ec156bbc21c75dd04534d7f79345b8c8543ad4775427e14cb5c30cf0d1e8a62a",
  )
  assert_eq(
    sha256_hex(fetched_useful_test_artifact(bundle, "formal-dut.sv")),
    "0484aaea5c480837b59290b364e541022cd6a06a29492dc53b1fb3e787cb7352",
  )
  assert_eq(harness.split("(* anyseq *)").count(), 13)
  for (name, width) in fetched_useful_guidance_pins() {
    let declaration = if width == 1 {
      "  (* anyseq *) logic lc_\{name};\n"
    } else {
      "  (* anyseq *) logic [\{width - 1}:0] lc_\{name};\n"
    }
    assert_eq(harness.split(declaration).count(), 2)
  }
  let (_, assumptions, _, covers) = fetched_useful_property_export()
  assert_eq((assumptions.length(), covers.length()), (8, 1))
  assert_true(harness.contains("logic lc_clock = 1'b0;\n"))
  assert_true(
    harness.contains("always @($global_clock) lc_clock <= ~lc_clock;\n"),
  )
}

///|
test "fetched input guidance preserves full prefix and twelve input-only known-bit pairs" {
  let roster = fetched_useful_guidance_test_roster()
  let (scenario, mapping) = fetched_useful_guidance(roster)
  assert_eq(fetched_useful_guidance(roster), (scenario, mapping))
  assert_eq(scenario.split("\nstate ").count(), 420)
  assert_eq(scenario.split("\nassume ").count(), 5029)
  assert_true(scenario.contains("\nstate 0 1\nassume (= [lc_reset] true)\n"))
  assert_true(
    scenario.contains("\nstate 836 837\nassume (= [lc_reset] false)\n"),
  )
  assert_false(scenario.contains("\nstate 838"))
  assert_true(scenario.contains("assume (= [lc_memory_response_fault] #b00)\n"))
  assert_true(mapping.contains("GUIDED-VALUES 10056 FREE-TAIL 838..1023"))
  assert_eq(mapping.split("\nINPUT ").count(), 13)
  assert_false(scenario.contains("[lc_clock]"))
  assert_false(scenario.contains("[lc_fu_"))
  assert_false(scenario.contains("[lc_dut."))
  assert_false(scenario.contains("[lc_completion_valid]"))
  assert_false(scenario.contains("[lc_memory_request_data]"))
}

///|
test "fetched input guidance rejects internal names clock unknown widths duplicates and prefix omission" {
  let roster = fetched_useful_guidance_test_roster()
  for
    bad_name in [
      "lc_fu_owned", "lc_dut.private_state", "clock", "memory_request_data", "completion_valid",
      "config_valid",
    ] {
    fetched_useful_guidance_test_reject(
      roster.replace(old="PRE 0 reset 1", new="PRE 0 \{bad_name} 1"),
    )
  }
  for bad_bits in ["", "X", "x", "?", "00", "2", "1 extra"] {
    fetched_useful_guidance_test_reject(
      roster.replace(old="PRE 0 reset 1", new="PRE 0 reset \{bad_bits}"),
    )
  }
  fetched_useful_guidance_test_reject(
    roster.replace(old="PRE 418 reset 0", new="PRE 419 reset 0"),
  )
  fetched_useful_guidance_test_reject(
    roster.replace(old="PRE 0 reset 1\n", new=""),
  )
  fetched_useful_guidance_test_reject(roster + "\n")
  fetched_useful_guidance_test_reject(roster[:roster.length() - 1].to_owned())
}

///|
test "fetched input guidance collector binds the sealed native trajectory without hardware edits" {
  if @env.get_env_var("LUNACHIP_PHASE6_FETCHED_GUIDANCE_PRINT") == Some("1") {
    guard @env.get_env_var("LUNACHIP_PHASE6_FETCHED_GUIDANCE_INPUT_PATH")
      is Some(path) &&
      path ==
      "/Users/kq/Workspace/lunachip/artifacts/phase6-fetched-useful-20261013/inputs.txt" else {
      fail("exact sealed native trajectory path required")
    }
    let roster = @fs.read_file_to_string(path)
    assert_eq(roster.length(), 197705)
    assert_eq(
      sha256_hex(roster),
      "618670ecc2a60afc7789bc6b19d56feebaf6177a0bb940a743ebb36bb1a8c14e",
    )
    let (scenario, mapping) = fetched_useful_guidance(roster)
    for
      (path, content) in [("scenario.smtc", scenario), ("mapping.txt", mapping)] {
      println("GUIDANCE-ARTIFACT \{path} sha256 \{sha256_hex(content)}")
      println(content)
      println("END-GUIDANCE-ARTIFACT \{path}")
    }
  }
}

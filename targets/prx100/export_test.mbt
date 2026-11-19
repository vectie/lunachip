///|
test "board export is deterministic and retained portable core identity is unchanged" {
  let bundle = @prx100.export_bundle(Array8)
  assert_eq(bundle, @prx100.export_bundle(Array8))
  let mut found = false
  for artifact in bundle {
    if artifact.path == "core.lcir" {
      found = true
      let hash = @crypto.bytes_to_hex_string(
        @crypto.sha256(@utf8.encode(artifact.content)),
      )
      assert_eq(
        hash, "37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8",
      )
    }
    if artifact.path == "build.tcl" {
      assert_true(artifact.content.contains("-slack_lesser_than 0"))
      assert_true(artifact.content.contains("write_bitstream"))
    }
    if artifact.path == "prx100.xdc" {
      assert_true(
        artifact.content.contains("PACKAGE_PIN L17 [get_ports uart_rx]"),
      )
      assert_true(
        artifact.content.contains("PACKAGE_PIN L18 [get_ports uart_tx]"),
      )
    }
  }
  assert_true(found)
  assert_eq(@prx100.shell(Smoke).memories().length(), 1)
  assert_eq(@prx100.shell(Smoke).memories()[0].depth().elements(), 1024)
  let emitted = @systemverilog.emit_design(
    @ir.Design::single("prx100-cpp-port-names", @prx100.shell(Smoke)),
  )
  for mapping in emitted.manifest().mappings() {
    if mapping.kind() is InputPort || mapping.kind() is OutputPort {
      assert_true(mapping.identifier().length() <= 128)
    }
  }
}

///|
test "unsupported UART divisor fails checked elaboration" {
  try @prx100.shell(Smoke, divisor=7) catch {
    @prx100.BoardError::InvalidDivisor(7) => ()
    other => fail("unexpected error: \{other}")
  } noraise {
    _ => fail("expected rejected divisor")
  }
}

///|
fn content(
  bundle : ReadOnlyArray[@prx100.Artifact],
  path : String,
) -> String raise {
  for artifact in bundle {
    if artifact.path == path {
      return artifact.content
    }
  }
  fail("missing artifact: \{path}")
}

///|
fn restore_equality_helpers(ordinary : String, target : String) -> String raise {
  let lines = ordinary.split("\n").map(line => line.to_owned()).to_array()
  let mut restored = target
  for i = 0; i < lines.length(); {
    let prefix = "  function automatic logic "
    if lines[i].has_prefix(prefix + "lc_fn_eq_w") {
      let name = lines[i][prefix.length():lines[i].length() - 1].to_owned()
      let mut ending = i + 4
      while ending < lines.length() && lines[ending] != "  endfunction" {
        ending += 1
      }
      let native = lines[i:i + 4].to_owned().join("\n") +
        "\n    " +
        name +
        " = (a == b);\n  endfunction"
      let pieces = restored
        .split(native)
        .map(part => part.to_owned())
        .to_array()
      assert_eq(pieces.length(), 2)
      restored = pieces.join(lines[i:ending + 1].to_owned().join("\n"))
      continue ending + 1
    }
    continue i + 1
  }
  restored
}

///|
test "target RTL only normalizes input nets and equality helpers" {
  let bundle = @prx100.export_bundle(Smoke)
  for
    (name, hardware) in [
      ("phase6-fetched-concurrent-1x1-k2-two-slots", @prx100.core(Smoke)),
      ("prx100-shell", @prx100.shell(Smoke)),
    ] {
    let ordinary = @systemverilog.emit_design(
        @ir.Design::single(name, hardware),
      ).modules()[0]
    let target = content(bundle, ordinary.filename())
    assert_true(target.has_prefix("`default_nettype none\n"))
    for line in target.split("\n") {
      assert_false(line.has_prefix("  input logic "))
    }
    let restored = target
      .split("  input wire logic ")
      .map(part => part.to_owned())
      .to_array()
      .join("  input logic ")
    assert_true(
      restore_equality_helpers(ordinary.source(), restored) == ordinary.source(),
    )
    for line in ordinary.source().split("\n") {
      if line.has_prefix("  input logic ") {
        assert_true(
          target.contains("  input wire logic " + line[14:].to_owned()),
        )
      }
    }
  }
}

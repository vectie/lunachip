///|
fn run() -> Unit raise {
  match @env.args()[1:] {
    ["export-formal" | "export-formal-negative" as mode, kind, root] => {
      guard !@fs.path_exists(root) else { fail("fresh formal root required") }
      let files = @verification.formal_bundle(
        kind,
        negative=mode == "export-formal-negative",
      )
      @fs.create_dir(root)
      for file in files {
        @fs.write_string_to_file(root + "/" + file.path, file.content)
      }
      println("Exported " + kind + " formal task; mode and scope in claim.txt")
    }
    [
      "export"
      | "export-replay"
      | "export-core-replay"
      | "export-bridge-replay" as mode,
      root,
    ] => {
      guard !@fs.path_exists(root) else { fail("fresh export root required") }
      let files = match mode {
        "export" => @projection.digital_bundle()
        "export-replay" => @verification.replay_bundle()
        "export-core-replay" => @verification.core_replay_bundle()
        _ => @verification.bridge_replay_bundle()
      }
      @fs.create_dir(root)
      for file in files {
        @fs.write_string_to_file(root + "/" + file.path, file.content)
      }
      println("Exported " + mode + "; opt-in word-read portable core")
    }
    ["audit" | "audit-core" as mode, expected, actual, cycles] => {
      let count = @string.parse_int(cycles)
      guard count > 0 && count <= 1000000 else { fail("invalid cycle count") }
      if mode == "audit-core" {
        @verification.audit_core(
          @fs.read_file_to_string(expected),
          @fs.read_file_to_string(actual),
          count,
        )
      } else {
        @verification.audit(
          @fs.read_file_to_string(expected),
          @fs.read_file_to_string(actual),
          count,
        )
      }
      println("PASS independent " + mode + " RTL replay")
    }
    ["audit-bridge", expected, actual] => {
      let wanted = @fs.read_file_to_string(expected).split("\n").to_array()
      let observed = @fs.read_file_to_string(actual).split("\n").to_array()
      assert_eq(wanted.length(), observed.length())
      for i, line in wanted {
        guard line == observed[i] else {
          fail("atomic bridge mismatch at line" + (i + 1).to_string())
        }
      }
      println(
        "PASS exact atomic bridge RTL replay, including bound identities and every observed output",
      )
    }
    _ =>
      fail(
        "export|export-replay|export-bridge-replay NEW_ROOT; audit EXPECTED ACTUAL CYCLES; audit-bridge EXPECTED ACTUAL",
      )
  }
}

///|
fn main {
  run() catch {
    @wire.WireError::CdcRejected(reason) => abort("CDC: \{Repr(reason)}")
    @systemverilog.EmitError::UnreachableNode(module_name~, node~) =>
      abort("unreachable \{module_name} node\{node}")
    e => abort("ERROR: " + e.to_string())
  }
}

///|
fn run_export() -> Unit raise {
  match @env.args()[1:] {
    ["export-formal" | "export-formal-negative" as mode, root] => {
      guard !@fs.path_exists(root) else { fail("fresh formal root required") }
      let bundle = @verification.formal_bundle(
        negative=mode == "export-formal-negative",
      )
      @fs.create_dir(root)
      for file in bundle {
        @fs.write_string_to_file(root + "/" + file.path, file.content)
      }
      println("Exported bounded DDR digital safety task")
    }
    ["export" | "export-replay" as mode, root] => {
      guard !@fs.path_exists(root) else { fail("fresh export root required") }
      let bundle = if mode == "export-replay" {
        @verification.generate_bundle()
      } else {
        @ddr.export_bundle()
      }
      @fs.create_dir(root)
      for file in bundle {
        @fs.write_string_to_file(root + "/" + file.path, file.content)
      }
      println(
        "Exported standalone MoonBit DDR tester; no portable accelerator included",
      )
    }
    ["audit", expected, actual, cycles] => {
      @verification.audit(
        @fs.read_file_to_string(expected),
        @fs.read_file_to_string(actual),
        parse_cycles(cycles),
      )
      println("PASS independent DDR controller replay")
    }
    _ => fail("export|export-replay NEW_ROOT or audit EXPECTED ACTUAL CYCLES")
  }
}

///|
fn main {
  run_export() catch {
    e => abort("ERROR: " + e.to_string())
  }
}

///|
fn parse_cycles(text : String) -> Int32 raise {
  guard text.length() > 0 && text.length() <= 7 else {
    fail("invalid cycle count")
  }
  let mut value = 0
  for c in text {
    guard c is ('0'..<='9') else { fail("decimal cycle count required") }
    value = value * 10 + c.to_int() - 48
  }
  guard value > 0 && value <= 1000000 else { fail("cycle count out of range") }
  value
}

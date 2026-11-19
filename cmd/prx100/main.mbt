///|
fn main raise {
  match @env.args()[1:] {
    ["export-byte-replay" | "export-uart-replay" as mode, directory] => {
      guard !@fs.path_exists(directory) else { fail("output already exists") }
      let artifacts = if mode == "export-byte-replay" {
        @verification.generate_byte_bundle()
      } else {
        @verification.generate_uart_bundle()
      }
      @fs.create_dir(directory)
      for artifact in artifacts {
        @fs.write_string_to_file(
          directory + "/" + artifact.path,
          artifact.content,
        )
      }
      println(
        "exported composed byte-interface replay; no independent RTL pass until executed and audited",
      )
    }
    ["audit-byte-replay", expected, actual, cycles] => {
      @verification.audit_byte_replay(
        @fs.read_file_to_string(expected),
        @fs.read_file_to_string(actual),
        cycle_count(cycles),
      )
      println("PRX100 composed byte-interface replay agrees")
    }
    ["audit-uart-replay", expected, actual, cycles] => {
      @verification.audit_uart_replay(
        @fs.read_file_to_string(expected),
        @fs.read_file_to_string(actual),
        cycle_count(cycles),
      )
      println("PRX100 bit-level UART replay agrees")
    }
    [
      "export"
      | "export-byte-test" as mode,
      "smoke"
      | "array8" as choice,
      directory,
    ] => {
      guard !@fs.path_exists(directory) else {
        fail("output already exists: \{directory}")
      }
      let profile = if choice == "smoke" {
        @board.Profile::Smoke
      } else {
        Array8
      }
      let artifacts = if mode == "export" {
        @board.export_bundle(profile)
      } else {
        @board.export_byte_test(profile)
      }
      @fs.create_dir(directory)
      for artifact in artifacts {
        @fs.write_string_to_file(
          directory + "/" + artifact.path,
          artifact.content,
        )
      }
      println(
        "exported \{artifacts.length()} inputs to \{directory}; no implementation or FPGA claim",
      )
    }
    ["request", opcode, sequence, argument, data, path] => {
      let op = decimal(opcode)
      let seq = decimal(sequence)
      guard op <= 255U && seq <= 65535U else {
        fail("opcode/sequence out of range")
      }
      let bytes = @board.request(
        op.to_byte(),
        seq.to_uint16(),
        decimal(argument),
        decimal(data),
      )
      @fs.write_bytes_to_file(path, bytes)
    }
    ["reply", path] => {
      let reply = @board.decode_reply(@fs.read_file_to_bytes(path)[:])
      println(
        "opcode=\{reply.opcode} sequence=\{reply.sequence} status=\{reply.status} words=[\{reply.words.map(word => word.to_string()).join(",")}]",
      )
    }
    _ =>
      println(
        "Usage: prx100 export|export-byte-test smoke|array8 NEW_DIRECTORY | request OP SEQ ARG DATA FILE | reply FILE",
      )
  }
}

///|
fn decimal(text : String) -> UInt32 raise {
  guard text.length() > 0 && text.length() <= 10 else {
    fail("expected UInt32 decimal")
  }
  let mut value = 0UL
  for c in text {
    guard c is ('0'..<='9') else { fail("expected UInt32 decimal") }
    value = value * 10UL + c.to_int().to_uint64() - 48UL
    guard value <= 0xffffffffUL else { fail("UInt32 overflow") }
  }
  value.to_uint()
}

///|
fn cycle_count(text : String) -> Int32 raise {
  let value = decimal(text)
  guard value > 0U && value <= 0x7fffffffU else { fail("invalid cycle count") }
  value.reinterpret_as_int()
}

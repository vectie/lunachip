///|
/// Offline fixture only: never opens /dev paths and never uses a real driver.
fn main raise {
  let mode = @env.get_env_var("PBLAZE3_MOCK_MODE").unwrap_or("normal")
  if mode == "failure" {
    fail("injected XDMA failure")
  }
  if mode == "timeout" {
    println("MOCK_DIAGNOSTIC_BEFORE_TIMEOUT")
    eprintln("MOCK_STDERR_BEFORE_TIMEOUT")
    for ;; {

    }
  }
  match @env.args()[1:] {
    ["-d", device, "-a", address, "-s", size, "-c", "1", "-f", file] => {
      guard !device.has_prefix("/dev/") else {
        fail("mock refuses real devices")
      }
      let address = @string.parse_uint64(address, base=0)
      let address = if mode == "alias" { address & 0x0fffffff } else { address }
      let count = @string.parse_int(size)
      if device.strip_suffix("_h2c_0") is Some(prefix) {
        let bytes = @fs.read_file_to_bytes(file)
        guard bytes.length() == count else { fail("short input") }
        if mode == "drop-poison" &&
          bytes.length() >= 4 &&
          bytes[0:4] == b"\x00\x00\xc0\x7f" {
          return
        }
        @fs.write_bytes_to_file(
          prefix.to_owned() + ".memory-" + address.to_string(radix=16),
          bytes,
        )
      } else if device.strip_suffix("_c2h_0") is Some(prefix) {
        let bytes = @fs.read_file_to_bytes(
          prefix.to_owned() + ".memory-" + address.to_string(radix=16),
        )
        let actual = if mode == "short" { count - 1 } else { count }
        guard bytes.length() >= actual else {
          fail("mock read exceeds stored data")
        }
        @fs.write_bytes_to_file(file, bytes[:actual].to_owned())
      } else {
        fail("unexpected mock device suffix")
      }
    }
    [device, address, "w", .. tail] => {
      if mode == "ddr-only" {
        fail("DDR-only image has no LunaChip register ABI")
      }
      guard !device.has_prefix("/dev/") else {
        fail("mock refuses real devices")
      }
      let offset = @string.parse_uint64(address, base=0)
      if tail is [value] {
        if mode != "bad-count" || offset != 0x14 {
          @fs.write_string_to_file(device + ".reg-" + offset.to_string(), value)
        }
        if offset == 0x10 && mode != "drop-start" {
          @fs.write_string_to_file(device + ".started", "1")
          let sequence_file = device + ".reg-56"
          let before = if @fs.path_exists(sequence_file) {
            @string.parse_uint64(@fs.read_file_to_string(sequence_file), base=0)
          } else {
            0
          }
          let delta : UInt64 = if mode == "jump-start" { 2 } else { 1 }
          let after = (before + delta) & 0xffffffff
          @fs.write_string_to_file(sequence_file, after.to_string())
          @fs.write_string_to_file(device + ".polls", "0")
          if mode == "launch-reset" {
            @fs.write_string_to_file(sequence_file, "0")
          }
          if mode == "launch-bad-count" {
            @fs.write_string_to_file(device + ".reg-20", "2")
          }
          if mode != "delayed-start" {
            store_results(device, mode)
          }
        }
      } else if tail.length() == 0 {
        let value : UInt64 = match offset {
          0 => if mode == "wrong-id" { 0 } else { 0x50423330 }
          4 => 0x10001
          8 => status_word(device, mode)
          0x80 => 0x80000000
          0x84 => 0
          0x88 => 31
          0x8c => 1
          0x38 if mode == "torn-once" || mode == "torn-always" => {
            let reads = stored_number(device + ".sequence-reads")
            let value = stored_number(device + ".reg-56")
            @fs.write_string_to_file(
              device + ".sequence-reads",
              (reads + 1).to_string(),
            )
            if (mode == "torn-always" && reads % 2 == 1) ||
              (mode == "torn-once" && reads == 1) {
              @fs.write_string_to_file(
                device + ".reg-56",
                (value + 1).to_string(),
              )
              value + 1
            } else {
              value
            }
          }
          _ => {
            let stored = device + ".reg-" + offset.to_string()
            if @fs.path_exists(stored) {
              @string.parse_uint64(@fs.read_file_to_string(stored), base=0)
            } else {
              0
            }
          }
        }
        println(
          "Read 32-bit value at address 0x\{offset.to_string(radix=16)} (0x0): 0x\{value.to_string(radix=16)}",
        )
      } else {
        fail("invalid reg_rw argument count")
      }
    }
    _ => fail("unsupported mock XDMA command")
  }
}

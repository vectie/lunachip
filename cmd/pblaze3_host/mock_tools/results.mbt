///|
priv struct ResultRegion {
  address : UInt32
  words : Array[UInt32]
} derive(FromJson)

///|
/// A test-owned result schedule, applied only after the mock accepts START.
fn store_results(device : String, mode : String) -> Unit raise {
  guard @env.get_env_var("PBLAZE3_MOCK_RESULTS") is Some(path) else { return }
  if path.is_empty() {
    return
  }
  guard device.strip_suffix("_user") is Some(prefix) else {
    fail("mock result device must be user BAR")
  }
  let regions : Array[ResultRegion] = @json.from_json(
    @json.parse(@fs.read_file_to_string(path)),
  )
  if mode == "missing-store" {
    return
  }
  for region in regions {
    let destination = prefix.to_owned() +
      ".memory-" +
      region.address.to_string(radix=16)
    let old = @fs.read_file_to_bytes(destination)
    guard old.length() == region.words.length() * 4 else {
      fail("mock output was not initialized to the expected shape")
    }
    let bytes = Bytes::makei(old.length(), i => {
      if mode == "partial-store" && i >= old.length() - 4 {
        old[i]
      } else {
        let word = region.words[i / 4]
        let word = if mode == "corrupt-store" && i < 4 {
          word ^ 0x00400000
        } else {
          word
        }
        (word >> (i % 4 * 8)).to_byte()
      }
    })
    @fs.write_bytes_to_file(destination, bytes)
  }
}

///|
fn stored_number(path : String, default~ : UInt64 = 0) -> UInt64 raise {
  if @fs.path_exists(path) {
    @string.parse_uint64(@fs.read_file_to_string(path), base=0)
  } else {
    default
  }
}

///|
fn status_word(device : String, mode : String) -> UInt64 raise {
  if mode == "ddr-smoke" {
    return 7
  }
  if mode == "ddr-uncalibrated" {
    return 6
  }
  if !@fs.path_exists(device + ".started") {
    return 1
  }
  match mode {
    "launch-fault" => 9
    "launch-health-loss" => 0
    "delayed-start" => {
      let polls = stored_number(device + ".polls")
      @fs.write_string_to_file(device + ".polls", (polls + 1).to_string())
      if polls < 2 {
        3
      } else {
        store_results(device, mode)
        5
      }
    }
    _ => 5
  }
}

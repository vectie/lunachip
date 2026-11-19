///|
pub fn dma_command(
  manifest : Manifest,
  write~ : Bool,
  device : String,
  address : UInt64,
  length : Int32,
  file : String,
) -> Command raise HostError {
  check_chunk(length)
  if length == 0 {
    raise InvalidChunk(length~)
  }
  manifest.check_range(address, length.to_uint64())
  {
    program: if write {
      "dma_to_device"
    } else {
      "dma_from_device"
    },
    arguments: [
      "-d",
      device,
      "-a",
      "0x" + address.to_string(radix=16),
      "-s",
      length.to_string(),
      "-c",
      "1",
      "-f",
      file,
    ],
    expected_bytes: length,
    timeout_ms: 10000,
  }
}

///|
/// Read registers through the XDMA user BAR. A write is an explicit operation.
pub fn register_command(
  manifest : Manifest,
  device : String,
  offset : UInt64,
  value : UInt32?,
) -> Command raise HostError {
  manifest.check_register(offset)
  let arguments = [device, "0x" + offset.to_string(radix=16), "w"]
  if value is Some(word) {
    arguments.push("0x" + word.to_string(radix=16))
  }
  { program: "reg_rw", arguments, expected_bytes: 4, timeout_ms: 2000, }
}

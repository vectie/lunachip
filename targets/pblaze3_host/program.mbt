///|
/// Little-endian 16-word instructions, matching the portable Qwen controller.
pub fn program_commands(
  manifest : Manifest,
  device : String,
  bytes : Bytes,
) -> Array[Command] raise HostError {
  if bytes.length() == 0 || bytes.length() % 64 != 0 || bytes.length() > 131072 {
    raise InvalidChunk(length=bytes.length())
  }
  window_commands(manifest, device, bytes, 0x20000)
}

///|
pub fn scratch_commands(
  manifest : Manifest,
  device : String,
  bytes : Bytes,
) -> Array[Command] raise HostError {
  if bytes.length() == 0 || bytes.length() % 4 != 0 || bytes.length() > 131072 {
    raise InvalidChunk(length=bytes.length())
  }
  window_commands(manifest, device, bytes, 0x40000)
}

///|
fn window_commands(
  manifest : Manifest,
  device : String,
  bytes : Bytes,
  base : UInt64,
) -> Array[Command] raise HostError {
  let commands = []
  for index in 0..<(bytes.length() / 4) {
    let offset = index * 4
    let word = bytes[offset].to_uint() |
      (bytes[offset + 1].to_uint() << 8) |
      (bytes[offset + 2].to_uint() << 16) |
      (bytes[offset + 3].to_uint() << 24)
    commands.push(
      register_command(manifest, device, base + offset.to_uint64(), Some(word)),
    )
  }
  commands
}

///|
pub fn start_commands(
  manifest : Manifest,
  device : String,
  count : Int32,
) -> Array[Command] raise HostError {
  if count <= 0 || count > 2048 {
    raise InvalidChunk(length=count)
  }
  [
    register_command(manifest, device, 0x14, Some(count.reinterpret_as_uint())),
    register_command(manifest, device, 0x10, Some(1)),
  ]
}

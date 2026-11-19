///|
/// Host-visible board contract. The 2 GiB aperture is physically verified;
/// this manifest alone does not establish the live image or device identity.
pub(all) struct Manifest {
  schema : Int32
  target : String
  part : String
  capacity_bytes : UInt64
  ddr_base : UInt64
  axi_data_bits : Int32
  axi_lite_translation : UInt64
  register_window_bytes : UInt64
  abi_version : UInt32
} derive(Debug, Eq, ToJson, FromJson)

///|
pub extend Manifest with @debug.Debug::{to_repr}

///|
pub extend Manifest with Eq::{equal, not_equal}

///|
pub extend Manifest with ToJson::{to_json}

///|
pub extend Manifest with @json.FromJson::{from_json}

///|
/// Errors are reported before an invalid request reaches a transport.
pub(all) suberror HostError {
  InvalidManifest(field~ : String)
  InvalidRange(address~ : UInt64, length~ : UInt64)
  InvalidChunk(length~ : Int32)
  InvalidRegister(offset~ : UInt64)
  ShortIo(operation~ : String, address~ : UInt64)
  InvalidIoCount(operation~ : String, actual~ : Int32, requested~ : Int32)
  DataMismatch(address~ : UInt64, expected~ : Byte, actual~ : Byte)
  NonfiniteFloat(index~ : Int32, reference~ : Bool)
  FloatMismatch(index~ : Int32, expected~ : Double, actual~ : Double)
  TransportFailure(message~ : String)
} derive(Debug)

///|
pub extend HostError with @debug.Debug::{to_repr}

///|
/// Synchronous callbacks; real transports must bound blocking I/O externally.
/// Returning a short positive count is permitted. Zero progress is an error.
pub(all) struct Transport {
  read : (UInt64, Int32) -> Bytes raise HostError
  write : (UInt64, Bytes) -> Int32 raise HostError
}

///|
/// One bounded userspace-tool operation, with separate executable and arguments.
pub(all) struct Command {
  program : String
  arguments : Array[String]
  expected_bytes : Int32
  timeout_ms : Int32
} derive(Debug, ToJson)

///|
pub extend Command with @debug.Debug::{to_repr}

///|
pub extend Command with ToJson::{to_json}

///|
pub fn default_manifest() -> Manifest {
  {
    schema: 1,
    target: "pblaze3-2gib",
    part: "xc7k325tffg900-2",
    capacity_bytes: 0x80000000,
    ddr_base: 0,
    axi_data_bits: 128,
    axi_lite_translation: 0x40000000,
    register_window_bytes: 0x100000,
    abi_version: 0x00010001,
  }
}

///|
/// Reject mismatched 4GiB vendor manifests instead of silently clipping them.
pub fn Manifest::validate(self : Manifest) -> Unit raise HostError {
  let expected = default_manifest()
  if self.schema != expected.schema {
    raise InvalidManifest(field="schema")
  }
  if self.target != expected.target {
    raise InvalidManifest(field="target")
  }
  if self.part != expected.part {
    raise InvalidManifest(field="part")
  }
  if self.capacity_bytes != expected.capacity_bytes {
    raise InvalidManifest(field="capacity_bytes")
  }
  if self.ddr_base != expected.ddr_base {
    raise InvalidManifest(field="ddr_base")
  }
  if self.axi_data_bits != expected.axi_data_bits {
    raise InvalidManifest(field="axi_data_bits")
  }
  if self.axi_lite_translation != expected.axi_lite_translation {
    raise InvalidManifest(field="axi_lite_translation")
  }
  if self.register_window_bytes != expected.register_window_bytes {
    raise InvalidManifest(field="register_window_bytes")
  }
  if self.abi_version != expected.abi_version {
    raise InvalidManifest(field="abi_version")
  }
}

///|
/// Length may be zero at the exclusive end. Subtraction avoids overflow.
pub fn Manifest::check_range(
  self : Manifest,
  address : UInt64,
  length : UInt64,
) -> Unit raise HostError {
  self.validate()
  if address < self.ddr_base || address - self.ddr_base > self.capacity_bytes {
    raise InvalidRange(address~, length~)
  }
  let available = self.capacity_bytes - (address - self.ddr_base)
  if length > available {
    raise InvalidRange(address~, length~)
  }
}

///|
/// XDMA's user device uses BAR-relative offsets, NOT translated AXI addresses.
pub fn Manifest::check_register(
  self : Manifest,
  offset : UInt64,
) -> Unit raise HostError {
  self.validate()
  if offset % 4 != 0 || offset >= self.register_window_bytes {
    raise InvalidRegister(offset~)
  }
}

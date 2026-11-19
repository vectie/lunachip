///|
/// GPIO channel 2 in the named ddr-smoke image; this is not a device identity.
pub(all) struct SmokeStatus {
  calibrated : Bool
  link_up : Bool
  ui_reset_released : Bool
  healthy : Bool
} derive(Debug, ToJson)

///|
pub extend SmokeStatus with @debug.Debug::{to_repr}

///|
pub extend SmokeStatus with ToJson::{to_json}

///|
pub fn decode_smoke_status(word : UInt32) -> SmokeStatus raise HostError {
  if (word & 0xfffffff8) != 0 {
    raise InvalidManifest(field="smoke_status_reserved")
  }
  {
    calibrated: (word & 1) != 0,
    link_up: (word & 2) != 0,
    ui_reset_released: (word & 4) != 0,
    healthy: word == 7,
  }
}

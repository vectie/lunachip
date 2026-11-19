///|
/// VendorBaseline reproduces the supplied 4GiB configuration for comparison.
/// The other modes target the user's provisional eight 256MiB components.
pub(all) enum BuildMode {
  VendorBaseline
  DdrSmoke
  Accelerator
  DdrSmokeIla
  AcceleratorIla
  DdrStatusIla
  DdrMigIla
  DdrXdmaIla
  AcceleratorCoreIla
} derive(Eq, @debug.Debug)

///|
pub(all) suberror BoardError {
  InvalidProfile(String)
  InvalidVendorInput(String)
} derive(Eq, @debug.Debug)

///|
pub fn parse_mode(text : String) -> BuildMode raise BoardError {
  match text {
    "vendor-baseline" => VendorBaseline
    "ddr-smoke" => DdrSmoke
    "accelerator" => Accelerator
    "ddr-smoke-ila" => DdrSmokeIla
    "accelerator-ila" => AcceleratorIla
    "ddr-status-ila" => DdrStatusIla
    "ddr-mig-ila" => DdrMigIla
    "ddr-xdma-ila" => DdrXdmaIla
    "accelerator-core-ila" => AcceleratorCoreIla
    _ => raise InvalidProfile(text)
  }
}

///|
pub fn BuildMode::name(self : BuildMode) -> String {
  match self {
    VendorBaseline => "vendor-baseline"
    DdrSmoke => "ddr-smoke"
    Accelerator => "accelerator"
    DdrSmokeIla => "ddr-smoke-ila"
    AcceleratorIla => "accelerator-ila"
    DdrStatusIla => "ddr-status-ila"
    DdrMigIla => "ddr-mig-ila"
    DdrXdmaIla => "ddr-xdma-ila"
    AcceleratorCoreIla => "accelerator-core-ila"
  }
}

///|
pub fn BuildMode::memory_bytes(self : BuildMode) -> UInt64 {
  if self == VendorBaseline {
    4294967296UL
  } else {
    2147483648UL
  }
}

///|
pub fn BuildMode::vivado_release(self : BuildMode) -> String {
  if self.is_diagnostic() {
    "2026.1"
  } else if self == VendorBaseline {
    "2024.2"
  } else {
    "2025.2"
  }
}

///|
/// Physical identity and the provisional component model are deliberately
/// distinct. This manifest never claims calibrated or verified hardware.
pub fn manifest(mode : BuildMode) -> Json {
  manifest_validated(mode, mode.vivado_release())
}

///|
pub fn manifest_for_release(
  mode : BuildMode,
  release : String,
) -> Json raise BoardError {
  validate_release(mode, release)
  manifest_validated(mode, release)
}

///|
fn validate_release(
  mode : BuildMode,
  release : String,
) -> Unit raise BoardError {
  let accepted = match (mode, release) {
    (VendorBaseline, "2024.2") => true
    // Both installed catalogs were queried on 2026-10-26. Their required
    // physical IP VLNVs match; exact release selection and pins stay separate.
    (DdrSmoke | Accelerator, "2025.2" | "2026.1") => true
    (
      DdrSmokeIla
      | AcceleratorIla
      | DdrStatusIla
      | DdrMigIla
      | DdrXdmaIla
      | AcceleratorCoreIla,
      "2026.1",
    ) => true
    _ => false
  }
  guard accepted else {
    raise InvalidProfile(
      "unsupported mode/tool release: \{mode.name()}/\{release}",
    )
  }
}

///|
fn manifest_validated(mode : BuildMode, release : String) -> Json {
  if mode.is_diagnostic() {
    return diagnostic_board_manifest(mode, release)
  }
  {
    "schema": "lunachip.pblaze3-board/v1",
    "mode": mode.name(),
    "part": "xc7k325tffg900-2",
    "vivado_release": release,
    "memory_bytes": Json(mode.memory_bytes()),
    "physical_component_identity_verified": false,
    "provisional_component_model": if mode == VendorBaseline {
      "MT41K512M8XX-125"
    } else {
      "MT41K256M8XX-125"
    },
    "capacity_basis": if mode == VendorBaseline {
      "unmodified vendor 4GiB configuration, not the requested board capacity"
    } else {
      "user instruction START WITH 8*256MiB; x8 organization assumed from vendor pin map"
    },
    "ddr_data_bits": 64,
    "ddr_ecc": false,
    "mig_axi_data_bits": 128,
    "mig_axi_id_bits": if mode == Accelerator {
      5
    } else {
      4
    },
    "mig_ui_mhz": 200,
    "pcie_generation": 2,
    "pcie_lanes": 8,
    "xdma_axi_mhz": 250,
    "transport_reset": {
      "clock_source": "board oscillator MMCM third output; independent of XDMA",
      "clock_mhz": 50,
      "async_assert_sync_release_stages": 3,
      "healthy_edges_before_release": 128,
      "minimum_required_pulse_ns": 1500,
      "calibration_loss_is_reset": false,
    },
    "xdma_ip_version": if mode == VendorBaseline {
      "4.1"
    } else {
      "4.2"
    },
    "core_period_ns": 30,
    "control_axi_base": "0x40000000",
    "control_aperture_bytes": if mode == Accelerator {
      1048576
    } else {
      65536
    },
    "smoke_status": if mode == DdrSmoke {
      {
        "bar_offset": "0x8",
        "access": "read-only",
        "calibrated_mask": 1,
        "pcie_link_up_mask": 2,
        "ui_reset_released_mask": 4,
        "ready_value": 7,
        "independent_flag_synchronizer_stages": 3,
      }
    } else {
      Json::null()
    },
    "qualified_on_board": false,
    "programming_performed": false,
    "vendor_warning": "supplied README reports intermittent errors; no cause established",
  }
}

///|
/// The archived MIG file starts with a corrupt EF BB 3F prefix. Normalize only
/// that known byte sequence before UTF-8 decoding, keeping original bytes in
/// the provenance archive. Unexpected prefixes fail instead of guessing.
pub fn normalize_vendor_xml(bytes : Bytes) -> String raise BoardError {
  guard bytes is [0xef, 0xbb, 0x3f, ..] else {
    raise InvalidVendorInput("unexpected vendor XML prefix")
  }
  let xml = @utf8.decode(bytes[3:]) catch {
    _ => raise InvalidVendorInput("invalid UTF-8 after known prefix")
  }
  guard xml.has_prefix("<?xml ") else {
    raise InvalidVendorInput("missing XML declaration after known prefix")
  }
  xml
}

///|
/// Generate a separate MIG input; the retained vendor bytes stay immutable.
/// Capacity, row geometry and AXI width change together. Unused ninth-byte
/// pins and A15 are removed. 2Gb timing values remain provisional until the
/// physical part marking and electrical profile are checked.
pub fn mig_project(
  vendor : String,
  mode : BuildMode,
) -> String raise BoardError {
  let mode = mode.production_mode()
  for
    marker in [
      "<MemoryDevice>DDR3_SDRAM/Components/MT41K512M8XX-125</MemoryDevice>", "<RowAddress>16</RowAddress>",
      "<DataWidth>64</DataWidth>", "<ECC>Disabled</ECC>", "<C0_MEM_SIZE>4294967296</C0_MEM_SIZE>",
      "<C0_S_AXI_ADDR_WIDTH>32</C0_S_AXI_ADDR_WIDTH>", "<C0_S_AXI_ID_WIDTH>4</C0_S_AXI_ID_WIDTH>",
    ] {
    guard vendor.contains(marker) else { raise InvalidVendorInput(marker) }
  }
  if mode == VendorBaseline {
    return vendor
  }
  let out = StringBuilder()
  for original in vendor.split("\n") {
    let line = original.to_owned().replace(old="\r", new="")
    let unused = line.contains("name=\"ddr3_addr[15]\"") ||
      line.contains("name=\"ddr3_dm[8]\"") ||
      line.contains("name=\"ddr3_dqs_p[8]\"") ||
      line.contains("name=\"ddr3_dqs_n[8]\"") ||
      [64, 65, 66, 67, 68, 69, 70, 71]
      .iter()
      .any(i => line.contains("name=\"ddr3_dq[\{i}]\""))
    if unused {
      continue
    }
    let transformed = line
      .replace(old="MT41K512M8XX-125", new="MT41K256M8XX-125")
      .replace(
        old="<RowAddress>16</RowAddress>",
        new="<RowAddress>15</RowAddress>",
      )
      .replace(
        old="<C0_MEM_SIZE>4294967296</C0_MEM_SIZE>",
        new="<C0_MEM_SIZE>2147483648</C0_MEM_SIZE>",
      )
      .replace(
        old="<C0_S_AXI_ADDR_WIDTH>32</C0_S_AXI_ADDR_WIDTH>",
        new="<C0_S_AXI_ADDR_WIDTH>31</C0_S_AXI_ADDR_WIDTH>",
      )
      .replace(old="trfc=\"260\"", new="trfc=\"160\"")
    // Two interconnect slave interfaces prefix one master-index bit to the
    // four-bit XDMA transaction ID. The accelerator itself uses no ID bits.
    out.write_string(
      if mode == Accelerator {
        transformed.replace(
          old="<C0_S_AXI_ID_WIDTH>4</C0_S_AXI_ID_WIDTH>",
          new="<C0_S_AXI_ID_WIDTH>5</C0_S_AXI_ID_WIDTH>",
        )
      } else {
        transformed
      },
    )
    out.write_string("\n")
  }
  out.to_string()
}

///|
pub extend BuildMode with Eq::{equal, not_equal}

///|
pub extend BuildMode with @debug.Debug::{to_repr}

///|
pub extend BoardError with @debug.Debug::{to_repr}

///|
pub extend BoardError with Eq::{equal, not_equal}

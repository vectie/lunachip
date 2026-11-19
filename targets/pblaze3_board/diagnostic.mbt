///|
pub fn BuildMode::is_diagnostic(self : BuildMode) -> Bool {
  self
  is (DdrSmokeIla
  | AcceleratorIla
  | DdrStatusIla
  | DdrMigIla
  | DdrXdmaIla
  | AcceleratorCoreIla)
}

///|
pub fn BuildMode::production_mode(self : BuildMode) -> BuildMode {
  match self {
    DdrSmokeIla | DdrStatusIla | DdrMigIla | DdrXdmaIla => DdrSmoke
    AcceleratorIla | AcceleratorCoreIla => Accelerator
    _ => self
  }
}

///|
priv struct CaptureDomain {
  name : String
  clock : String
  mhz : Int32
  probes : Array[Array[(String, String, Int32)]]
}

///|
fn axi_capture(
  name : String,
  clock : String,
  mhz : Int32,
  prefix : String,
  address : Int32,
  id : Int32,
  burst : Bool,
  status : Array[(String, String, Int32)],
  control : String?,
) -> CaptureDomain {
  let probes : Array[Array[(String, String, Int32)]] = []
  for channel in ["aw", "w", "b", "ar", "r"] {
    let fields : Array[(String, String, Int32)] = []
    let signals = match channel {
      "aw" | "ar" => {
        let result = [(channel + "valid", 1), (channel + "ready", 1)]
        if id > 0 {
          result.push((channel + "id", id))
        }
        result.push((channel + "addr", address))
        result.push((channel + "len", 8))
        result.push((channel + "size", 3))
        if burst {
          result.push((channel + "burst", 2))
        }
        result
      }
      "w" =>
        [
          ("wvalid", 1),
          ("wready", 1),
          ("wlast", 1),
          ("wstrb", 16),
          ("wdata", 128),
        ]
      "b" => {
        let result = [("bvalid", 1), ("bready", 1), ("bresp", 2)]
        if id > 0 {
          result.push(("bid", id))
        }
        result
      }
      _ => {
        let result = [("rvalid", 1), ("rready", 1), ("rlast", 1), ("rresp", 2)]
        if id > 0 {
          result.push(("rid", id))
        }
        result.push(("rdata", 128))
        result
      }
    }
    for (signal, width) in signals {
      fields.push((signal, prefix + signal, width))
    }
    if channel == "aw" {
      for field in status {
        fields.push(field)
      }
    }
    if control is Some(ctrl) {
      let extra = match channel {
        "aw" =>
          [
            ("awvalid", 1),
            ("awready", 1),
            ("awaddr", 32),
            ("wvalid", 1),
            ("wready", 1),
            ("wdata", 32),
            ("wstrb", 4),
            ("bvalid", 1),
            ("bready", 1),
            ("bresp", 2),
          ]
        "ar" =>
          [
            ("arvalid", 1),
            ("arready", 1),
            ("araddr", 32),
            ("rvalid", 1),
            ("rready", 1),
            ("rdata", 32),
            ("rresp", 2),
          ]
        _ => []
      }
      for (signal, width) in extra {
        fields.push(("ctrl_" + signal, ctrl + signal, width))
      }
    }
    probes.push(fields)
  }
  { name, clock, mhz, probes, }
}

///|
fn capture_domains(mode : BuildMode) -> Array[CaptureDomain] {
  let accelerator = mode.production_mode() == Accelerator
  let domains = [
    {
      name: "ila_reset50",
      clock: "diagnostic_clock/clock50",
      mhz: 50,
      probes: [[("status", "diagnostic_status/synced", 9)]],
    },
    axi_capture(
      "ila_mig200",
      "mig/ui_clk",
      200,
      "mig/s_axi_",
      31,
      if accelerator {
        5
      } else {
        4
      },
      true,
      [
        ("calibrated", "mig/init_calib_complete", 1),
        ("ui_reset", "mig/ui_clk_sync_rst", 1),
        ("axi_reset_n", "reset_ui/peripheral_aresetn", 1),
      ],
      None,
    ),
    axi_capture(
      "ila_xdma250",
      "xdma/axi_aclk",
      250,
      "xdma/m_axi_",
      64,
      4,
      true,
      [
        ("axi_reset_n", "xdma/axi_aresetn", 1),
        ("link_up", "xdma/user_lnk_up", 1),
      ],
      Some("xdma/m_axil_"),
    ),
  ]
  if mode == DdrStatusIla {
    return [domains[0]]
  }
  if mode == DdrMigIla {
    return [domains[1]]
  }
  if mode == DdrXdmaIla {
    return [domains[2]]
  }
  if accelerator {
    domains.push(
      axi_capture(
        "ila_core33",
        "clocks/core_clk",
        33,
        "accelerator/m_axi_",
        32,
        0,
        true,
        [
          ("core_reset", "accelerator/reset", 1),
          ("memory_healthy", "accelerator/memory_healthy", 1),
        ],
        Some("accelerator/s_axi_"),
      ),
    )
  }
  if mode == AcceleratorCoreIla {
    return [domains[3]]
  }
  domains
}

///|
fn has_status_capture(mode : BuildMode) -> Bool {
  capture_domains(mode).any(domain => domain.name == "ila_reset50")
}

///|
/// Capture layout is generated from the same ordered fields as BD wiring.
/// Fields are packed least-significant first; captures across ILAs are not
/// simultaneous. The status vector contains independent synchronized levels.
pub fn diagnostic_manifest(mode : BuildMode) -> Json raise BoardError {
  guard mode.is_diagnostic() else {
    raise InvalidProfile("diagnostic mode required")
  }
  let domains : Array[Json] = capture_domains(mode).map(domain => {
    let probes : Array[Json] = domain.probes.mapi((index, fields) => {
      let mut offset = 0
      let entries = fields.map(field => {
        let (name, pin, width) = field
        let entry : Json = {
          "name": name,
          "bd_pin": pin,
          "capture_bd_pin": if domain.name == "ila_reset50" {
            pin
          } else {
            domain.name + "_monitor/" + name
          },
          "lsb": offset,
          "width": width,
        }
        offset += width
        entry
      })
      { "name": "probe\{index}", "width": offset, "fields": entries }
    })
    {
      "name": domain.name,
      "clock_bd_pin": domain.clock,
      "nominal_mhz": domain.mhz,
      "period_ns": if domain.mhz == 33 {
        30
      } else {
        1000 / domain.mhz
      },
      "probe_driver_bd_cell": if domain.name == "ila_reset50" {
        "ila_reset50_probe0"
      } else {
        domain.name + "_monitor"
      },
      "depth": 1024,
      "input_pipeline_stages": 1,
      "probes": probes,
    }
  })
  {
    "schema": "lunachip.pblaze3-ila/v1",
    "mode": mode.name(),
    "ila_vlnv": "xilinx.com:ip:ila:6.2",
    "monitor_type": "Native",
    "hub_clock_bd_pin": "diagnostic_clock/clock50",
    "hub_clock_hz": 50000000,
    "cores": domains,
    "status_bits_lsb_first": if has_status_capture(mode) {
      Json([
        "pcie_perst_n", "source_mmcm_locked", "mig_mmcm_locked", "mig_ui_reset",
        "calibrated", "xdma_axi_reset_n", "pcie_link_up", "transport_healthy", "supervisor_released_n",
      ])
    } else {
      Json(([] : Array[String]))
    },
    "status_sync_stages": if has_status_capture(mode) {
      3
    } else {
      0
    },
    "limitations": if has_status_capture(mode) {
      "Requires physical board oscillator/JTAG. Status flags are independent delayed levels, not coherent snapshots or guaranteed short-pulse capture. Final transport reset is inferred from its separately observed operands. AXI payload is sampled only in its own domain. Full AXI profiles require stable UI/XDMA/core clocks for debug communication; use ddr-status-ila when those clocks are absent. No hardware capture has been performed."
    } else {
      "Requires physical board oscillator/JTAG and the selected native AXI capture clock running. The debug hub uses independent raw50MHz; payload and accompanying native-domain flags are sampled only in the selected domain. This image has no raw-status synchronizer or status ILA and does not observe the separate transport-reset operands. Use ddr-status-ila for startup or when this capture clock is absent. No hardware capture has been performed."
    },
    "qualified_on_board": false,
  }
}

///|
fn diagnostic_board_manifest(mode : BuildMode, release : String) -> Json {
  let base = manifest_validated(mode.production_mode(), release)
  if base is Object(fields) {
    fields["mode"] = Json(mode.name())
    fields["production_mode"] = Json(mode.production_mode().name())
    fields["diagnostic_manifest"] = Json("diagnostic.json")
    fields["diagnostic_capture_performed"] = Json(false)
  }
  base
}

///|
pub fn diagnostic_status_wrapper() -> String {
  (
    #|module pblaze3_diagnostic_status (
    #|  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clock50 CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clock50, FREQ_HZ 50000000" *)
    #|  input wire clock50,
    #|  input wire [8:0] flags,
    #|  output wire [8:0] synced
    #|);
    #|  xpm_cdc_array_single #(
    #|    .DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SIM_ASSERT_CHK(1),
    #|    .SRC_INPUT_REG(0), .WIDTH(9)
    #|  ) flags_cdc (
    #|    .src_clk(1'b0), .src_in(flags), .dest_clk(clock50), .dest_out(synced)
    #|  );
    #|endmodule
    #|
  )
}

///|
/// Diagnostic profiles share one physical oscillator input buffer with the
/// existing Clocking Wizard, whose input buffering is explicitly disabled.
pub fn diagnostic_clock_wrapper() -> String {
  (
    #|module pblaze3_diagnostic_clock (
    #|  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 oscillator CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME oscillator, FREQ_HZ 50000000" *)
    #|  input wire oscillator,
    #|  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clock50 CLK", X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clock50, FREQ_HZ 50000000" *)
    #|  output wire clock50
    #|);
    #|  wire buffered_input;
    #|  IBUF oscillator_input(.I(oscillator), .O(buffered_input));
    #|  BUFG oscillator_global(.I(buffered_input), .O(clock50));
    #|endmodule
    #|
  )
}

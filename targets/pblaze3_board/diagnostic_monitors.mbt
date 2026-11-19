///|
fn status_field(name : String) -> Bool {
  [
    "calibrated", "ui_reset", "axi_reset_n", "link_up", "core_reset", "memory_healthy",
  ].contains(name)
}

///|
fn monitor_interface_name(field : String) -> String? {
  if field.has_prefix("ctrl_") {
    Some("MON_CTRL")
  } else if status_field(field) {
    None
  } else {
    Some("MON_AXI")
  }
}

///|
fn monitor_interface_signal(field : String) -> String {
  (if field.has_prefix("ctrl_") { field[5:].to_owned() } else { field }).to_upper()
}

///|
/// Inputs only: joining an existing interface as MONITOR must never replace
/// its functional master/slave endpoints. Individual BD constituent-pin taps
/// are deliberately forbidden because Vivado can disconnect the interface.
pub fn diagnostic_axi_wrappers(mode : BuildMode) -> Array[(String, String)] {
  let result : Array[(String, String)] = []
  for domain in capture_domains(mode) {
    if domain.name == "ila_reset50" {
      continue
    }
    let out = StringBuilder()
    let module_name = "pblaze3_" + domain.name + "_monitor"
    let has_control = domain.name != "ila_mig200"
    let buses = if has_control { "MON_AXI:MON_CTRL" } else { "MON_AXI" }
    let hz = if domain.mhz == 33 { 33333333 } else { domain.mhz * 1000000 }
    out.write_string(
      "module \{module_name}(\n  (* X_INTERFACE_INFO = \"xilinx.com:signal:clock:1.0 clock CLK\", X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME clock, FREQ_HZ \{hz}, ASSOCIATED_BUSIF \{buses}\" *)\n  input wire clock,\n",
    )
    for fields in domain.probes {
      for (field, _, width) in fields {
        if monitor_interface_name(field) is Some(interface) {
          let signal = monitor_interface_signal(field)
          let extra = if signal == "AWVALID" {
            let control = interface == "MON_CTRL"
            let address = if control || domain.name == "ila_core33" {
              32
            } else if domain.name == "ila_mig200" {
              31
            } else {
              64
            }
            let id = if control || domain.name == "ila_core33" {
              0
            } else if domain.name == "ila_mig200" &&
              mode.production_mode() == Accelerator {
              5
            } else {
              4
            }
            let protocol = if control { "AXI4LITE" } else { "AXI4" }
            let data = if control { 32 } else { 128 }
            let narrow = if !control &&
              mode.production_mode() == Accelerator &&
              domain.name != "ila_xdma250" {
              1
            } else {
              0
            }
            ", X_INTERFACE_MODE = \"monitor\", X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME \{interface}, PROTOCOL \{protocol}, ADDR_WIDTH \{address}, DATA_WIDTH \{data}, ID_WIDTH \{id}, SUPPORTS_NARROW_BURST \{narrow}\""
          } else {
            ""
          }
          out.write_string(
            "  (* X_INTERFACE_INFO = \"xilinx.com:interface:aximm:1.0 \{interface} \{signal}\"\{extra} *)\n",
          )
        }
        let range = if width == 1 { "" } else { "[\{width - 1}:0] " }
        out.write_string("  input wire \{range}\{field},\n")
      }
    }
    for index, fields in domain.probes {
      let width = fields.fold(init=0, (sum, field) => sum + field.2)
      let comma = if index == domain.probes.length() - 1 { "" } else { "," }
      out.write_string("  output wire [\{width - 1}:0] probe\{index}\{comma}\n")
    }
    out.write_string(");\n")
    for index, fields in domain.probes {
      let names = fields.map(field => field.0)
      names.rev_in_place()
      out.write_string("  assign probe\{index} = {" + names.join(", ") + "};\n")
    }
    out.write_string("endmodule\n")
    result.push((module_name + ".sv", out.to_string()))
  }
  result
}

///|
fn diagnostic_bus_monitor_tcl(domain : CaptureDomain) -> String {
  let out = StringBuilder()
  let instance = domain.name + "_monitor"
  out.write_string(
    "create_bd_cell -type module -reference pblaze3_\{instance} \{instance}\nwire \{domain.clock} \{instance}/clock\n",
  )
  let source = match domain.name {
    "ila_mig200" => "mig/S_AXI"
    "ila_xdma250" => "xdma/M_AXI"
    _ => "accelerator/M_AXI_DDR"
  }
  out.write_string(
    "pblaze_attach_monitor \{source} \{instance}/MON_AXI $diagnostic_report\n",
  )
  if domain.name != "ila_mig200" {
    let control = if domain.name == "ila_xdma250" {
      "xdma/M_AXI_LITE"
    } else {
      "accelerator/S_AXI_CTRL"
    }
    out.write_string(
      "pblaze_attach_monitor \{control} \{instance}/MON_CTRL $diagnostic_report\n",
    )
  }
  for fields in domain.probes {
    for (name, source, _) in fields {
      if status_field(name) {
        out.write_string("wire \{source} \{instance}/\{name}\n")
      }
    }
  }
  out.to_string()
}

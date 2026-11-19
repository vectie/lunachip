///|
fn diagnostic_connect_tcl(mode : BuildMode) -> String {
  let out = StringBuilder()
  out.write_string(
    (
      #|proc pblaze_probe_bus {name fields report} {
      #|  set config [list CONFIG.NUM_PORTS [llength $fields]]
      #|  set width 0
      #|  set index 0
      #|  foreach field $fields {
      #|    lassign $field label source bits
      #|    set pin [get_bd_pins -quiet $source]
      #|    if {![llength $pin]} {set pin [get_bd_ports -quiet $source]}
      #|    if {[llength $pin] != 1} {error "missing/ambiguous diagnostic source: $source"}
      #|    set left [get_property LEFT $pin]; set right [get_property RIGHT $pin]
      #|    set actual 1
      #|    if {$left ne "" && $right ne ""} {set actual [expr {abs($left-$right)+1}]}
      #|    if {$actual != $bits} {error "diagnostic width mismatch: $source expected $bits got $actual"}
      #|    lappend config CONFIG.IN${index}_WIDTH $bits
      #|    puts $report "FIELD $name $label lsb=$width width=$bits source=$source"
      #|    incr width $bits; incr index
      #|  }
      #|  if {$width < 1 || $width > 1024} {error "diagnostic probe exceeds BASIC width"}
      #|  ip $name xilinx.com:ip:xlconcat:2.1 $config
      #|  set index 0
      #|  foreach field $fields {
      #|    wire [lindex $field 1] $name/In$index
      #|    incr index
      #|  }
      #|  return $width
      #|}
      #|proc pblaze_attach_monitor {source monitor report} {
      #|  set source_pin [get_bd_intf_pins $source]
      #|  set monitor_pin [get_bd_intf_pins $monitor]
      #|  if {[get_property MODE $monitor_pin] ne "Monitor"} {error "capture interface is not passive Monitor: $monitor"}
      #|  set net [get_bd_intf_nets -of_objects $source_pin]
      #|  if {[llength $net] != 1} {error "missing functional AXI net: $source"}
      #|  set before [lsort [get_property NAME [get_bd_intf_pins -of_objects $net]]]
      #|  if {[llength $before] != 2} {error "expected original two functional AXI endpoints: $source"}
      #|  connect_bd_intf_net -intf_net $net $source_pin $monitor_pin
      #|  set after [lsort [get_property NAME [get_bd_intf_pins -of_objects $net]]]
      #|  if {$after ne [lsort [concat $before [get_property NAME $monitor_pin]]]} {error "passive capture changed functional AXI endpoints"}
      #|  puts $report "MONITOR $monitor source=$source original=$before joined=$after"
      #|}
      #|set diagnostic_report [open diagnostic-bd.txt w]
      #|
    ),
  )
  if has_status_capture(mode) {
    out.write_string(
      (
        #|create_bd_cell -type module -reference pblaze3_diagnostic_status diagnostic_status
        #|wire diagnostic_clock/clock50 diagnostic_status/clock50
        #|pblaze_probe_bus diagnostic_flags {
        #|  {pcie_perst_n sys_rst_n_0 1}
        #|  {source_mmcm_locked clocks/locked 1}
        #|  {mig_mmcm_locked mig/mmcm_locked 1}
        #|  {mig_ui_reset mig/ui_clk_sync_rst 1}
        #|  {calibrated mig/init_calib_complete 1}
        #|  {xdma_axi_reset_n xdma/axi_aresetn 1}
        #|  {pcie_link_up xdma/user_lnk_up 1}
        #|  {transport_healthy transport_healthy_gate/Res 1}
        #|  {supervisor_released_n transport_supervisor/released_n 1}
        #|} $diagnostic_report
        #|wire diagnostic_flags/dout diagnostic_status/flags
        #|
      ),
    )
  }
  for domain in capture_domains(mode) {
    let status_only = domain.name == "ila_reset50"
    if !status_only {
      out.write_string(diagnostic_bus_monitor_tcl(domain))
    }
    out.write_string(
      "set probe_config {CONFIG.C_MONITOR_TYPE Native CONFIG.C_ENABLE_ILA_AXI_MON false CONFIG.C_DATA_DEPTH 1024 CONFIG.C_INPUT_PIPE_STAGES 1 CONFIG.C_EN_STRG_QUAL 1 CONFIG.C_ADV_TRIGGER false CONFIG.C_NUM_OF_PROBES \{domain.probes.length()}}\n",
    )
    for index, fields in domain.probes {
      if !status_only {
        let width = fields.fold(init=0, (sum, field) => sum + field.2)
        out.write_string(
          "lappend probe_config CONFIG.C_PROBE\{index}_WIDTH \{width}\n",
        )
        continue
      }
      out.write_string(
        "set width [pblaze_probe_bus \{domain.name}_probe\{index} {\n",
      )
      for (name, pin, width) in fields {
        out.write_string("  {\{name} \{pin} \{width}}\n")
      }
      out.write_string(
        "} $diagnostic_report]\nlappend probe_config CONFIG.C_PROBE\{index}_WIDTH $width\n",
      )
    }
    out.write_string(
      "ip \{domain.name} xilinx.com:ip:ila:6.2 $probe_config\nwire \{domain.clock} \{domain.name}/clk\n",
    )
    for index, _ in domain.probes {
      out.write_string(
        if status_only {
          "wire \{domain.name}_probe\{index}/dout \{domain.name}/probe\{index}\n"
        } else {
          "wire \{domain.name}_monitor/probe\{index} \{domain.name}/probe\{index}\n"
        },
      )
    }
    out.write_string(
      "if {[llength [get_bd_pins -quiet \{domain.name}/probe*]] != \{domain.probes.length()}} {error {unexpected ILA probe count}}\n",
    )
    out.write_string(
      "foreach {key expected} {C_MONITOR_TYPE Native C_ENABLE_ILA_AXI_MON false C_NUM_OF_PROBES \{domain.probes.length()} C_DATA_DEPTH 1024 C_INPUT_PIPE_STAGES 1} {\n  set actual [get_property CONFIG.$key [get_bd_cells \{domain.name}]]\n  if {$actual ne $expected} {error \"ILA property mismatch: \{domain.name} $key=$actual expected$expected\"}\n  puts $diagnostic_report \"ILA \{domain.name} $key=$actual\"\n}\n",
    )
  }
  out.write_string("close $diagnostic_report\n")
  out.to_string()
}

///|
pub fn diagnostic_hub_constraints() -> String {
  (
    #|# Instantiated ILA flow: select an independent oscillator clock for the
    #|# automatically generated hub. This file is implementation-only.
    #|set_property C_CLK_INPUT_FREQ_HZ 50000000 [get_debug_cores dbg_hub]
    #|set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
    #|connect_debug_port dbg_hub/clk [get_nets -of_objects [get_pins pblaze3_i/diagnostic_clock/inst/oscillator_global/O]]
    #|
  )
}

///|
fn diagnostic_final_tcl(mode : BuildMode) -> String {
  let out = StringBuilder()
  out.write_string(
    if has_status_capture(mode) {
      diagnostic_physical_guard()
    } else {
      diagnostic_physical_guard().replace(
        old="  pblaze_assert_diagnostic_status_sync $report\n",
        new="  # This single-domain AXI image has no status synchronizer or status ILA.\n",
      )
    },
  )
  out.write_string("set diagnostic_rows {\n")
  for domain in capture_domains(mode) {
    let source = if domain.name == "ila_reset50" {
      "pblaze3_i/diagnostic_clock/inst/oscillator_global/O"
    } else {
      "pblaze3_i/" + domain.clock
    }
    let period = if domain.mhz == 33 { 30 } else { 1000 / domain.mhz }
    let widths = domain.probes.map(fields => {
      fields.fold(init=0, (sum, field) => sum + field.2).to_string()
    })
    out.write_string(
      "  {\{domain.name} \{source} \{period} {" + widths.join(" ") + "}}\n",
    )
  }
  out.write_string(
    (
      #|}
      #|set diagnostic_report [open diagnostic-routed.txt w]
      #|pblaze_assert_diagnostic_physical $diagnostic_rows $diagnostic_report
      #|puts $diagnostic_report PBLAZE3_ILA_ROUTED_GUARD_COMPLETE
      #|close $diagnostic_report
      #|write_debug_probes -force pblaze3.ltx
      #|if {![file isfile pblaze3.ltx] || [file size pblaze3.ltx] == 0} {error "diagnostic LTX missing"}
      #|
    ),
  )
  out.to_string()
}

///|
fn diagnostic_build_tcl(mode : BuildMode, release : String) -> String {
  let base = build_tcl_validated(mode.production_mode(), release)
  // Only the diagnostic profile adds the explicitly named passive monitor.
  // Every production ID width, routing and generated-RTL assertion is retained.
  let base = if mode == AcceleratorIla {
    base.replace(
      old="set expected [lsort [list $origin $destination]]\n",
      new=(
        #|set expected [lsort [list $origin $destination]]
        #|  if {$origin eq "/memory/M00_AXI" && $destination eq "/mig/S_AXI"} {
        #|    set monitor [get_bd_intf_pins -quiet /ila_mig200_monitor/MON_AXI]
        #|    if {[llength $monitor] != 1 || [get_property MODE $monitor] ne "Monitor"} {error "missing passive MIG diagnostic monitor"}
        #|    set expected [lsort [concat $expected /ila_mig200_monitor/MON_AXI]]
        #|  }
        #|
      ),
    )
  } else {
    base
  }
  let common_sources =
    #|foreach source {pblaze3_diagnostic_clock.sv pblaze3_diagnostic_status.sv} {
    #|  add_files -norecurse [file join $bundle $source]
    #|  set_property file_type Verilog [get_files [file join $bundle $source]]
    #|}
    #|
  let sources = StringBuilder()
  sources.write_string(
    if has_status_capture(mode) {
      common_sources
    } else {
      common_sources.replace(
        old="pblaze3_diagnostic_clock.sv pblaze3_diagnostic_status.sv",
        new="pblaze3_diagnostic_clock.sv",
      )
    },
  )
  for (name, _) in diagnostic_axi_wrappers(mode) {
    sources.write_string(
      "add_files -norecurse [file join $bundle \{name}]\nset_property file_type Verilog [get_files [file join $bundle \{name}]]\n",
    )
  }
  let clock =
    #|set_property CONFIG.PRIM_SOURCE No_buffer [get_bd_cells clocks]
    #|create_bd_cell -type module -reference pblaze3_diagnostic_clock diagnostic_clock
    #|wire clk_in1_50M diagnostic_clock/oscillator
    #|wire diagnostic_clock/clock50 clocks/clk_in1
    #|
  let xdc =
    #|add_files -fileset constrs_1 -norecurse [file join $bundle debug-hub.xdc]
    #|set_property USED_IN_SYNTHESIS false [get_files [file join $bundle debug-hub.xdc]]
    #|set_property PROCESSING_ORDER LATE [get_files [file join $bundle debug-hub.xdc]]
    #|
  base
  .replace(
    old="create_bd_design pblaze3\n",
    new=sources.to_string() + "create_bd_design pblaze3\n",
  )
  .replace(old="wire clk_in1_50M clocks/clk_in1\n", new=clock)
  .replace(
    old="validate_bd_design\n",
    new=diagnostic_connect_tcl(mode) + "validate_bd_design\n",
  )
  .replace(
    old="pblaze_record_mig_input $bundle $output $build_mode\n",
    new=diagnostic_connectivity_tcl(mode) +
      "pblaze_record_mig_input $bundle $output $build_mode\n",
  )
  .replace(
    old="set_property top pblaze3_wrapper",
    new=xdc + "set_property top pblaze3_wrapper",
  )
  .replace(
    old="report_pulse_width -warn_on_violation -verbose -file pulse-width.rpt\n",
    new="report_bus_skew -warn_on_violation -file bus-skew.rpt\nreport_pulse_width -warn_on_violation -verbose -file pulse-width.rpt\n",
  )
  .replace(
    old="write_checkpoint -force routed.dcp\n",
    new="write_checkpoint -force routed.dcp\n# Debug metadata APIs require a standalone checkpoint, not the project implementation view.\nclose_project\nopen_checkpoint [file join $output routed.dcp]\n",
  )
  .replace(
    old="write_bitstream -force pblaze3.bit\n",
    new=diagnostic_final_tcl(mode) + "write_bitstream -force pblaze3.bit\n",
  )
}

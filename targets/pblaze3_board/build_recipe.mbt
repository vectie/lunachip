///|
/// Emit vendor tool input from a stable board contract. All filesystem and
/// process orchestration stays in the MoonBit runner. Accelerator mode expects
/// the root exporter to supply pblaze3_layer_system and its three RTL sources.
pub fn build_tcl(mode : BuildMode) -> String {
  build_tcl_validated(mode, mode.vivado_release())
}

///|
/// An explicit tool release never changes the default reproducible profile.
pub fn build_tcl_for_release(
  mode : BuildMode,
  release : String,
) -> String raise BoardError {
  validate_release(mode, release)
  build_tcl_validated(mode, release)
}

///|
fn build_tcl_validated(mode : BuildMode, release : String) -> String {
  if mode.is_diagnostic() {
    return diagnostic_build_tcl(mode, release)
  }
  let out = StringBuilder()
  out.write_string(run_gates_tcl())
  out.write_string(mig_inputs_tcl())
  out.write_string(reset_boundary_tcl())
  out.write_string(id_routing_tcl())
  out.write_string("set required_release {\{release}}\n")
  out.write_string("set build_mode {\{mode.name()}}\n")
  out.write_string("set memory_range \{mode.memory_bytes()}\n")
  out.write_string(
    "set xdma_vlnv xilinx.com:ip:xdma:" +
    (if mode == VendorBaseline { "4.1" } else { "4.2" }) +
    "\n",
  )
  out.write_string(
    (
      #|if {[version -short] ne $required_release} {error "requires Vivado $required_release"}
      #|if {$argc ni {2 3}} {error "expected fresh build output, action prepare|implement, and optional previous work for read-only native cache reuse"}
      #|set bundle [file dirname [file normalize [info script]]]
      #|set output [file normalize [lindex $argv 0]]
      #|set action [lindex $argv 1]
      #|if {$action ni {prepare implement}} {error "unsupported build action"}
      #|if {[file exists $output]} {error "refusing existing build output"}
      #|file mkdir $output
      #|cd $output
      #|set_param general.maxThreads 1
      #|set tool [open tool-version.txt w]; puts $tool [version]; close $tool
      #|create_project pblaze3 [file join $output project] -part xc7k325tffg900-2
      #|if {$argc == 3} {
      #|  set previous [file normalize [lindex $argv 2]]
      #|  set channel [open [file join $previous tool-version.txt] r]; set old_version [string trim [read $channel]]; close $channel
      #|  if {$old_version ne [string trim [version]]} {error "native IP cache tool identity differs"}
      #|  set ip_cache [file join $previous project pblaze3.cache ip]
      #|  if {![file isdirectory $ip_cache]} {error "missing native IP cache"}
      #|  set cache_report [open cache-run-gates.txt w]
      #|  if {[pblaze_assert_cache_logs $ip_cache $previous $cache_report] == 0} {error "native IP cache has no original synthesis logs"}
      #|  close $cache_report
      #|  config_ip_cache -use_cache_location $ip_cache
      #|  set_property IP_CACHE_PERMISSIONS read [current_project]
      #|}
      #|set_property target_language Verilog [current_project]
      #|set_property simulator_language Mixed [current_project]
      #|set_property XPM_LIBRARIES {XPM_CDC} [current_project]
      #|add_files -norecurse [file join $bundle pblaze3_transport_reset_core.sv]
      #|add_files -norecurse [file join $bundle pblaze3_transport_reset.sv]
      #|set_property file_type Verilog [get_files [file join $bundle pblaze3_transport_reset.sv]]
      #|if {$build_mode eq "ddr-smoke"} {
      #|  add_files -norecurse [file join $bundle pblaze3_smoke_status_sync.sv]
      #|  set_property file_type Verilog [get_files [file join $bundle pblaze3_smoke_status_sync.sv]]
      #|}
      #|if {$build_mode eq "accelerator"} {
      #|  foreach source {core.sv controller.sv bridge.sv pblaze3_layer_system.sv pblaze3_calib_sync.sv} {
      #|    if {![file isfile [file join $bundle $source]]} {error "missing accelerator source $source"}
      #|    add_files -norecurse [file join $bundle $source]
      #|  }
      #|  # BD module references require a Verilog top. These physical wrappers
      #|  # use Verilog2001 syntax; their generated child cores remain SystemVerilog.
      #|  foreach source {pblaze3_layer_system.sv pblaze3_calib_sync.sv} {
      #|    set_property file_type Verilog [get_files [file join $bundle $source]]
      #|  }
      #|  update_compile_order -fileset sources_1
      #|}
      #|proc ip {name vlnv config} {
      #|  set cell [create_bd_cell -type ip -vlnv $vlnv $name]
      #|  if {[llength $config]} {set_property -dict $config $cell}
      #|  return $cell
      #|}
      #|proc wire {args} {
      #|  set pins {}
      #|  foreach name $args {
      #|    set pin [get_bd_pins -quiet $name]
      #|    if {![llength $pin]} {set pin [get_bd_ports -quiet $name]}
      #|    if {[llength $pin] != 1} {error "missing/ambiguous scalar pin $name"}
      #|    lappend pins $pin
      #|  }
      #|  connect_bd_net {*}$pins
      #|}
      #|proc bus {a b} {connect_bd_intf_net [get_bd_intf_pins $a] [get_bd_intf_pins $b]}
      #|proc external_bus {pin name} {
      #|  set before [get_bd_intf_ports -quiet]
      #|  make_bd_intf_pins_external [get_bd_intf_pins $pin]
      #|  set created {}
      #|  foreach port [get_bd_intf_ports -quiet] {if {[lsearch -exact $before $port] < 0} {lappend created $port}}
      #|  if {[llength $created] != 1} {error "expected one new external interface for $pin"}
      #|  if {[get_property name $created] ne $name} {set_property name $name $created}
      #|}
      #|proc external_pin {pin name} {
      #|  set before [get_bd_ports -quiet]
      #|  make_bd_pins_external [get_bd_pins $pin]
      #|  set created {}
      #|  foreach port [get_bd_ports -quiet] {if {[lsearch -exact $before $port] < 0} {lappend created $port}}
      #|  if {[llength $created] != 1} {error "expected one new external port for $pin"}
      #|  if {[get_property name $created] ne $name} {set_property name $name $created}
      #|}
      #|create_bd_design pblaze3
      #|create_bd_port -dir I -type clk -freq_hz 50000000 clk_in1_50M
      #|create_bd_port -dir I -type rst sys_rst_n_0
      #|set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports sys_rst_n_0]
      #|ip refclk xilinx.com:ip:util_ds_buf:2.2 {CONFIG.C_BUF_TYPE IBUFDSGTE}
      #|external_bus refclk/CLK_IN_D CLK_IN_D_0
      #|set_property CONFIG.FREQ_HZ 100000000 [get_bd_intf_ports CLK_IN_D_0]
      #|ip xdma $xdma_vlnv {
      #|  CONFIG.mode_selection Advanced CONFIG.pl_link_cap_max_link_speed 5.0_GT/s
      #|  CONFIG.pl_link_cap_max_link_width X8 CONFIG.axi_data_width 128_bit
      #|  CONFIG.axisten_freq 250 CONFIG.axilite_master_en true
      #|  CONFIG.pciebar2axibar_axil_master 0x40000000
      #|  CONFIG.pf0_device_id 7024 CONFIG.xdma_rnum_chnl 2 CONFIG.xdma_wnum_chnl 2
      #|}
      #|if {$build_mode eq "accelerator"} {
      #|  set_property -dict {CONFIG.axilite_master_size 1 CONFIG.axilite_master_scale Megabytes} [get_bd_cells xdma]
      #|}
      #|external_bus xdma/pcie_mgt pcie_mgt_0
      #|wire refclk/IBUF_OUT xdma/sys_clk
      #|ip clocks xilinx.com:ip:clk_wiz:6.0 {
      #|  CONFIG.PRIM_IN_FREQ 50.000 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 200.000
      #|  CONFIG.CLK_OUT1_PORT clk_200M CONFIG.CLKOUT2_USED true
      #|  CONFIG.CLKOUT2_REQUESTED_OUT_FREQ 33.333333 CONFIG.CLK_OUT2_PORT core_clk
      #|  CONFIG.CLKOUT3_USED true CONFIG.CLKOUT3_REQUESTED_OUT_FREQ 50.000
      #|  CONFIG.CLK_OUT3_PORT reset_clk50
      #|  CONFIG.USE_RESET false CONFIG.USE_LOCKED true
      #|}
      #|wire clk_in1_50M clocks/clk_in1
      #|# MIG mutates XML_INPUT_FILE during BD capability propagation. Preserve
      #|# the exported source and give the vendor only a fresh working copy.
      #|file copy [file join $bundle mig.prj] [file join $output mig-source.prj]
      #|file copy [file join $bundle mig.prj] [file join $output mig-effective.prj]
      #|ip mig xilinx.com:ip:mig_7series:4.2 [list CONFIG.XML_INPUT_FILE [file join $output mig-effective.prj] CONFIG.BOARD_MIG_PARAM Custom CONFIG.MIG_DONT_TOUCH_PARAM Custom CONFIG.RESET_BOARD_INTERFACE Custom]
      #|external_bus mig/DDR3 DDR3_0
      #|wire clocks/clk_200M mig/sys_clk_i
      #|# Reset MIG when PCIe PERST asserts or its source MMCM is unlocked.
      #|ip mig_reset_gate xilinx.com:ip:util_vector_logic:2.0 {CONFIG.C_OPERATION and CONFIG.C_SIZE 1}
      #|wire clocks/locked mig_reset_gate/Op1
      #|wire sys_rst_n_0 mig_reset_gate/Op2
      #|wire mig_reset_gate/Res mig/sys_rst
      #|# A MIG UI reset must also flush the upstream XDMA transaction owner.
      #|# MIG physical reset remains independent of XDMA to avoid startup feedback.
      #|ip ui_reset_inv xilinx.com:ip:util_vector_logic:2.0 {CONFIG.C_OPERATION not CONFIG.C_SIZE 1}
      #|wire mig/ui_clk_sync_rst ui_reset_inv/Op1
      #|ip ui_ready xilinx.com:ip:util_vector_logic:2.0 {CONFIG.C_OPERATION and CONFIG.C_SIZE 1}
      #|wire ui_reset_inv/Res ui_ready/Op1
      #|wire mig/mmcm_locked ui_ready/Op2
      #|ip transport_healthy_gate xilinx.com:ip:util_vector_logic:2.0 {CONFIG.C_OPERATION and CONFIG.C_SIZE 1}
      #|wire mig_reset_gate/Res transport_healthy_gate/Op1
      #|wire ui_ready/Res transport_healthy_gate/Op2
      #|# PG054 requires >=1500ns fundamental reset. A canonical 128-cycle
      #|# supervisor requires128 healthy 50MHz edges after synchronized recovery.
      #|# Its clock is independent of XDMA; source-MMCM loss asserts asynchronously.
      #|create_bd_cell -type module -reference pblaze3_transport_reset transport_supervisor
      #|wire clocks/reset_clk50 transport_supervisor/clock50
      #|wire transport_healthy_gate/Res transport_supervisor/healthy
      #|ip transport_reset_gate xilinx.com:ip:util_vector_logic:2.0 {CONFIG.C_OPERATION and CONFIG.C_SIZE 1}
      #|wire transport_supervisor/released_n transport_reset_gate/Op1
      #|wire transport_healthy_gate/Res transport_reset_gate/Op2
      #|wire transport_reset_gate/Res xdma/sys_rst_n
      #|ip xdma_reset_inv xilinx.com:ip:util_vector_logic:2.0 {CONFIG.C_OPERATION not CONFIG.C_SIZE 1}
      #|wire xdma/axi_aresetn xdma_reset_inv/Op1
      #|ip reset_ui xilinx.com:ip:proc_sys_reset:5.0 {CONFIG.C_AUX_RESET_HIGH 1}
      #|wire mig/ui_clk reset_ui/slowest_sync_clk
      #|wire mig/ui_clk_sync_rst reset_ui/ext_reset_in
      #|wire xdma_reset_inv/Res reset_ui/aux_reset_in
      #|wire mig/mmcm_locked reset_ui/dcm_locked
      #|wire reset_ui/peripheral_aresetn mig/aresetn
      #|ip memory xilinx.com:ip:axi_interconnect:2.1 [list CONFIG.NUM_MI 1 CONFIG.NUM_SI [expr {$build_mode eq "accelerator" ? 2 : 1}]]
      #|bus xdma/M_AXI memory/S00_AXI
      #|bus memory/M00_AXI mig/S_AXI
      #|wire mig/ui_clk memory/ACLK memory/M00_ACLK
      #|wire reset_ui/interconnect_aresetn memory/ARESETN
      #|wire reset_ui/peripheral_aresetn memory/M00_ARESETN
      #|wire xdma/axi_aclk memory/S00_ACLK
      #|wire xdma/axi_aresetn memory/S00_ARESETN
      #|if {$build_mode eq "accelerator"} {
      #|  # Calibration loss is a health fault, not a unilateral core reset.
      #|  # Outstanding AXI requests drain before software requests PERST recovery.
      #|  create_bd_cell -type module -reference pblaze3_calib_sync calibration_sync
      #|  wire clocks/core_clk calibration_sync/dest_clk
      #|  wire mig/init_calib_complete calibration_sync/src_in
      #|  ip reset_core xilinx.com:ip:proc_sys_reset:5.0 {CONFIG.C_AUX_RESET_HIGH 1}
      #|  wire clocks/core_clk reset_core/slowest_sync_clk
      #|  wire xdma/axi_aresetn reset_core/ext_reset_in
      #|  wire mig/ui_clk_sync_rst reset_core/aux_reset_in
      #|  wire mig/mmcm_locked reset_core/dcm_locked
      #|  create_bd_cell -type module -reference pblaze3_layer_system accelerator
      #|  wire clocks/core_clk accelerator/clock memory/S01_ACLK
      #|  wire reset_core/peripheral_reset accelerator/reset
      #|  wire calibration_sync/dest_out accelerator/memory_healthy
      #|  wire reset_core/peripheral_aresetn memory/S01_ARESETN
      #|  bus accelerator/M_AXI_DDR memory/S01_AXI
      #|  ip control xilinx.com:ip:axi_interconnect:2.1 {CONFIG.NUM_SI 1 CONFIG.NUM_MI 1}
      #|  bus xdma/M_AXI_LITE control/S00_AXI
      #|  bus control/M00_AXI accelerator/S_AXI_CTRL
      #|  wire xdma/axi_aclk control/ACLK control/S00_ACLK
      #|  wire xdma/axi_aresetn control/ARESETN control/S00_ARESETN
      #|  wire clocks/core_clk control/M00_ACLK
      #|  wire reset_core/peripheral_aresetn control/M00_ARESETN
      #|  ip leds xilinx.com:ip:xlconcat:2.1 {CONFIG.NUM_PORTS 3}
      #|  wire mig/init_calib_complete leds/In0
      #|  wire xdma/user_lnk_up leds/In1
      #|  wire reset_core/peripheral_aresetn leds/In2
      #|  external_pin leds/dout led
      #|} else {
      #|  ip gpio xilinx.com:ip:axi_gpio:2.0 {CONFIG.C_GPIO_WIDTH 3 CONFIG.C_ALL_OUTPUTS 1}
      #|  if {$build_mode eq "ddr-smoke"} {
      #|    set_property -dict {CONFIG.C_IS_DUAL 1 CONFIG.C_GPIO2_WIDTH 3 CONFIG.C_ALL_INPUTS_2 1} [get_bd_cells gpio]
      #|    create_bd_cell -type module -reference pblaze3_smoke_status_sync smoke_status
      #|    wire xdma/axi_aclk smoke_status/dest_clk
      #|    wire mig/init_calib_complete smoke_status/calibrated
      #|    wire xdma/user_lnk_up smoke_status/link_up
      #|    wire reset_ui/peripheral_aresetn smoke_status/ui_reset_released
      #|    wire smoke_status/status gpio/gpio2_io_i
      #|  }
      #|  bus xdma/M_AXI_LITE gpio/S_AXI
      #|  wire xdma/axi_aclk gpio/s_axi_aclk
      #|  wire xdma/axi_aresetn gpio/s_axi_aresetn
      #|  external_pin gpio/gpio_io_o led
      #|}
      #|assign_bd_address -offset 0x00000000 -range $memory_range -target_address_space [get_bd_addr_spaces xdma/M_AXI] [get_bd_addr_segs mig/memmap/memaddr]
      #|if {$build_mode eq "accelerator"} {
      #|  assign_bd_address -offset 0x00000000 -range $memory_range -target_address_space [get_bd_addr_spaces accelerator/M_AXI_DDR] [get_bd_addr_segs mig/memmap/memaddr]
      #|  set ctrl_segment [get_bd_addr_segs -quiet accelerator/S_AXI_CTRL/*]
      #|  if {[llength $ctrl_segment] != 1} {error "expected one module control segment, found $ctrl_segment; all segments: [get_bd_addr_segs -quiet]"}
      #|  assign_bd_address -offset 0x40000000 -range 1M -target_address_space [get_bd_addr_spaces xdma/M_AXI_LITE] $ctrl_segment
      #|} else {
      #|  assign_bd_address -offset 0x40000000 -range 64K -target_address_space [get_bd_addr_spaces xdma/M_AXI_LITE] [get_bd_addr_segs gpio/S_AXI/Reg]
      #|}
      #|validate_bd_design
      #|# C_EXT_RESET_HIGH is inferred and read-only in BD. Verify the
      #|# propagated polarity instead of issuing an ignored assignment.
      #|if {[get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells reset_ui]] != 1} {error "MIG UI reset must be active high"}
      #|if {$build_mode eq "accelerator" && [get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells reset_core]] != 0} {error "XDMA core transport reset must be active low"}
      #|set transport [open [file join $output transport-properties.txt] w]
      #|foreach reset_name {reset_ui reset_core} {
      #|  set reset_cell [get_bd_cells -quiet $reset_name]
      #|  if {[llength $reset_cell]} {puts $transport "RESET $reset_name EXT_HIGH=[get_property CONFIG.C_EXT_RESET_HIGH $reset_cell] AUX_HIGH=[get_property CONFIG.C_AUX_RESET_HIGH $reset_cell]"}
      #|}
      #|foreach interface {xdma/M_AXI memory/S00_AXI memory/M00_AXI mig/S_AXI} {
      #|  set pin [get_bd_intf_pins $interface]
      #|  puts $transport "INTERFACE $interface"
      #|  foreach property [lsort [list_property $pin]] {
      #|    if {[string match CONFIG.* $property]} {puts $transport "$property=[get_property $property $pin]"}
      #|  }
      #|}
      #|close $transport
      #|save_bd_design
      #|write_bd_tcl -force [file join $output resolved-design.tcl]
      #|report_ip_status -file [file join $output ip-status.rpt]
      #|generate_target all [get_files pblaze3.bd]
      #|pblaze_record_mig_input $bundle $output $build_mode
      #|set reset_report [open [file join $output reset-boundary-properties.txt] w]
      #|pblaze_assert_reset_vendor_release [file join $output project pblaze3.gen sources_1 bd pblaze3 ip pblaze3_xdma_0 ip_0 source] $reset_report
      #|close $reset_report
      #|if {$build_mode eq "accelerator"} {
      #|  set ids [open [file join $output id-routing-properties.txt] w]
      #|  pblaze_assert_memory_ids [file join $output project pblaze3.gen sources_1 bd pblaze3 synth pblaze3.v] $ids
      #|  close $ids
      #|}
      #|set wrapper [make_wrapper -files [get_files pblaze3.bd] -top]
      #|add_files -norecurse $wrapper
      #|add_files -fileset constrs_1 -norecurse [file join $bundle pblaze3.xdc]
      #|# Leaf IP netlist pins are linked only after top synthesis. The guard
      #|# checks the complete linked fanout before this implementation-only XDC.
      #|add_files -fileset constrs_1 -norecurse [file join $bundle reset-boundary.xdc]
      #|set_property USED_IN_SYNTHESIS false [get_files [file join $bundle reset-boundary.xdc]]
      #|set_property PROCESSING_ORDER LATE [get_files [file join $bundle reset-boundary.xdc]]
      #|set_property top pblaze3_wrapper [current_fileset]
      #|update_compile_order -fileset sources_1
      #|set prepare_critical_count [get_msg_config -count -severity {CRITICAL WARNING}]
      #|if {![string is integer -strict $prepare_critical_count] || $prepare_critical_count != 0} {error "BD/IP generation emitted critical warnings"}
      #|if {$action eq "prepare"} {
      #|  set marker [open PREPARE_COMPLETE w]
      #|  puts $marker "Vivado IP generation and BD validation only; no timing or board claim"
      #|  close $marker
      #|  exit
      #|}
      #|
    ),
  )
  out.write_string(implementation_tcl())
  out.to_string()
}

if {[catch {
  set work /work/builds/pblaze3-ila-catalog-20261028-a2
  if {[file exists $work]} {error "fresh guest evidence required"}
  file mkdir $work
  cd $work
  set_param general.maxThreads 1
  puts "ILA_TOOL=[version]"
  create_project -in_memory -part xc7k325tffg900-2
  set defs [get_ipdefs -all xilinx.com:ip:ila:*]
  puts "ILA_IPDEFS=$defs"
  if {[lsearch -exact $defs xilinx.com:ip:ila:6.2] < 0} {error "expected ordinary ILA6.2"}
  create_bd_design ila_probe
  set core [create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila]
  set_property -dict {CONFIG.C_MONITOR_TYPE Native CONFIG.C_ENABLE_ILA_AXI_MON false CONFIG.C_NUM_OF_PROBES 5 CONFIG.C_DATA_DEPTH 1024 CONFIG.C_PROBE0_WIDTH 64 CONFIG.C_PROBE1_WIDTH 147 CONFIG.C_PROBE2_WIDTH 9 CONFIG.C_PROBE3_WIDTH 142 CONFIG.C_PROBE4_WIDTH 64 CONFIG.C_INPUT_PIPE_STAGES 1} $core
  foreach p [lsort [list_property $core]] {if {[string match CONFIG.* $p] && !([regexp {C_PROBE([0-9]+)_} $p all n] && $n > 4)} {puts "ILA_CONFIG $p=[get_property $p $core]"}}
  if {[llength [get_bd_pins ila/probe*]] != 5} {error "expected exactly5nativeprobes"}
  set index 0
  foreach expected {64 147 9 142 64} {if {[get_property LEFT [get_bd_pins ila/probe$index]]+1 != $expected} {error "nativeprobe width differs"};incr index}
  foreach p [get_bd_pins -of_objects $core] {
    puts "ILA_PIN $p"
    foreach key {DIR TYPE LEFT RIGHT} {if {$key in [list_property $p]} {puts "  $key=[get_property $key $p]"}}
  }
  puts [help connect_debug_port]
  puts [help disconnect_debug_port]
  puts [help write_debug_probes]
  close_project
  open_project -read_only /work/builds/pblaze3-work-20261026-v20261-build-a9/project/pblaze3.xpr
  open_bd_design [get_files -quiet */pblaze3.bd]
  foreach name {mig xdma} {
    foreach p [lsort [get_bd_pins -of_objects [get_bd_cells $name]]] {
      if {[regexp -nocase {/(s_axi_|m_axi_|m_axil_|axi_aclk|axi_aresetn|ui_clk|init_calib|mmcm_locked)} $p]} {
        puts "BOARD_PIN $p"
        foreach key {DIR TYPE LEFT RIGHT} {if {$key in [list_property $p]} {puts "  $key=[get_property $key $p]"}}
      }
    }
  }
  foreach interface {mig/S_AXI xdma/M_AXI xdma/M_AXI_LITE} {
    set p [get_bd_intf_pins $interface]
    foreach key {CONFIG.PROTOCOL CONFIG.DATA_WIDTH CONFIG.ADDR_WIDTH CONFIG.ID_WIDTH CONFIG.FREQ_HZ} {if {$key in [list_property $p]} {puts "BOARD_INTERFACE $interface $key=[get_property $key $p]"}}
  }
  close_project
  puts "ILA_CATALOG_PROBE=PASS"
} reason options]} {puts stderr "ILA_PROBE_FAILED=$reason";puts stderr [dict get $options -errorinfo];exit 1}
exit 0

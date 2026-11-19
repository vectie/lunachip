if {[catch {
set output /work/builds/pblaze3-review-mig-effective-a10-a1
if {[file exists $output]} {error {fresh evidence required}}
file mkdir $output
set_param general.maxThreads 1
set work /work/builds/pblaze3-work-20261026-v20261-build-a10
set checkpoint $work/project/pblaze3.runs/impl_1/pblaze3_wrapper_routed.dcp
set before [exec sha256sum $checkpoint]
set report [open $output/properties.txt w]
puts $report "DCP_BEFORE=$before"
open_project -read_only $work/project/pblaze3.xpr
open_bd_design [get_files */pblaze3.bd]
foreach name {xdma/M_AXI accelerator/M_AXI_DDR memory/S00_AXI memory/S01_AXI memory/M00_AXI memory/xbar/M00_AXI mig/S_AXI} {
  set object [get_bd_intf_pins $name]
  if {[llength $object] != 1} {error "interface absent: $name"}
  foreach property {CONFIG.ADDR_WIDTH CONFIG.DATA_WIDTH CONFIG.ID_WIDTH CONFIG.SUPPORTS_NARROW_BURST CONFIG.MAX_BURST_LENGTH CONFIG.NUM_READ_OUTSTANDING CONFIG.NUM_WRITE_OUTSTANDING} {
    puts $report "BD $name $property=[get_property $property $object]"
  }
}
foreach {name property expected} {mig/S_AXI CONFIG.ADDR_WIDTH 31 mig/S_AXI CONFIG.DATA_WIDTH 128 mig/S_AXI CONFIG.ID_WIDTH 5 mig/S_AXI CONFIG.SUPPORTS_NARROW_BURST 1 accelerator/M_AXI_DDR CONFIG.SUPPORTS_NARROW_BURST 1 xdma/M_AXI CONFIG.SUPPORTS_NARROW_BURST 0} {
  if {[get_property $property [get_bd_intf_pins $name]] ne $expected} {error "effective interface mismatch: $name $property"}
}
foreach object [get_ips -all pblaze3_mig_0] {
  foreach property [lsort [list_property $object]] {
    if {[regexp {^CONFIG.*(NARROW|ADDR_WIDTH|DATA_WIDTH|ID_WIDTH|ROW|COL|BANK|MEMORY|Memory)} $property]} {puts $report "IP $object $property=[get_property $property $object]"}
  }
}
set generated $work/project/pblaze3.gen/sources_1/bd/pblaze3/ip/pblaze3_mig_0/pblaze3_mig_0
foreach name {mig.prj user_design/rtl/pblaze3_mig_0_mig.v user_design/rtl/axi/mig_7series_v4_2_axi_mc.v user_design/rtl/ip_top/mig_7series_v4_2_memc_ui_top_axi.v} {
  set file $generated/$name
  puts $report "GENERATED_SHA256=[exec sha256sum $file]"
  set channel [open $file r]; set content [read $channel]; close $channel
  set line_number 0
  foreach line [split $content \n] {
    incr line_number
    if {[regexp {C_S_AXI_(ID_WIDTH|ADDR_WIDTH|DATA_WIDTH|SUPPORTS_NARROW_BURST)|P_USE_UPSIZER|parameter (BANK_WIDTH|COL_WIDTH|ROW_WIDTH|DQ_WIDTH|DQS_WIDTH|tCK |nCK_PER_CLK)|<MemoryDevice>|<RowAddress>|<ColAddress>|<BankAddress>|<DataWidth>|<C0_S_AXI} $line]} {puts $report "GENERATED $name:$line_number $line"}
  }
}
close_bd_design [current_bd_design]
open_run impl_1
proc exact_pin {name} {
  set found [get_pins -quiet -hierarchical -filter [format {NAME == "%s"} $name]]
  if {[llength $found] != 1} {error "mapped pin absent: $name"}
  return $found
}
foreach {signal width value} {m_axi_awsize 3 4 m_axi_arsize 3 4 m_axi_awlen 8 0 m_axi_arlen 8 0} {
  for {set index 0} {$index < $width} {incr index} {
    set name [format {pblaze3_i/accelerator/%s[%d]} $signal $index]
    set drivers [get_pins -leaf -of_objects [get_nets -segments -of_objects [exact_pin $name]] -filter {DIRECTION == OUT}]
    set cells [get_cells -of_objects $drivers]
    set expected [expr {($value >> $index) & 1 ? "VCC" : "GND"}]
    if {[llength $cells] != 1 || [get_property REF_NAME $cells] ne $expected} {error "core AXI constant differs: $name"}
    puts $report "DCP_CONSTANT $name $expected $drivers"
  }
}
set mig [get_cells pblaze3_i/mig]
set pins [get_pins -of_objects $mig]
foreach {signal expected} {s_axi_awaddr 31 s_axi_araddr 31 s_axi_wdata 128 s_axi_rdata 128 s_axi_wstrb 16 s_axi_awid 5 s_axi_arid 5 s_axi_bid 5 s_axi_rid 5 ddr3_addr 15 ddr3_ba 3 ddr3_dq 64 ddr3_dqs_p 8} {
  set count 0
  foreach pin $pins {
    set ref [get_property REF_PIN_NAME $pin]
    if {[string first "${signal}\[" $ref] == 0} {incr count}
  }
  puts $report "DCP_WIDTH $signal actual=$count expected=$expected"
  if {$count != $expected} {error "mapped MIG pin width differs: $signal"}
}
set upsizer [get_cells -hierarchical -filter {NAME =~ pblaze3_i/mig/* && NAME =~ *upsizer*}]
puts $report "DCP_UPSIZER_CELL_COUNT=[llength $upsizer]"
if {![llength $upsizer]} {error "mapped MIG upsizer absent"}
foreach cell [lrange [lsort $upsizer] 0 15] {puts $report "DCP_UPSIZER $cell REF_NAME=[get_property REF_NAME $cell]"}
close_project
set after [exec sha256sum $checkpoint]
puts $report "DCP_AFTER=$after"
if {$before ne $after} {error "original checkpoint changed"}
close $report
puts REVIEW_MIG_EFFECTIVE_PASS
exit 0
} failure]} {puts "REVIEW_MIG_EFFECTIVE_ERROR=$failure"; exit 1}

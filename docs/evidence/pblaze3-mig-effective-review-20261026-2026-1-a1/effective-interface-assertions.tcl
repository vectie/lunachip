proc pblaze_assert_mig_effective_interface {report} {
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
}

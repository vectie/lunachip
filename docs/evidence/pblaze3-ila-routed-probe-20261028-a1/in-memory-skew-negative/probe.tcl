if {[catch {
set_param general.maxThreads 1
set dcp /work/builds/pblaze3-work-20261028-status-ila-build-a3/routed.dcp
puts "DCP_BEFORE=[exec sha256sum $dcp]"
open_checkpoint $dcp
set before [get_msg_config -count -severity {CRITICAL WARNING}]
if {$before != 0} {error "unexpected pre-negative critical warnings"}
set scope pblaze3_i/memory/s00_couplers/auto_cc/inst/gen_clock_conv.gen_async_conv.asyncfifo_axi/inst_fifo_gen/gaxi_full_lite.gread_ch.grdch2.axi_rdch/grf.rf/gntv_or_sync_fifo.gcx.clkx/rd_pntr_cdc_inst
current_instance $scope
set sources [get_cells src_gray_ff_reg*]
set destinations [get_cells {dest_graysync_ff_reg[0]*}]
if {[llength $sources] < 2 || [llength $sources] != [llength $destinations]} {error "unexpected skew-negative endpoints"}
puts "SKEW_NEGATIVE_FROM=$sources"
puts "SKEW_NEGATIVE_TO=$destinations"
set_bus_skew -from $sources -to $destinations 0.001
current_instance
file mkdir /work/builds/pblaze3-ila-skew-negative-20261028-a1
report_bus_skew -warn_on_violation -file /work/builds/pblaze3-ila-skew-negative-20261028-a1/bus-skew.rpt
set fd [open /work/builds/pblaze3-ila-skew-negative-20261028-a1/bus-skew.rpt r]
puts BUS_SKEW_BEGIN
puts [read $fd]
close $fd
puts BUS_SKEW_END
puts "DCP_AFTER=[exec sha256sum $dcp]"
set critical [get_msg_config -count -severity {CRITICAL WARNING}]
puts "SKEW_CRITICAL_COUNT=$critical"
if {![string is integer -strict $critical] || $critical != 0} {error "bus-skew or prior critical warning prevents acceptance"}
puts UNEXPECTED_BUILD_COMPLETE
} reason options]} {
  puts stderr "NEGATIVE_GATE_REJECTED=$reason"
  exit 1
}
exit 0

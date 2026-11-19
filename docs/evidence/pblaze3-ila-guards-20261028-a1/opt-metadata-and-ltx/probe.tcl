if {[catch {
set_param general.maxThreads 1
set probe_work /work/builds/pblaze3-ila-netlist-status-opt-a2
if {[file exists $probe_work]} {error {fresh guest evidence required}}
file mkdir $probe_work
open_checkpoint {/work/builds/pblaze3-work-20261028-status-ila-build-a3/project/pblaze3.runs/impl_1/pblaze3_wrapper_opt.dcp}
puts "ILA_TOOL=[version]"
puts "ILA_CORES=[get_debug_cores]"
foreach core [get_debug_cores] {
  puts "CORE_PROPERTIES_BEGIN $core"
  puts [report_property -return_string $core]
  puts "CORE_PROPERTIES_END $core"
  foreach port [get_debug_ports -of_objects $core] {
    puts "PORT_PROPERTIES_BEGIN $port"
    puts [report_property -return_string $port]
    puts "PORT_PROPERTIES_END $port"
  }
}
foreach pattern {
  */diagnostic_clock/inst/*
  dbg_hub/clk
  */diagnostic_status/inst/*
  */ila_reset50/inst/clk
  */ila_mig200/inst/clk
  */ila_xdma250/inst/clk
  */ila_core33/inst/clk
  */clocks/core_clk
  */mig/ui_clk
  */xdma/axi_aclk
} {
  foreach pin [get_pins -hier -filter "NAME =~ $pattern"] {
    if {[regexp {/(D|Q|C|CLK|I|O|clk|clock50|ui_clk|axi_aclk|core_clk|oscillator)$} $pin]} {
      puts "PIN $pin NETS=[get_nets -segments -of_objects $pin] CLOCKS=[get_clocks -of_objects $pin]"
    }
  }
}
foreach cell [get_cells -hier -filter {NAME =~ */diagnostic_clock/inst/* || NAME =~ */diagnostic_status/inst/*}] {
  puts "CELL_PROPERTIES_BEGIN $cell"
  puts [report_property -return_string $cell]
  puts "CELL_PROPERTIES_END $cell"
}
foreach clock [get_clocks] {
  puts "CLOCK_PROPERTIES_BEGIN $clock"
  puts [report_property -return_string $clock]
  puts "CLOCK_PROPERTIES_END $clock"
}
if {[llength [get_debug_cores]] > 0} {
  write_debug_probes -force [file join $probe_work preview.ltx]
  set fd [open [file join $probe_work preview.ltx] r];set ltx [read $fd];close $fd
  puts "LTX_PREVIEW_BEGIN"
  puts $ltx
  puts "LTX_PREVIEW_END"
}
puts "ILA_NETLIST_PROBE=PASS"
} reason options]} {puts stderr "ILA_NETLIST_FAILED=$reason";puts stderr [dict get $options -errorinfo];exit 1}
exit 0

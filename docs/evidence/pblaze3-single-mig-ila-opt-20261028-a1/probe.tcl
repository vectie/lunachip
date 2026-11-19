if {[catch {
set_param general.maxThreads 1
set dcp {/work/builds/pblaze3-work-20261028-mig-ila-build-a1/project/pblaze3.runs/impl_1/pblaze3_wrapper_opt.dcp}
puts "DCP_BEFORE=[exec sha256sum $dcp]"
open_checkpoint $dcp
proc pblaze_diag_pin {name} {
  set pin [get_pins -quiet -hier -filter [format {NAME == "%s"} $name]]
  if {[llength $pin] != 1} {error "missing/ambiguous diagnostic physical pin $name"}
  return $pin
}
proc pblaze_diag_cell {name} {
  set cell [get_cells -quiet -hier -filter [format {NAME == "%s"} $name]]
  if {[llength $cell] != 1} {error "missing/ambiguous diagnostic physical cell $name"}
  return $cell
}
proc pblaze_diag_property {object property expected} {
  if {[llength $object] != 1 || $property ni [list_property $object]} {error "diagnostic property absent: $object $property"}
  set actual [get_property $property $object]
  if {$actual ne $expected} {error "diagnostic property mismatch: $object $property=$actual expected=$expected"}
}
proc pblaze_diag_same_net {left right label report} {
  if {[llength $left] != 1 || [llength $right] != 1} {error "ambiguous diagnostic net endpoints: $label"}
  set a [lsort [get_nets -segments -of_objects $left]]
  set b [lsort [get_nets -segments -of_objects $right]]
  if {[llength $a] == 0 || $a ne $b} {error "diagnostic net identity mismatch: $label ($left -> $right)"}
  puts $report "NET_IDENTITY $label left=$left right=$right segments=[llength $a]"
}
proc pblaze_diag_clock {pin period report} {
  set clock [get_clocks -of_objects $pin]
  if {[llength $clock] != 1 || abs([get_property PERIOD $clock]-$period)>0.001} {error "diagnostic clock identity/period mismatch: $pin expected=$period"}
  puts $report "CLOCK_IDENTITY $pin name=[get_property NAME $clock] period=[get_property PERIOD $clock]"
  return $clock
}
proc pblaze_assert_diagnostic_raw_clock {report} {
  set raw pblaze3_i/diagnostic_clock/inst
  pblaze_diag_property [pblaze_diag_cell $raw/oscillator_input] REF_NAME IBUF
  pblaze_diag_property [pblaze_diag_cell $raw/oscillator_global] REF_NAME BUFG
  set port [get_ports -quiet clk_in1_50M]
  if {[llength $port] != 1} {error "diagnostic primary clock port missing"}
  pblaze_diag_same_net $port [pblaze_diag_pin $raw/oscillator_input/I] oscillator_to_ibuf $report
  pblaze_diag_same_net [pblaze_diag_pin $raw/oscillator_input/O] [pblaze_diag_pin $raw/oscillator_global/I] ibuf_to_bufg $report
  set clock [pblaze_diag_clock [pblaze_diag_pin $raw/oscillator_global/O] 20 $report]
  pblaze_diag_property $clock NAME clk_in1_50M
  pblaze_diag_property $clock IS_GENERATED 0
  pblaze_diag_property $clock SOURCE_PINS clk_in1_50M
  pblaze_diag_same_net [pblaze_diag_pin $raw/oscillator_global/O] [pblaze_diag_pin dbg_hub/clk] raw50_to_hub $report
  set hub [get_debug_cores -quiet dbg_hub]
  pblaze_diag_property $hub C_CLK_INPUT_FREQ_HZ 50000000
  pblaze_diag_property $hub C_ENABLE_CLK_DIVIDER false
  puts $report "RAW_OSCILLATOR_CLOCK=PASS"
}
proc pblaze_assert_diagnostic_status_sync {report} {
  set root pblaze3_i/diagnostic_status/inst/flags_cdc
  set actual [get_cells -quiet -hier -filter [format {NAME =~ "%s/syncstages_ff_reg*"} $root]]
  set expected {}
  for {set stage 0} {$stage < 3} {incr stage} {
    for {set bit 0} {$bit < 9} {incr bit} {
      set name [format {%s/syncstages_ff_reg[%d][%d]} $root $stage $bit]
      lappend expected $name
      set cell [pblaze_diag_cell $name]
      pblaze_diag_property $cell REF_NAME FDRE
      pblaze_diag_property $cell ASYNC_REG 1
      pblaze_diag_same_net [pblaze_diag_pin $name/C] [pblaze_diag_pin pblaze3_i/diagnostic_clock/inst/oscillator_global/O] status_clock_$stage.$bit $report
      if {$stage > 0} {
        set prior [format {%s/syncstages_ff_reg[%d][%d]/Q} $root [expr {$stage-1}] $bit]
        pblaze_diag_same_net [pblaze_diag_pin $prior] [pblaze_diag_pin $name/D] status_chain_$stage.$bit $report
      }
      if {$stage == 2} {
        set probe [format {pblaze3_i/ila_reset50/inst/probe0[%d]} $bit]
        pblaze_diag_same_net [pblaze_diag_pin $name/Q] [pblaze_diag_pin $probe] status_probe_$bit $report
      }
    }
  }
  if {[lsort $actual] ne [lsort $expected]} {error "diagnostic status synchronizer cell set differs"}
  puts $report "STATUS_SYNC_3X9=PASS"
}
proc pblaze_assert_diagnostic_cores {rows report} {
  set expected {dbg_hub}
  foreach row $rows {lappend expected pblaze3_i/[lindex $row 0]}
  if {[lsort [get_debug_cores]] ne [lsort $expected]} {error "diagnostic exact debug core set differs"}
  foreach row $rows {
    if {[llength $row] != 4} {error "malformed diagnostic core row"}
    lassign $row name source period widths
    set full pblaze3_i/$name
    set core [get_debug_cores $full]
    pblaze_diag_property [pblaze_diag_cell $full] REF_NAME pblaze3_${name}_0
    pblaze_diag_property $core C_DATA_DEPTH 1024
    pblaze_diag_property $core C_INPUT_PIPE_STAGES 1
    pblaze_diag_property $core C_ADV_TRIGGER false
    pblaze_diag_property $core C_EN_STRG_QUAL true
    pblaze_diag_property $core C_TRIGIN_EN false
    pblaze_diag_property $core C_TRIGOUT_EN false
    set uuid [get_property UUID $core]
    if {![regexp {^[[:xdigit:]]{32}$} $uuid] || $uuid eq "00000000000000000000000000000000"} {error "diagnostic ILA UUID missing/invalid"}
    puts $report [join [list CORE $full $uuid 1024 1] [format %c 9]]
    set expected_ports [list $full/clk]
    set index 0
    foreach width $widths {
      set probe [get_debug_ports $full/probe$index]
      pblaze_diag_property $probe PORT_WIDTH $width
      pblaze_diag_property $probe PROBE_TYPE DATA_AND_TRIGGER
      lappend expected_ports $full/probe$index
      puts $report [join [list PROBE $full $index $width] [format %c 9]]
      incr index
    }
    if {$index < 1 || $index > 5 || [lsort [get_debug_ports -of_objects $core]] ne [lsort $expected_ports]} {error "diagnostic exact debug port set differs: $full"}
    set pin [pblaze_diag_pin $full/inst/clk]
    pblaze_diag_same_net [pblaze_diag_pin $source] $pin $name.domain_clock $report
    pblaze_diag_clock $pin $period $report
  }
  puts $report "DIAGNOSTIC_CORES=PASS"
}
proc pblaze_assert_diagnostic_physical {rows report} {
  pblaze_assert_diagnostic_raw_clock $report
  # This single-domain AXI image has no status synchronizer or status ILA.
  pblaze_assert_diagnostic_cores $rows $report
  puts $report "DIAGNOSTIC_PHYSICAL=PASS"
}
set diagnostic_rows {
  {ila_mig200 pblaze3_i/mig/ui_clk 5 {53 147 8 50 137}}
}
pblaze_assert_diagnostic_physical $diagnostic_rows stdout
file mkdir {/work/builds/pblaze3-single-ila-opt-mig-a1}
write_debug_probes -force {/work/builds/pblaze3-single-ila-opt-mig-a1/preview.ltx}
set fd [open {/work/builds/pblaze3-single-ila-opt-mig-a1/preview.ltx} r]
puts PREVIEW_LTX_BEGIN
puts [read $fd]
close $fd
puts PREVIEW_LTX_END
puts "DCP_AFTER=[exec sha256sum $dcp]"
puts SINGLE_ILA_OPT_REVIEW_COMPLETE
} reason options]} {puts stderr "SINGLE_ILA_OPT_REVIEW_FAILED=$reason"; puts stderr [dict get $options -errorinfo];exit 1}
exit 0

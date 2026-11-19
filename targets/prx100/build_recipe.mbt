///|
fn build_tcl(
  sources : ArrayView[String],
  hardware : @ir.Module,
) -> String raise {
  let stages : Array[String] = []
  for primitive in hardware.cdc_primitives() {
    if primitive is BitSynchronizer(sync) {
      for id in sync.stages() {
        stages.push("system_i/shell_i/lc_n\{id.ordinal()}_reg")
      }
    }
  }
  guard stages.length() == 2 else {
    raise MissingMapping("UART synchronizer stages")
  }
  let out = StringBuilder()
  let prelude =
    #|# Generated tool input. Orchestration and identity checks live in .mbtx.
    #|if {[version -short] ne "2025.2"} {error "Vivado release mismatch: require 2025.2"}
    #|if {$argc != 1} {error "expected fresh output directory"}
    #|set bundle [file dirname [file normalize [info script]]]
    #|set output [file normalize [lindex $argv 0]]
    #|cd $output
    #|set_param general.maxThreads 1
    #|set identity [open tool-version.txt w]
    #|puts $identity [version]
    #|close $identity
    #|
  out.write_string(prelude)
  for path in sources {
    out.write_string("read_verilog -sv [file join $bundle {\{path}}]\n")
  }
  let synthesis =
    #|read_verilog -sv [file join $bundle prx100_top.sv]
    #|read_xdc [file join $bundle prx100.xdc]
    #|synth_design -top prx100_top -part xc7a100tfgg676-2 -flatten_hierarchy none
    #|set aperture_bram [get_cells -hierarchical -filter {NAME =~ */shell_i/* && REF_NAME =~ RAMB*}]
    #|if {![llength $aperture_bram]} {error "board host aperture did not map to block RAM"}
    #|
  out.write_string(synthesis)
  out.write_string("set sync_cells [get_cells {\{stages.join(" ")}}]\n")
  out.write_string(
    "if {[llength $sync_cells] != 2} {error \"UART synchronizer cells missing\"}\n",
  )
  out.write_string(
    "set_property ASYNC_REG TRUE $sync_cells\nset_property DONT_TOUCH TRUE $sync_cells\n",
  )
  out.write_string(
    "set_false_path -from [get_ports uart_rx] -to [get_pins {\{stages[0]}/D}]\n",
  )
  let implementation =
    #|report_utilization -hierarchical -file utilization-synth.rpt
    #|opt_design -directive Default
    #|place_design -directive Default
    #|phys_opt_design -directive Default
    #|route_design -directive Default
    #|report_utilization -hierarchical -file utilization-route.rpt
    #|report_timing_summary -delay_type min_max -report_unconstrained -file timing.rpt
    #|report_cdc -file cdc.rpt
    #|report_drc -file drc.rpt
    #|check_timing -verbose -file check-timing.rpt
    #|set coverage [check_timing -override_defaults {no_clock unconstrained_internal_endpoints} -return_string]
    #|set coverage_counts [regexp -all -inline {\(([0-9]+)\)} $coverage]
    #|if {![string match *no_clock* $coverage] || ![string match *unconstrained_internal_endpoints* $coverage] || [llength $coverage_counts] < 4} {error "unrecognized timing coverage report"}
    #|foreach {label count} $coverage_counts {if {$count != 0} {error "unconstrained internal timing endpoints"}}
    #|if {[llength [get_timing_paths -delay_type max -slack_lesser_than 0 -max_paths 1]]} {error "setup timing failed"}
    #|if {[llength [get_timing_paths -delay_type min -slack_lesser_than 0 -max_paths 1]]} {error "hold timing failed"}
    #|if {![llength [get_timing_paths -delay_type max -max_paths 1]]} {error "no timed paths"}
    #|set violations [get_drc_violations -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]
    #|if {[llength $violations]} {error "implementation DRC failed"}
    #|write_checkpoint -force routed.dcp
    #|write_bitstream -force prx100.bit
    #|set done [open BUILD_COMPLETE w]
    #|puts $done "PRX100 implementation gates passed; physical execution remains unclaimed"
    #|close $done
    #|exit
    #|
  out.write_string(implementation)
  out.to_string()
}

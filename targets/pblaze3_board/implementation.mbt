///|
fn implementation_tcl() -> String {
  (
    #|launch_runs synth_1 -jobs 1
    #|wait_on_run synth_1
    #|if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "synthesis failed"}
    #|set child_report [open child-run-gates.txt w]
    #|pblaze_assert_run_logs [get_runs -filter {IS_SYNTHESIS == 1}] synthesis $child_report
    #|open_run synth_1
    #|pblaze_assert_reset_clock $child_report
    #|set reset_report [open reset-boundary-properties.txt a]
    #|pblaze_assert_transport_reset_boundary synthesis $reset_report
    #|close $reset_report
    #|foreach {port expected} {clk_in1_50M 20.000 {CLK_IN_D_0_clk_p[0]} 10.000} {
    #|  set clocks [get_clocks -quiet -of_objects [get_ports $port]]
    #|  if {[llength $clocks] != 1 || abs([get_property PERIOD $clocks] - $expected) > 0.001} {error "missing/ambiguous/wrong primary clock: $port"}
    #|  puts $child_report "PRIMARY_CLOCK $port [get_property NAME $clocks] [get_property PERIOD $clocks]"
    #|}
    #|close_design
    #|launch_runs impl_1 -to_step route_design -jobs 1
    #|wait_on_run impl_1
    #|if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "implementation failed"}
    #|pblaze_assert_run_logs [get_runs impl_1] implementation $child_report
    #|open_run impl_1
    #|pblaze_assert_reset_clock $child_report
    #|set reset_report [open reset-boundary-properties.txt a]
    #|pblaze_assert_transport_reset_boundary routed $reset_report
    #|close $reset_report
    #|close $child_report
    #|report_utilization -hierarchical -file utilization.rpt
    #|report_timing_summary -delay_type min_max -report_unconstrained -file timing.rpt
    #|report_cdc -details -file cdc.rpt
    #|report_drc -file drc.rpt
    #|report_clock_interaction -file clock-interaction.rpt
    #|report_clocks -file clocks.rpt
    #|write_xdc -force applied-constraints.xdc
    #|# AMD documents a Critical Warning for every pulse-width/min-period/
    #|# max-skew violation when -warn_on_violation is enabled. Count the whole
    #|# parent process, not a before/after delta that could miss a counter reset.
    #|report_pulse_width -warn_on_violation -verbose -file pulse-width.rpt
    #|set critical_count [get_msg_config -count -severity {CRITICAL WARNING}]
    #|if {![string is integer -strict $critical_count] || $critical_count != 0} {error "pulse-width or prior critical warning prevents bitstream"}
    #|check_timing -verbose -file check-timing.rpt
    #|set coverage [check_timing -override_defaults {no_clock unconstrained_internal_endpoints} -return_string]
    #|set counts [regexp -all -inline {\(([0-9]+)\)} $coverage]
    #|if {![string match *no_clock* $coverage] || ![string match *unconstrained_internal_endpoints* $coverage] || [llength $counts] < 4} {error "unrecognized timing coverage report"}
    #|foreach {label count} $counts {if {$count != 0} {error "unconstrained internal timing endpoints"}}
    #|if {![llength [get_timing_paths -delay_type max -max_paths 1]]} {error "no timed paths"}
    #|if {[llength [get_timing_paths -delay_type max -slack_lesser_than 0 -max_paths 1]]} {error "setup timing failed"}
    #|if {[llength [get_timing_paths -delay_type min -slack_lesser_than 0 -max_paths 1]]} {error "hold timing failed"}
    #|if {[llength [get_drc_violations -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]]} {error "implementation DRC failed"}
    #|# A CDC report is retained for review; generating it alone is not CDC proof.
    #|write_checkpoint -force routed.dcp
    #|write_bitstream -force pblaze3.bit
    #|set final_critical [get_msg_config -count -severity {CRITICAL WARNING}]
    #|set final_errors [get_msg_config -count -severity ERROR]
    #|if {![string is integer -strict $final_critical] || $final_critical != 0 || ![string is integer -strict $final_errors] || $final_errors != 0} {error "final bitstream warnings/errors prevent acceptance"}
    #|if {![file isfile pblaze3.bit] || [file size pblaze3.bit] == 0} {error "bitstream missing"}
    #|set done [open BUILD_COMPLETE w]
    #|puts $done "Routed timing coverage/setup/hold/pulse and DRC passed; nonempty bitstream and final error/critical-warning count checked; physical execution unclaimed; independent CDC review still required"
    #|close $done
    #|exit
    #|
  )
}

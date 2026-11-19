if {[catch {
set output /work/builds/pblaze3-review-routed-a4-20261026-a1
if {[file exists $output]} {error {fresh diagnostic output required}}
file mkdir $output
set_param general.maxThreads 1
open_checkpoint /work/builds/pblaze3-work-20261026-v20261-build-a4/project/pblaze3.runs/impl_1/pblaze3_wrapper_routed.dcp
set report [open $output/reset-fanout.txt w]
set roots [get_pins -hierarchical -filter {NAME =~ */transport_reset_gate/*/O}]
if {[llength $roots] != 1} {error "expected exactly one transport reset LUT output: $roots"}
puts $report "TRANSPORT_RESET_SOURCE=$roots"
foreach pin [lsort [all_fanout -flat -endpoints_only -from $roots]] {
  set cell [get_cells -of_objects $pin]
  puts $report "RESET_ENDPOINT=$pin CELL=$cell REF_NAME=[get_property REF_NAME $cell] ASYNC_REG=[get_property ASYNC_REG $cell]"
}
foreach pattern {*reset_n_reg1_reg *reset_n_reg2_reg *user_reset_int_reg *user_reset_out_reg *pl_received_hot_rst_q_reg *pl_phy_lnk_up_q_reg *user_lnk_up_int_reg} {
  foreach cell [get_cells -hierarchical -filter "NAME =~ $pattern"] {
    puts $report "RESET_CELL=$cell REF_NAME=[get_property REF_NAME $cell] ASYNC_REG=[get_property ASYNC_REG $cell]"
    foreach pin [get_pins -of_objects $cell] {
      puts $report "CELL_PIN=$pin NET=[get_nets -of_objects $pin]"
    }
    set q [get_pins -of_objects $cell -filter {DIRECTION == OUT}]
    puts $report "CELL_OUTPUT_ENDPOINTS=$cell [lsort [all_fanout -flat -endpoints_only -from $q]]"
  }
}
close $report
puts REVIEW_RESET_FANOUT_WRITTEN
report_timing -slack_lesser_than 0 -max_paths 30 -nworst 30 -file $output/failing-paths.rpt
report_clock_interaction -file $output/clock-interaction.rpt
report_clocks -file $output/clocks.rpt
check_timing -verbose -file $output/check-timing.rpt
report_pulse_width -warn_on_violation -verbose -file $output/pulse-width.rpt
report_cdc -details -file $output/cdc.rpt
close_design
puts REVIEW_ROUTED_DIAGNOSTICS_COMPLETE
exit 0
} failure]} {puts "REVIEW_ROUTED_DIAGNOSTICS_ERROR=$failure"; exit 1}

if {[catch {
set output {/work/builds/pblaze3-pulse-20261026-a1-positive}
set period 20.0
if {[version -short] ne "2025.2"} {error "Vivado 2025.2 required"}
if {[file exists $output]} {error "fresh work directory required"}
file mkdir $output
cd $output
set_param general.maxThreads 1
puts "PULSE_TOOL_VERSION_BEGIN"
puts [version]
puts "PULSE_TOOL_VERSION_END"
puts "PULSE_PART=xc7a100tfgg676-2"
puts "PULSE_PERIOD_NS=$period"
set source [open pulse-fixture.v w]
puts $source {module pulse_fixture(input wire clk, input wire data, output reg result);
  always @(posedge clk) result <= data;
endmodule
}
close $source
read_verilog pulse-fixture.v
synth_design -top pulse_fixture -part xc7a100tfgg676-2
if {[llength [get_cells -hierarchical -filter {REF_NAME == FDRE}]] != 1} {
  error "expected exactly one real FDRE timing endpoint"
}
create_clock -name fixture_clock -period $period [get_ports clk]
puts "PULSE_GATE_REACHED"
set failed [catch {
report_pulse_width -warn_on_violation -verbose -file pulse-width.rpt
set pulse_warnings [get_msg_config -count -severity {CRITICAL WARNING}]
puts "PULSE_WARNING_COUNT=$pulse_warnings"
if {![string is integer -strict $pulse_warnings] || $pulse_warnings != 0} {
  error "pulse-width gate or preceding critical warning failed"
}
} gate_error]
if {![file isfile pulse-width.rpt]} {error "pulse-width report missing"}
set report [open pulse-width.rpt r]
puts "PULSE_REPORT_BEGIN"
puts [read $report]
close $report
puts "PULSE_REPORT_END"
if {$failed} {
  puts "PULSE_GATE_REJECTED=$gate_error"
  exit 2
}
puts "PULSE_GATE_ACCEPTED"
exit 0
} unexpected]} {
  puts "PULSE_PROBE_ERROR=$unexpected"
  exit 1
}

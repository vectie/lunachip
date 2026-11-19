///|
/// Child processes have independent message counters. Their completed logs
/// must pass before implementation or bitstream; parent counts are not enough.
fn run_gates_tcl() -> String {
  (
    #|proc pblaze_assert_reset_clock {report} {
    #|  set pin [get_pins -quiet {pblaze3_i/transport_supervisor/clock50}]
    #|  if {[llength $pin] != 1} {error "missing/ambiguous independent reset clock pin"}
    #|  set clocks [get_clocks -quiet -of_objects $pin]
    #|  if {[llength $clocks] != 1 || abs([get_property PERIOD $clocks] - 20.000) > 0.001} {error "reset supervisor requires exactly50MHz"}
    #|  if {![get_property IS_GENERATED $clocks] || [get_property MASTER_CLOCK $clocks] ne "clk_in1_50M"} {error "reset supervisor clock must derive directly from board oscillator"}
    #|  set master [get_clocks -quiet clk_in1_50M]
    #|  if {[llength $master] != 1 || [get_property IS_GENERATED $master] || abs([get_property PERIOD $master] - 20.000) > 0.001} {error "reset supervisor master clock differs"}
    #|  puts $report "RESET_CLOCK_PASS [get_property NAME $clocks] PERIOD=[get_property PERIOD $clocks] MASTER=[get_property MASTER_CLOCK $clocks]"
    #|  flush $report
    #|}
    #|proc pblaze_assert_child_log {path phase report} {
    #|  if {![file isfile $path] || ![file readable $path]} {error "missing/unreadable child log: $path"}
    #|  set channel [open $path r]
    #|  set text [read $channel]
    #|  close $channel
    #|  if {[regexp -line {^(CRITICAL WARNING|ERROR):} $text]} {error "child critical warning/error: $path"}
    #|  foreach {match count} [regexp -all -inline {([0-9]+) Critical Warnings} $text] {
    #|    if {$count != 0} {error "nonzero child critical-warning summary: $path"}
    #|  }
    #|  foreach {match count} [regexp -all -inline {([0-9]+) Errors encountered} $text] {
    #|    if {$count != 0} {error "nonzero child error summary: $path"}
    #|  }
    #|  if {![regexp {INFO: \[Common 17-206\] Exiting Vivado} $text]} {error "incomplete child log: $path"}
    #|  if {$phase eq "synthesis"} {
    #|    if {![string match {*synth_design completed successfully*} $text] && ![string match {*Using cached IP synthesis design*} $text]} {error "missing successful synthesis completion: $path"}
    #|  } elseif {$phase eq "implementation"} {
    #|    if {![string match {*route_design completed successfully*} $text]} {error "missing successful route completion: $path"}
    #|  } else {error "unknown child log phase: $phase"}
    #|  puts $report "CHILD_LOG_PASS $phase $path"
    #|  flush $report
    #|}
    #|proc pblaze_assert_cache_logs {directory previous report} {
    #|  set count 0
    #|  foreach path [lsort [glob -nocomplain -directory $directory *]] {
    #|    if {[file type $path] eq "link"} {error "symlink in native IP cache"}
    #|    if {[file isdirectory $path]} {
    #|      incr count [pblaze_assert_cache_logs $path $previous $report]
    #|    } elseif {[file extension $path] eq ".dcp"} {
    #|      set ip [file rootname [file tail $path]]
    #|      set key [file tail [file dirname $path]]
    #|      set log [file join $previous project pblaze3.runs ${ip}_synth_1 runme.log]
    #|      pblaze_assert_child_log $log synthesis $report
    #|      set channel [open $log r]; set text [read $channel]; close $channel
    #|      set exact_key 0
    #|      foreach {match token} [regexp -all -inline {cache-ID = ([[:xdigit:]]+)} $text] {
    #|        if {$token eq $key} {set exact_key 1}
    #|      }
    #|      if {!$exact_key} {error "cache key has no original successful producer: $path"}
    #|      puts $report "NATIVE_CACHE $ip $key $path"
    #|      incr count
    #|    }
    #|  }
    #|  return $count
    #|}
    #|proc pblaze_assert_run_logs {runs phase report} {
    #|  if {![llength $runs]} {error "no $phase runs to verify"}
    #|  foreach run $runs {
    #|    if {[get_property PROGRESS $run] ne "100%"} {error "incomplete child run: $run"}
    #|    pblaze_assert_child_log [file join [get_property DIRECTORY $run] runme.log] $phase $report
    #|  }
    #|}
    #|
  )
}

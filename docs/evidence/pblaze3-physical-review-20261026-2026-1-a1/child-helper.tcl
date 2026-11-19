proc pblaze_assert_child_log {path phase report} {
  if {![file isfile $path] || ![file readable $path]} {error "missing/unreadable child log: $path"}
  set channel [open $path r]
  set text [read $channel]
  close $channel
  if {[regexp -line {^(CRITICAL WARNING|ERROR):} $text]} {error "child critical warning/error: $path"}
  foreach {match count} [regexp -all -inline {([0-9]+) Critical Warnings} $text] {
    if {$count != 0} {error "nonzero child critical-warning summary: $path"}
  }
  foreach {match count} [regexp -all -inline {([0-9]+) Errors encountered} $text] {
    if {$count != 0} {error "nonzero child error summary: $path"}
  }
  if {![regexp {INFO: \[Common 17-206\] Exiting Vivado} $text]} {error "incomplete child log: $path"}
  if {$phase eq "synthesis"} {
    if {![string match {*synth_design completed successfully*} $text] && ![string match {*Using cached IP synthesis design*} $text]} {error "missing successful synthesis completion: $path"}
  } elseif {$phase eq "implementation"} {
    if {![string match {*route_design completed successfully*} $text]} {error "missing successful route completion: $path"}
  } else {error "unknown child log phase: $phase"}
  puts $report "CHILD_LOG_PASS $phase $path"
  flush $report
}
proc pblaze_assert_run_logs {runs phase report} {
  if {![llength $runs]} {error "no $phase runs to verify"}
  foreach run $runs {
    if {[get_property PROGRESS $run] ne "100%"} {error "incomplete child run: $run"}
    pblaze_assert_child_log [file join [get_property DIRECTORY $run] runme.log] $phase $report
  }
}

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

if {[catch {
set work /work/builds/pblaze3-work-20261026-v20261-build-a1
set runs $work/project/pblaze3.runs
open_project -read_only $work/project/pblaze3.xpr
set project [current_project]
foreach property [list_property $project] {
  if {[string match *IP* $property] || [string match *CACHE* $property]} {
    puts "REVIEW_PROJECT_PROPERTY $property=[get_property $property $project]"
  }
}
foreach name {pblaze3_xdma_0_synth_1 pblaze3_mig_0_synth_1} {
  pblaze_assert_run_logs [get_runs $name] synthesis stdout
  puts "REVIEW_POSITIVE=$name"
}
if {![catch {pblaze_assert_run_logs [get_runs synth_1] synthesis stdout} reason]} {error {top critical-warning negative control accepted}}
puts "REVIEW_NEGATIVE_TOP=$reason"
set fixture /work/builds/pblaze3-review-childguard-20261026-a1
if {[file exists $fixture]} {error {fixture path already exists}}
file mkdir $fixture
set channel [open $runs/pblaze3_xdma_0_synth_1/runme.log r]
set clean [read $channel]
close $channel
set channel [open $fixture/truncated.log {WRONLY CREAT EXCL}]
puts -nonewline $channel [string range $clean 0 1000]
close $channel
set channel [open $fixture/summary.log {WRONLY CREAT EXCL}]
puts $channel "$clean\n1 Critical Warnings, 0 Errors encountered."
close $channel
foreach name {missing truncated summary} {
  if {![catch {pblaze_assert_child_log $fixture/$name.log synthesis stdout} reason]} {error "negative control accepted: $name"}
  puts "REVIEW_NEGATIVE_[string toupper $name]=$reason"
}
if {![catch {pblaze_assert_child_log $runs/pblaze3_xdma_0_synth_1/runme.log implementation stdout} reason]} {error {wrong phase negative control accepted}}
puts "REVIEW_NEGATIVE_PHASE=$reason"
open_run synth_1
foreach clock [get_clocks] {
  if {![get_property IS_GENERATED $clock]} {
    foreach property {NAME PERIOD SOURCE_PINS FILE_NAME LINE_NUMBER} {
      puts "REVIEW_CLOCK_PROPERTY $clock $property=[get_property $property $clock]"
    }
  }
}
close_project
puts REVIEW_CHILD_GUARD_PASS
exit 0
} failure]} {puts "REVIEW_CHILD_GUARD_ERROR=$failure"; exit 1}

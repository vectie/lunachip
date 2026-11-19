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
proc pblaze_assert_cache_logs {directory previous report} {
  set count 0
  foreach path [lsort [glob -nocomplain -directory $directory *]] {
    if {[file type $path] eq "link"} {error "symlink in native IP cache"}
    if {[file isdirectory $path]} {
      incr count [pblaze_assert_cache_logs $path $previous $report]
    } elseif {[file extension $path] eq ".dcp"} {
      set ip [file rootname [file tail $path]]
      set key [file tail [file dirname $path]]
      set log [file join $previous project pblaze3.runs ${ip}_synth_1 runme.log]
      pblaze_assert_child_log $log synthesis $report
      set channel [open $log r]; set text [read $channel]; close $channel
      if {[string first "cache-ID = $key" $text] < 0} {error "cache key has no original successful producer: $path"}
      puts $report "NATIVE_CACHE $ip $key $path"
      incr count
    }
  }
  return $count
}
proc pblaze_assert_run_logs {runs phase report} {
  if {![llength $runs]} {error "no $phase runs to verify"}
  foreach run $runs {
    if {[get_property PROGRESS $run] ne "100%"} {error "incomplete child run: $run"}
    pblaze_assert_child_log [file join [get_property DIRECTORY $run] runme.log] $phase $report
  }
}

if {[catch {
set previous /work/builds/pblaze3-work-20261026-v20261-build-a1
set cache $previous/project/pblaze3.cache/ip
set count [pblaze_assert_cache_logs $cache $previous stdout]
if {$count < 1} {error {positive cache has no DCP entries}}
puts "REVIEW_CACHE_POSITIVE_COUNT=$count"
set dcps [lsort [glob $cache/2026.1/*/*/*/*.dcp]]
set source [lindex $dcps 0]
set key [file tail [file dirname $source]]
set ip [file rootname [file tail $source]]
set fixture /work/builds/pblaze3-review-cacheguard-20261026-a1
if {[file exists $fixture]} {error {fixture path already exists}}
file mkdir $fixture/cache/$key
set channel [open $fixture/cache/$key/$ip.dcp {WRONLY CREAT EXCL}]
puts $channel {Negative-control placeholder only; not a Vivado checkpoint.}
close $channel
set producer [file join $previous project pblaze3.runs ${ip}_synth_1 runme.log]
set channel [open $producer r]; set text [read $channel]; close $channel
set producer_dir [file join $fixture project pblaze3.runs ${ip}_synth_1]
file mkdir $producer_dir
set channel [open $producer_dir/runme.log {WRONLY CREAT EXCL}]
puts -nonewline $channel [string map [list "cache-ID = $key" {cache-ID = intentionally-wrong}] $text]
close $channel
if {![catch {pblaze_assert_cache_logs $fixture/cache $fixture stdout} reason]} {error {wrong producer key accepted}}
puts "REVIEW_CACHE_NEGATIVE_KEY=$reason"
if {![string match {cache key has no original successful producer:*} $reason]} {error {wrong negative key failure}}
if {![catch {pblaze_assert_cache_logs $fixture/cache $fixture/missing stdout} reason]} {error {missing producer accepted}}
puts "REVIEW_CACHE_NEGATIVE_MISSING=$reason"
if {![string match {missing/unreadable child log:*} $reason]} {error {wrong missing producer failure}}
puts REVIEW_CACHE_GUARD_PASS
exit 0
} failure]} {puts "REVIEW_CACHE_GUARD_ERROR=$failure"; exit 1}

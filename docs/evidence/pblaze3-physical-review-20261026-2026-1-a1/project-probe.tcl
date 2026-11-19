if {[catch {
open_project -read_only /work/builds/pblaze3-work-20261026-v20261-build-a1/project/pblaze3.xpr
foreach name {synth_1 impl_1 pblaze3_xdma_0_synth_1 pblaze3_mig_0_synth_1} {
  set run [get_runs $name]
  puts "REVIEW_RUN=$run PROPERTIES=[list_property $run]"
  foreach property [list_property $run] {
    if {[string match *WARN* $property] || [string match *ERR* $property] || $property in {STATUS PROGRESS DIRECTORY}} {
      puts "REVIEW_RUN_PROPERTY $run $property=[get_property $property $run]"
    }
  }
}
open_run synth_1
report_clocks
foreach clock [get_clocks] {
  puts "REVIEW_CLOCK=$clock PROPERTIES=[list_property $clock]"
  foreach property [list_property $clock] {
    if {$property in {NAME PERIOD IS_GENERATED SOURCE_PINS SOURCE_PORTS MASTER_CLOCK}} {
      puts "REVIEW_CLOCK_PROPERTY $clock $property=[get_property $property $clock]"
    }
  }
}
close_project
puts REVIEW_PROJECT_PASS
exit 0
} failure]} {puts "REVIEW_PROJECT_ERROR=$failure"; exit 1}

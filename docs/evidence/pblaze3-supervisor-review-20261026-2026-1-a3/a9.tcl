# Derived reset-output copies only: use Vivado replication provenance,
# require exact original parent/leaf, and prove every input is identical.
# This helper changes no timing constraint or checkpoint.
proc pblaze_reset_output_replicas {report} {
  set base [pblaze_reset_base]
  set original [pblaze_reset_exact_cell $base/user_reset_out_reg FDPE $report]
  set related [get_cells -quiet -include_replicated_objects $original]
  if {[lsearch -exact $related $original] < 0} {error "reset replication lookup omitted original"}
  set result {}
  foreach cell [lsort -unique $related] {
    if {$cell eq $original} {continue}
    set parent [string range $cell 0 [expr {[string last / $cell]-1}]]
    set origin [get_property ORIG_CELL_NAME $cell]
    set optimization [get_property PHYS_OPT_MODIFIED $cell]
    puts $report "RESET_REPLICA $cell parent=$parent origin=$origin optimization=$optimization"
    if {$parent ne $base || $origin ne "user_reset_out_reg" || [get_property IS_ORIG_CELL $cell] ne "0" || [get_property ORIG_REF_NAME $cell] ne "FDPE" || $optimization ne "FANOUT_OPT"} {error "reset replica provenance differs: $cell"}
    if {[get_property IS_ORIG_CELL $original] ne "1" || [get_property PHYS_OPT_MODIFIED $original] ne "FANOUT_OPT"} {error "reset original fanout provenance differs"}
    pblaze_reset_exact_cell $cell FDPE $report
    foreach property {INIT IS_C_INVERTED IS_PRE_INVERTED} {
      if {$property in [list_property $original]} {
        set value [get_property $property $original]
        if {$property ni [list_property $cell] || [get_property $property $cell] ne $value} {error "reset replica property differs: $cell $property"}
        puts $report "RESET_REPLICA_PROPERTY $cell $property=$value"
      }
    }
    set inputs {}
    foreach pin [get_pins -of_objects $cell -filter {DIRECTION == IN}] {lappend inputs [get_property REF_PIN_NAME $pin]}
    if {[lsort $inputs] ne {C CE D PRE}} {error "reset replica input interface differs: $cell"}
    foreach suffix {C CE D PRE} {pblaze_reset_same_net $original/$suffix $cell/$suffix $report}
    lappend result $cell/PRE
  }
  puts $report "RESET_REPLICA_COUNT=[llength $result]"
  return [lsort $result]
}

# Exact asynchronous sys_rst_n boundary of the reviewed 7-series PCIe wrapper.
# PG054 defines asynchronous fundamental reset; PG195 forbids depending on
# axi_aclk for reset release. No payload or clock-domain-wide timing exception.
proc pblaze_reset_base {} {
  return pblaze3_i/xdma/inst/pblaze3_xdma_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst
}
proc pblaze_reset_expected_pins {} {
  set base [pblaze_reset_base]
  set result {}
  foreach suffix {
    gt_top_i/pipe_wrapper_i/reset_n_reg1_reg/CLR
    gt_top_i/pipe_wrapper_i/reset_n_reg2_reg/CLR
    pl_phy_lnk_up_q_reg/R
    pl_received_hot_rst_q_reg/R
    user_lnk_up_int_reg/R
    user_reset_int_reg/PRE
    user_reset_out_reg/PRE
  } {lappend result $base/$suffix}
  return [lsort $result]
}
proc pblaze_reset_exact_pin {name} {
  set found [get_pins -quiet -hierarchical -filter [format {NAME == "%s"} $name]]
  if {[llength $found] != 1} {error "missing/ambiguous reset pin: $name"}
  return $found
}
proc pblaze_reset_exact_cell {name expected report} {
  set cell [get_cells -quiet -hierarchical -filter [format {NAME == "%s"} $name]]
  if {[llength $cell] != 1} {error "missing/ambiguous reset primitive: $name"}
  set actual [get_property REF_NAME $cell]
  puts $report "RESET_PRIMITIVE $name actual=$actual expected=$expected"
  if {$actual ne $expected} {error "wrong reset primitive: $name $actual expected $expected"}
  return $cell
}
proc pblaze_reset_same_net {first second report} {
  set a [lsort [get_nets -segments -of_objects [pblaze_reset_exact_pin $first]]]
  set b [lsort [get_nets -segments -of_objects [pblaze_reset_exact_pin $second]]]
  puts $report "RESET_NET first=$first second=$second segments=[llength $a] matched=[expr {$a eq $b}]"
  if {![llength $a] || $a ne $b} {error "reset stage connection differs: $first $second"}
}
proc pblaze_reset_require_vcc {pin report} {
  set nets [get_nets -segments -of_objects [pblaze_reset_exact_pin $pin]]
  set starts [get_pins -leaf -of_objects $nets -filter {DIRECTION == OUT}]
  set cells [get_cells -of_objects $starts]
  puts $report "RESET_CONSTANT $pin sources=$starts cells=$cells"
  if {[llength $starts] != 1 || [llength $cells] != 1 || [get_property REF_NAME $cells] ne "VCC"} {error "reset stage input is not constant one: $pin"}
}
proc pblaze_assert_transport_reset_boundary {phase report} {
  if {$phase ni {synthesis routed}} {error "unknown reset guard phase: $phase"}
  set base [pblaze_reset_base]
  set boundary [pblaze_reset_exact_pin {pblaze3_i/transport_reset_gate/Res[0]_INST_0/O}]
  set boundary_cell [get_cells -of_objects $boundary]
  if {[llength $boundary_cell] != 1 || [get_property REF_NAME $boundary_cell] ne "LUT2"} {error "unexpected final transport-reset gate primitive"}
  set expected [pblaze_reset_expected_pins]
  set replicas {}
  if {$phase eq "routed"} {
    set replicas [pblaze_reset_output_replicas $report]
    set expected [lsort [concat $expected $replicas]]
  }
  if {$phase eq "synthesis"} {
    lappend expected $base/user_lnk_up_mux_reg/R
    lappend expected pblaze3_i/xdma/inst/sys_rst_n_reg_reg/CLR
    lappend expected pblaze3_i/xdma/inst/sys_rst_n_reg2_reg/CLR
    set expected [lsort $expected]
  }
  set actual [lsort [all_fanout -flat -endpoints_only -from $boundary]]
  puts $report "RESET_BOUNDARY=$boundary"
  puts $report "RESET_BOUNDARY_EXPECTED=$expected"
  puts $report "RESET_BOUNDARY_ACTUAL=$actual"
  set count [expr {$phase eq "synthesis" ? 10 : 7 + [llength $replicas]}]
  if {[llength $expected] != $count || $actual ne $expected} {error "transport reset has unexpected complete fanout"}
  if {$phase eq "synthesis"} {
    pblaze_reset_exact_cell $base/user_lnk_up_mux_reg FDRE $report
    pblaze_reset_exact_cell pblaze3_i/xdma/inst/sys_rst_n_reg_reg FDCE $report
    pblaze_reset_exact_cell pblaze3_i/xdma/inst/sys_rst_n_reg2_reg FDCE $report
    foreach dead [list $base/user_lnk_up_mux_reg/Q pblaze3_i/xdma/inst/sys_rst_n_reg2_reg/Q] {
      set next [all_fanout -flat -endpoints_only -from [pblaze_reset_exact_pin $dead]]
      puts $report "RESET_DEAD_OUTPUT $dead endpoints=$next"
      if {[llength $next]} {error "synthesis-only reset output unexpectedly used: $dead"}
    }
    set next [all_fanout -flat -endpoints_only -from [pblaze_reset_exact_pin pblaze3_i/xdma/inst/sys_rst_n_reg_reg/Q]]
    puts $report "RESET_DEAD_CHAIN endpoints=$next"
    if {$next ne "pblaze3_i/xdma/inst/sys_rst_n_reg2_reg/D"} {error "synthesis-only shadow reset chain unexpectedly used"}
  }
  foreach suffix {gt_top_i/pipe_wrapper_i/reset_n_reg1_reg gt_top_i/pipe_wrapper_i/reset_n_reg2_reg} {
    set cell [pblaze_reset_exact_cell $base/$suffix FDCE $report]
    if {[get_property ASYNC_REG $cell] ne "1"} {error "PIPE reset synchronizer lacks ASYNC_REG"}
    pblaze_reset_require_vcc $base/$suffix/CE $report
  }
  set first $base/gt_top_i/pipe_wrapper_i/reset_n_reg1_reg
  set second $base/gt_top_i/pipe_wrapper_i/reset_n_reg2_reg
  pblaze_reset_require_vcc $first/D $report
  pblaze_reset_same_net $first/Q $second/D $report
  pblaze_reset_same_net $first/C $second/C $report
  set next [all_fanout -flat -endpoints_only -from [pblaze_reset_exact_pin $first/Q]]
  if {$next ne "$second/D"} {error "first PIPE reset stage bypasses final synchronizer stage"}
  foreach suffix {pl_phy_lnk_up_q_reg pl_received_hot_rst_q_reg user_lnk_up_int_reg} {
    pblaze_reset_exact_cell $base/$suffix FDRE $report
    pblaze_reset_same_net $base/$suffix/C $base/user_reset_out_reg/C $report
  }
  foreach suffix {user_reset_int_reg user_reset_out_reg} {
    pblaze_reset_exact_cell $base/$suffix FDPE $report
  }
  pblaze_reset_same_net $base/user_reset_int_reg/Q $base/user_reset_out_reg/D $report
  pblaze_reset_same_net $base/user_reset_int_reg/C $base/user_reset_out_reg/C $report
  foreach {status cdc} {pl_phy_lnk_up_q_reg phy_lnk_up_cdc pl_received_hot_rst_q_reg pl_received_hot_rst_cdc} {
    set first [format {%s/%s/syncstages_ff_reg[0]} $base $cdc]
    set second [format {%s/%s/syncstages_ff_reg[1]} $base $cdc]
    foreach name [list $first $second] {
      set cell [pblaze_reset_exact_cell $name FDRE $report]
      if {[get_property ASYNC_REG $cell] ne "1"} {error "status input synchronizer lacks ASYNC_REG"}
    }
    pblaze_reset_same_net $first/Q $second/D $report
    pblaze_reset_same_net $second/Q $base/$status/D $report
    pblaze_reset_same_net $first/C $second/C $report
    pblaze_reset_same_net $second/C $base/$status/C $report
  }
  set nets [get_nets -segments -of_objects [pblaze_reset_exact_pin $base/user_lnk_up_int_reg/D]]
  set starts [get_pins -leaf -of_objects $nets -filter {DIRECTION == OUT}]
  set expected_source $base/pcie_top_i/pcie_7x_i/pcie_block_i/TRNLNKUP
  puts $report "RESET_LINK_STATUS_SOURCE=$starts"
  if {$starts ne $expected_source} {error "user link status no longer comes from PCIe hard block"}
  pblaze_reset_exact_cell $base/pcie_top_i/pcie_7x_i/pcie_block_i PCIE_2_1 $report
  puts $report "TRANSPORT_RESET_BOUNDARY_PASS phase=$phase"
  flush $report
}
proc pblaze_assert_reset_vendor_release {directory report} {
  foreach {file needles} {
    pblaze3_xdma_0_pcie2_ip_pipe_wrapper.v {
      {always @ (posedge clk_pclk or negedge PIPE_RESET_N)}
      {reset_n_reg1 <= 1'd0;} {reset_n_reg2 <= 1'd0;}
      {reset_n_reg1 <= 1'd1;} {reset_n_reg2 <= reset_n_reg1;}
    }
    pblaze3_xdma_0_pcie2_ip_core_top.v {
      {assign sys_or_hot_rst = !sys_rst_n || pl_received_hot_rst_q;}
      {always @(posedge user_clk_out or posedge sys_or_hot_rst)}
      {user_reset_int <= #TCQ 1'b1;}
      {end else if (user_rst_n && pl_phy_lnk_up_q) begin}
      {user_reset_int <= #TCQ 1'b0;}
      {user_reset_out <= #TCQ 1'b1;}
      {user_reset_out <= #TCQ user_reset_int;}
    }
  } {
    set path [file join $directory $file]
    if {![file isfile $path]} {error "missing reviewed reset vendor source: $path"}
    set channel [open $path r]; set text [read $channel]; close $channel
    foreach needle $needles {
      if {[string first $needle $text] < 0} {error "vendor reset release structure changed: $file $needle"}
      puts $report "VENDOR_RESET_RELEASE $file $needle"
    }
  }
  puts $report VENDOR_RESET_RELEASE_PASS
  flush $report
}

if {[catch {
set output /work/builds/pblaze3-review-reset-replicas-a9-a4
if {[file exists $output]} {error {fresh replica proof required}}
file mkdir $output
set_param general.maxThreads 1
set work /work/builds/pblaze3-work-20261026-v20261-build-a9
set checkpoint $work/project/pblaze3.runs/impl_1/pblaze3_wrapper_routed.dcp
set before [exec sha256sum $checkpoint]
set report [open $output/guard.txt w]
puts $report "UNCHANGED_ROUTED_DCP_BEFORE=$before"
open_project -read_only $work/project/pblaze3.xpr
open_run impl_1
pblaze_assert_transport_reset_boundary routed $report
set replicas [pblaze_reset_output_replicas $report]
if {[llength $replicas] != 8} {error "a9 actual replica count differs"}
set first [get_cells -of_objects [get_pins [lindex $replicas 0]]]
set ::review_replica $first
puts REVIEW_REPLICA_ROUTED_PASS
rename get_property review_original_get_property
proc get_property {args} {
  if {[lindex $args 0] eq "ORIG_CELL_NAME" && [lindex $args 1] eq $::review_replica} {return unrelated_register}
  return [uplevel 1 [list review_original_get_property {*}$args]]
}
set rejected [catch {pblaze_assert_transport_reset_boundary routed $report} reason]
rename get_property {}
rename review_original_get_property get_property
if {!$rejected || ![string match {reset replica provenance differs:*} $reason]} {error "replica provenance negative failed: $reason"}
puts "REVIEW_REPLICA_NEGATIVE_PROVENANCE=$reason"
rename get_nets review_original_get_nets
proc get_nets {args} {
  if {[lindex $args end] eq "$::review_replica/D"} {
    return [review_original_get_nets -quiet -segments -of_objects [pblaze_reset_exact_pin $::review_replica/PRE]]
  }
  return [uplevel 1 [list review_original_get_nets {*}$args]]
}
set rejected [catch {pblaze_assert_transport_reset_boundary routed $report} reason]
rename get_nets {}
rename review_original_get_nets get_nets
if {!$rejected || ![string match {reset stage connection differs:*} $reason]} {error "replica data-input negative failed: $reason"}
puts "REVIEW_REPLICA_NEGATIVE_DATA=$reason"
set ::review_extra_fanout 1
set ::review_bad_fanout [concat [all_fanout -flat -endpoints_only -from [pblaze_reset_exact_pin {pblaze3_i/transport_reset_gate/Res[0]_INST_0/O}]] [list [pblaze_reset_base]/user_reset_out_reg/D]]
rename all_fanout review_original_all_fanout
proc all_fanout {args} {
  if {$::review_extra_fanout} {
    set ::review_extra_fanout 0
    return $::review_bad_fanout
  }
  return [uplevel 1 [list review_original_all_fanout {*}$args]]
}
set rejected [catch {pblaze_assert_transport_reset_boundary routed $report} reason]
rename all_fanout {}
rename review_original_all_fanout all_fanout
if {!$rejected || $reason ne "transport reset has unexpected complete fanout"} {error "unrelated endpoint negative failed: $reason"}
puts "REVIEW_REPLICA_NEGATIVE_ENDPOINT=$reason"
pblaze_assert_transport_reset_boundary routed $report
set setup [get_timing_paths -delay_type max -slack_lesser_than 0 -max_paths 1]
set hold [get_timing_paths -delay_type min -slack_lesser_than 0 -max_paths 1]
puts $report "NEGATIVE_SETUP=[llength $setup] NEGATIVE_HOLD=[llength $hold]"
if {[llength $setup] || [llength $hold]} {error "timing failed on unchanged routed design"}
write_xdc $output/applied-constraints.xdc
report_exceptions -file $output/exceptions.rpt
close_project
set after [exec sha256sum $checkpoint]
puts $report "UNCHANGED_ROUTED_DCP_AFTER=$after"
if {$before ne $after} {error "original routed checkpoint changed"}
close $report
puts REVIEW_REPLICA_GUARD_PROBE_PASS
exit 0
} failure]} {puts "REVIEW_REPLICA_GUARD_PROBE_ERROR=$failure"; exit 1}

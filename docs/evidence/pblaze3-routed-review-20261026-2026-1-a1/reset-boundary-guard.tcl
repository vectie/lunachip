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
  set count [expr {$phase eq "synthesis" ? 10 : 7}]
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

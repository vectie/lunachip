# Vivado 2025.2 post-generate_target assertion. Read-only; no warning suppression.
proc pblaze_require_integer_property {object property expected report} {
  if {[llength $object] != 1} {error "missing or ambiguous object for $property"}
  set actual [get_property $property $object]
  puts $report "$object $property=$actual expected=$expected"
  if {![string is integer -strict $actual] || $actual != $expected} {
    error "AXI identity mismatch: $object $property=$actual expected=$expected"
  }
}

proc pblaze_require_interface_pair {origin destination report} {
  set pin [get_bd_intf_pins -quiet $origin]
  if {[llength $pin] != 1} {error "missing or ambiguous interface $origin"}
  set nets [get_bd_intf_nets -quiet -of_objects $pin]
  if {[llength $nets] != 1} {error "missing or ambiguous interface net $origin"}
  set actual [lsort [get_bd_intf_pins -quiet -of_objects $nets]]
  set expected [lsort [list $origin $destination]]
  puts $report "$nets interfaces=$actual expected=$expected"
  if {$actual ne $expected} {error "AXI interface routing mismatch for $origin"}
}

proc pblaze_require_rtl_once {rtl needle report} {
  set first [string first $needle $rtl]
  if {$first < 0 || [string first $needle $rtl [expr {$first + [string length $needle]}]] >= 0} {
    error "missing or ambiguous generated AXI wiring: $needle"
  }
  puts $report "RTL $needle"
}

proc pblaze_assert_m00_id_passthrough {rtl report} {
  set headers [regexp -all -inline -line {^module m00_couplers_imp_[^\n]+} $rtl]
  if {[llength $headers] != 1} {error "missing or ambiguous generated M00 coupler module"}
  set begin [string first [lindex $headers 0] $rtl]
  set end [string first endmodule $rtl $begin]
  if {$end < $begin} {error "unterminated generated M00 coupler module"}
  set coupler [string range $rtl $begin $end]
  foreach needle {
    {output [4:0]M_AXI_arid;} {output [4:0]M_AXI_awid;}
    {input [4:0]M_AXI_bid;} {input [4:0]M_AXI_rid;}
    {input [4:0]S_AXI_arid;} {input [4:0]S_AXI_awid;}
    {output [4:0]S_AXI_bid;} {output [4:0]S_AXI_rid;}
    {assign M_AXI_arid = S_AXI_arid[4:0];}
    {assign M_AXI_awid = S_AXI_awid[4:0];}
    {assign S_AXI_bid = M_AXI_bid[4:0];}
    {assign S_AXI_rid = M_AXI_rid[4:0];}
  } {pblaze_require_rtl_once $coupler $needle $report}
}

proc pblaze_assert_memory_ids {generated_top report} {
  set xbar [get_ips -all -quiet pblaze3_memory_imp_xbar_0]
  foreach {property expected} {
    CONFIG.NUM_SI 2 CONFIG.NUM_MI 1 CONFIG.ID_WIDTH 5
    CONFIG.S00_THREAD_ID_WIDTH 4 CONFIG.S01_THREAD_ID_WIDTH 0
    CONFIG.S00_BASE_ID 0 CONFIG.S01_BASE_ID 16
  } {pblaze_require_integer_property $xbar $property $expected $report}
  foreach {interface expected} {
    xdma/M_AXI 4 mig/S_AXI 5 accelerator/M_AXI_DDR 0
    memory/xbar/M00_AXI 5 memory/xbar/S00_AXI 5 memory/xbar/S01_AXI 5
  } {
    pblaze_require_integer_property [get_bd_intf_pins -quiet $interface] CONFIG.ID_WIDTH $expected $report
  }
  foreach path {
    memory/xbar/m_axi_awid memory/xbar/m_axi_arid memory/xbar/m_axi_bid memory/xbar/m_axi_rid
    mig/s_axi_awid mig/s_axi_arid mig/s_axi_bid mig/s_axi_rid
  } {
    set pin [get_bd_pins -quiet $path]
    pblaze_require_integer_property $pin LEFT 4 $report
    pblaze_require_integer_property $pin RIGHT 0 $report
  }
  foreach {origin destination} {
    /memory/xbar/M00_AXI /memory/m00_couplers/S_AXI
    /memory/m00_couplers/M_AXI /memory/M00_AXI
    /memory/M00_AXI /mig/S_AXI
  } {pblaze_require_interface_pair $origin $destination $report}
  set fd [open $generated_top r]
  set rtl [read $fd]
  close $fd
  pblaze_assert_m00_id_passthrough $rtl $report
  foreach needle {
    {wire [4:0]memory_M00_AXI_ARID;} {wire [4:0]memory_M00_AXI_AWID;}
    {wire [4:0]memory_M00_AXI_BID;} {wire [4:0]memory_M00_AXI_RID;}
    {wire [4:0]xbar_to_m00_couplers_ARID;} {wire [4:0]xbar_to_m00_couplers_AWID;}
    {wire [4:0]xbar_to_m00_couplers_BID;} {wire [4:0]xbar_to_m00_couplers_RID;}
    {.s_axi_arid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,s00_couplers_to_xbar_ARID}),}
    {.s_axi_awid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,s00_couplers_to_xbar_AWID}),}
    {.m_axi_bid(M_AXI_bid[3:0]),} {.m_axi_rid(M_AXI_rid[3:0]),}
  } {pblaze_require_rtl_once $rtl $needle $report}
  puts $report "AXI_ID_ROUTING=PASS"
}

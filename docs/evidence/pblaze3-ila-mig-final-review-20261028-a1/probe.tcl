if {[catch {
set_param general.maxThreads 1
set dcp {/work/builds/pblaze3-ila-reroute-20261028-mig-a1/optimized.dcp}
puts "DCP_BEFORE=[exec sha256sum $dcp]"
open_checkpoint $dcp
proc pblaze_assert_reset_clock {report} {
  set pin [get_pins -quiet {pblaze3_i/transport_supervisor/clock50}]
  if {[llength $pin] != 1} {error "missing/ambiguous independent reset clock pin"}
  set clocks [get_clocks -quiet -of_objects $pin]
  if {[llength $clocks] != 1 || abs([get_property PERIOD $clocks] - 20.000) > 0.001} {error "reset supervisor requires exactly50MHz"}
  if {![get_property IS_GENERATED $clocks] || [get_property MASTER_CLOCK $clocks] ne "clk_in1_50M"} {error "reset supervisor clock must derive directly from board oscillator"}
  set master [get_clocks -quiet clk_in1_50M]
  if {[llength $master] != 1 || [get_property IS_GENERATED $master] || abs([get_property PERIOD $master] - 20.000) > 0.001} {error "reset supervisor master clock differs"}
  puts $report "RESET_CLOCK_PASS [get_property NAME $clocks] PERIOD=[get_property PERIOD $clocks] MASTER=[get_property MASTER_CLOCK $clocks]"
  flush $report
}
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
      set exact_key 0
      foreach {match token} [regexp -all -inline {cache-ID = ([[:xdigit:]]+)} $text] {
        if {$token eq $key} {set exact_key 1}
      }
      if {!$exact_key} {error "cache key has no original successful producer: $path"}
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
proc pblaze_mig_read {path} {
  set channel [open $path rb]
  set bytes [read $channel]
  close $channel
  return $bytes
}
proc pblaze_assert_mig_xml {source effective mode report} {
  set before [pblaze_mig_read $source]
  set after [pblaze_mig_read $effective]
  set old {<C0_S_AXI_SUPPORTS_NARROW_BURST>0</C0_S_AXI_SUPPORTS_NARROW_BURST>}
  set new {<C0_S_AXI_SUPPORTS_NARROW_BURST>1</C0_S_AXI_SUPPORTS_NARROW_BURST>}
  if {[regexp -all -- $old $before] != 1} {error "source MIG narrow-burst setting differs"}
  if {$mode eq "accelerator"} {
    if {$after ne [string map [list $old $new] $before]} {error "unexpected accelerator MIG XML mutation"}
    puts $report "ALLOWED_TRANSFORMATION exactly one C0_S_AXI_SUPPORTS_NARROW_BURST 0->1; all other bytes identical"
  } elseif {$mode in {ddr-smoke vendor-baseline}} {
    if {$after ne $before} {error "smoke/baseline MIG XML must remain byte-identical"}
    puts $report "ALLOWED_TRANSFORMATION none; source and effective bytes identical"
  } else {error "unknown MIG build mode"}
  set row [expr {$mode eq "vendor-baseline" ? 16 : 15}]
  set address [expr {$mode eq "vendor-baseline" ? 32 : 31}]
  set memory [expr {$mode eq "vendor-baseline" ? 4294967296 : 2147483648}]
  set part [expr {$mode eq "vendor-baseline" ? "MT41K512M8XX-125" : "MT41K256M8XX-125"}]
  set id [expr {$mode eq "accelerator" ? 5 : 4}]
  foreach {name expected} [list MemoryDevice "DDR3_SDRAM/Components/$part" DataWidth 64 ECC Disabled RowAddress $row ColAddress 10 BankAddress 3 C0_MEM_SIZE $memory C0_S_AXI_ADDR_WIDTH $address C0_S_AXI_DATA_WIDTH 128 C0_S_AXI_ID_WIDTH $id] {
    set tag "<$name>$expected</$name>"
    if {[regexp -all -- $tag $after] != 1} {error "effective MIG geometry differs: $name"}
    puts $report "XML $name=$expected"
  }
}
proc pblaze_record_mig_input {bundle output mode} {
  set source [file join $output mig-source.prj]
  set effective [file join $output mig-effective.prj]
  set report [open [file join $output mig-input-properties.txt] w]
  if {[pblaze_mig_read [file join $bundle mig.prj]] ne [pblaze_mig_read $source]} {error "exported MIG source changed during tool execution"}
  if {[auto_execok sha256sum] ne ""} {
    set hashing [list sha256sum]
  } elseif {[auto_execok shasum] ne ""} {
    set hashing [list shasum -a 256]
  } else {error "SHA256 utility required for effective MIG evidence"}
  set hashes [open [file join $output mig-inputs.sha256] w]
  puts $hashes [exec {*}$hashing [file join $bundle mig.prj] $source $effective]
  close $hashes
  pblaze_assert_mig_xml $source $effective $mode $report
  set address [expr {$mode eq "vendor-baseline" ? 32 : 31}]
  set id [expr {$mode eq "accelerator" ? 5 : 4}]
  set narrow [expr {$mode eq "accelerator" ? 1 : 0}]
  foreach {name expected} [list ADDR_WIDTH $address DATA_WIDTH 128 ID_WIDTH $id SUPPORTS_NARROW_BURST $narrow] {
    set actual [get_property CONFIG.$name [get_bd_intf_pins mig/S_AXI]]
    if {$actual ne $expected} {error "effective MIG interface differs: $name=$actual, expected $expected"}
    puts $report "BD mig/S_AXI $name=$actual"
  }
  if {[get_property CONFIG.SUPPORTS_NARROW_BURST [get_bd_intf_pins xdma/M_AXI]] ne "0"} {error "XDMA narrow-burst contract changed"}
  if {$mode eq "accelerator" && [get_property CONFIG.SUPPORTS_NARROW_BURST [get_bd_intf_pins accelerator/M_AXI_DDR]] ne "1"} {error "accelerator narrow-burst metadata changed"}
  close $report
}
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
proc pblaze_diag_pin {name} {
  set pin [get_pins -quiet -hier -filter [format {NAME == "%s"} $name]]
  if {[llength $pin] != 1} {error "missing/ambiguous diagnostic physical pin $name"}
  return $pin
}
proc pblaze_diag_cell {name} {
  set cell [get_cells -quiet -hier -filter [format {NAME == "%s"} $name]]
  if {[llength $cell] != 1} {error "missing/ambiguous diagnostic physical cell $name"}
  return $cell
}
proc pblaze_diag_property {object property expected} {
  if {[llength $object] != 1 || $property ni [list_property $object]} {error "diagnostic property absent: $object $property"}
  set actual [get_property $property $object]
  if {$actual ne $expected} {error "diagnostic property mismatch: $object $property=$actual expected=$expected"}
}
proc pblaze_diag_same_net {left right label report} {
  if {[llength $left] != 1 || [llength $right] != 1} {error "ambiguous diagnostic net endpoints: $label"}
  set a [lsort [get_nets -segments -of_objects $left]]
  set b [lsort [get_nets -segments -of_objects $right]]
  if {[llength $a] == 0 || $a ne $b} {error "diagnostic net identity mismatch: $label ($left -> $right)"}
  puts $report "NET_IDENTITY $label left=$left right=$right segments=[llength $a]"
}
proc pblaze_diag_clock {pin period report} {
  set clock [get_clocks -of_objects $pin]
  if {[llength $clock] != 1 || abs([get_property PERIOD $clock]-$period)>0.001} {error "diagnostic clock identity/period mismatch: $pin expected=$period"}
  puts $report "CLOCK_IDENTITY $pin name=[get_property NAME $clock] period=[get_property PERIOD $clock]"
  return $clock
}
proc pblaze_assert_diagnostic_raw_clock {report} {
  set raw pblaze3_i/diagnostic_clock/inst
  pblaze_diag_property [pblaze_diag_cell $raw/oscillator_input] REF_NAME IBUF
  pblaze_diag_property [pblaze_diag_cell $raw/oscillator_global] REF_NAME BUFG
  set port [get_ports -quiet clk_in1_50M]
  if {[llength $port] != 1} {error "diagnostic primary clock port missing"}
  pblaze_diag_same_net $port [pblaze_diag_pin $raw/oscillator_input/I] oscillator_to_ibuf $report
  pblaze_diag_same_net [pblaze_diag_pin $raw/oscillator_input/O] [pblaze_diag_pin $raw/oscillator_global/I] ibuf_to_bufg $report
  set clock [pblaze_diag_clock [pblaze_diag_pin $raw/oscillator_global/O] 20 $report]
  pblaze_diag_property $clock NAME clk_in1_50M
  pblaze_diag_property $clock IS_GENERATED 0
  pblaze_diag_property $clock SOURCE_PINS clk_in1_50M
  pblaze_diag_same_net [pblaze_diag_pin $raw/oscillator_global/O] [pblaze_diag_pin dbg_hub/clk] raw50_to_hub $report
  set hub [get_debug_cores -quiet dbg_hub]
  pblaze_diag_property $hub C_CLK_INPUT_FREQ_HZ 50000000
  pblaze_diag_property $hub C_ENABLE_CLK_DIVIDER false
  puts $report "RAW_OSCILLATOR_CLOCK=PASS"
}
proc pblaze_assert_diagnostic_status_sync {report} {
  set root pblaze3_i/diagnostic_status/inst/flags_cdc
  set actual [get_cells -quiet -hier -filter [format {NAME =~ "%s/syncstages_ff_reg*"} $root]]
  set expected {}
  for {set stage 0} {$stage < 3} {incr stage} {
    for {set bit 0} {$bit < 9} {incr bit} {
      set name [format {%s/syncstages_ff_reg[%d][%d]} $root $stage $bit]
      lappend expected $name
      set cell [pblaze_diag_cell $name]
      pblaze_diag_property $cell REF_NAME FDRE
      pblaze_diag_property $cell ASYNC_REG 1
      pblaze_diag_same_net [pblaze_diag_pin $name/C] [pblaze_diag_pin pblaze3_i/diagnostic_clock/inst/oscillator_global/O] status_clock_$stage.$bit $report
      if {$stage > 0} {
        set prior [format {%s/syncstages_ff_reg[%d][%d]/Q} $root [expr {$stage-1}] $bit]
        pblaze_diag_same_net [pblaze_diag_pin $prior] [pblaze_diag_pin $name/D] status_chain_$stage.$bit $report
      }
      if {$stage == 2} {
        set probe [format {pblaze3_i/ila_reset50/inst/probe0[%d]} $bit]
        pblaze_diag_same_net [pblaze_diag_pin $name/Q] [pblaze_diag_pin $probe] status_probe_$bit $report
      }
    }
  }
  if {[lsort $actual] ne [lsort $expected]} {error "diagnostic status synchronizer cell set differs"}
  puts $report "STATUS_SYNC_3X9=PASS"
}
proc pblaze_assert_diagnostic_cores {rows report} {
  set expected {dbg_hub}
  foreach row $rows {lappend expected pblaze3_i/[lindex $row 0]}
  if {[lsort [get_debug_cores]] ne [lsort $expected]} {error "diagnostic exact debug core set differs"}
  foreach row $rows {
    if {[llength $row] != 4} {error "malformed diagnostic core row"}
    lassign $row name source period widths
    set full pblaze3_i/$name
    set core [get_debug_cores $full]
    pblaze_diag_property [pblaze_diag_cell $full] REF_NAME pblaze3_${name}_0
    pblaze_diag_property $core C_DATA_DEPTH 1024
    pblaze_diag_property $core C_INPUT_PIPE_STAGES 1
    pblaze_diag_property $core C_ADV_TRIGGER false
    pblaze_diag_property $core C_EN_STRG_QUAL true
    pblaze_diag_property $core C_TRIGIN_EN false
    pblaze_diag_property $core C_TRIGOUT_EN false
    set uuid [get_property UUID $core]
    if {![regexp {^[[:xdigit:]]{32}$} $uuid] || $uuid eq "00000000000000000000000000000000"} {error "diagnostic ILA UUID missing/invalid"}
    puts $report [join [list CORE $full $uuid 1024 1] [format %c 9]]
    set expected_ports [list $full/clk]
    set index 0
    foreach width $widths {
      set probe [get_debug_ports $full/probe$index]
      pblaze_diag_property $probe PORT_WIDTH $width
      pblaze_diag_property $probe PROBE_TYPE DATA_AND_TRIGGER
      lappend expected_ports $full/probe$index
      puts $report [join [list PROBE $full $index $width] [format %c 9]]
      incr index
    }
    if {$index < 1 || $index > 5 || [lsort [get_debug_ports -of_objects $core]] ne [lsort $expected_ports]} {error "diagnostic exact debug port set differs: $full"}
    set pin [pblaze_diag_pin $full/inst/clk]
    pblaze_diag_same_net [pblaze_diag_pin $source] $pin $name.domain_clock $report
    pblaze_diag_clock $pin $period $report
  }
  puts $report "DIAGNOSTIC_CORES=PASS"
}
proc pblaze_assert_diagnostic_physical {rows report} {
  pblaze_assert_diagnostic_raw_clock $report
  # This single-domain AXI image has no status synchronizer or status ILA.
  pblaze_assert_diagnostic_cores $rows $report
  puts $report "DIAGNOSTIC_PHYSICAL=PASS"
}
set diagnostic_rows {
  {ila_mig200 pblaze3_i/mig/ui_clk 5 {53 147 8 50 137}}
}

set flag_rows {
{ila_mig200 calibrated mig/init_calib_complete 50}
{ila_mig200 ui_reset mig/ui_clk_sync_rst 51}
{ila_mig200 axi_reset_n reset_ui/peripheral_aresetn 52}
}
proc pblaze_review_flag_pin {name} {
  set pin [get_pins -quiet -hier -filter [format {NAME == "%s"} $name]]
  if {[llength $pin] == 0} {
    set vector [format {%s[0]} $name]
    set pin [get_pins -quiet -hier -filter [format {NAME == "%s"} $vector]]
  }
  if {[llength $pin] != 1} {error "missing/ambiguous flag pin $name"}
  return $pin
}
proc pblaze_review_flag_cell {cell} {
  puts "FLAG_CELL $cell REF_NAME=[get_property REF_NAME $cell]"
  foreach prop {INIT ASYNC_REG IS_C_INVERTED IS_PRE_INVERTED IS_CLR_INVERTED} {
    if {$prop in [list_property $cell]} {puts "FLAG_PROPERTY $cell $prop=[get_property $prop $cell]"}
  }
  foreach port {C CLK PRE CLR R S} {
    set pin [get_pins -quiet -of_objects $cell -filter "REF_PIN_NAME == $port"]
    if {[llength $pin] == 1} {
      puts "FLAG_CONTROL $pin clocks=[get_clocks -quiet -of_objects $pin]"
      if {$port ni {C CLK}} {
        set drivers [get_pins -quiet -leaf -of_objects [get_nets -segments -of_objects $pin] -filter {DIRECTION == OUT}]
        puts "FLAG_CONTROL_DRIVERS $pin $drivers"
      }
    }
  }
}
foreach row $flag_rows {
  lassign $row core label source bit
  set source_pin [pblaze_review_flag_pin pblaze3_i/$source]
  set capture [pblaze_diag_pin pblaze3_i/${core}_monitor/$label]
  set probe [pblaze_diag_pin [format {pblaze3_i/%s/inst/probe0[%d]} $core $bit]]
  pblaze_diag_same_net $source_pin $capture $core.$label.source_to_monitor stdout
  pblaze_diag_same_net $capture $probe $core.$label.monitor_to_probe_bit$bit stdout
  puts "FLAG_MAPPING $core $label bit=$bit source=$source_pin capture=$capture probe=$probe"
  set drivers [get_pins -quiet -leaf -of_objects [get_nets -segments -of_objects $source_pin] -filter {DIRECTION == OUT}]
  if {[llength $drivers] != 1} {error "flag requires one physical driver: $source_pin ($drivers)"}
  puts "FLAG_DRIVER $label $drivers"
  foreach cell [get_cells -of_objects $drivers] {pblaze_review_flag_cell $cell}
  set starts [all_fanin -flat -startpoints_only -to $source_pin]
  puts "FLAG_STARTPOINTS $label $starts"
  foreach cell [get_cells -quiet -of_objects $starts] {pblaze_review_flag_cell $cell}
}
puts LOCAL_FLAG_MAPPING_REVIEW=PASS
pblaze_assert_reset_clock stdout
pblaze_assert_transport_reset_boundary routed stdout
pblaze_assert_diagnostic_physical $diagnostic_rows stdout
file mkdir {/work/builds/pblaze3-ila-routed-flags-mig-reroute-a1}
report_cdc -details -file {/work/builds/pblaze3-ila-routed-flags-mig-reroute-a1/cdc.rpt}
set fd [open {/work/builds/pblaze3-ila-routed-flags-mig-reroute-a1/cdc.rpt} r]
puts CDC_REPORT_BEGIN
puts [read $fd]
close $fd
puts CDC_REPORT_END
write_debug_probes -force {/work/builds/pblaze3-ila-routed-flags-mig-reroute-a1/routed.ltx}
set fd [open {/work/builds/pblaze3-ila-routed-flags-mig-reroute-a1/routed.ltx} r]
puts LTX_BEGIN
puts [read $fd]
close $fd
puts LTX_END
puts "DCP_AFTER=[exec sha256sum $dcp]"
puts ROUTED_FLAGS_CDC_REVIEW_COMPLETE
} reason options]} {puts stderr "ROUTED_FLAGS_REVIEW_FAILED=$reason";puts stderr [dict get $options -errorinfo];exit 1}
exit 0

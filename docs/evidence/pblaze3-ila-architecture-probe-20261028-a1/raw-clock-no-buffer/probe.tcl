if {[catch {
  set work /work/builds/pblaze3-ila-clock-probe-20261028-a1
  if {[file exists $work]} {error "fresh guest evidence required"}
  file mkdir $work;cd $work
  set_param general.maxThreads 1
  puts "CLOCK_TOOL=[version]"
  create_project clock_probe [file join $work project] -part xc7k325tffg900-2
  create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clocks
  set_property -dict {CONFIG.PRIM_IN_FREQ 50.000 CONFIG.PRIM_SOURCE No_buffer CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 200.000 CONFIG.CLK_OUT1_PORT clk_200M CONFIG.CLKOUT2_USED true CONFIG.CLKOUT2_REQUESTED_OUT_FREQ 33.333333 CONFIG.CLK_OUT2_PORT core_clk CONFIG.CLKOUT3_USED true CONFIG.CLKOUT3_REQUESTED_OUT_FREQ 50.000 CONFIG.CLK_OUT3_PORT reset_clk50 CONFIG.USE_RESET false CONFIG.USE_LOCKED true} [get_ips clocks]
  puts "CLOCK_PRIM_SOURCE=[get_property CONFIG.PRIM_SOURCE [get_ips clocks]]"
  generate_target all [get_ips clocks]
  proc inspect {directory} {
    foreach file [lsort [glob -nocomplain -directory $directory *]] {
      if {[file isdirectory $file]} {inspect $file;continue}
      if {[file extension $file] ni {.v .xdc}} {continue}
      puts "CLOCK_SOURCE $file"
      set f [open $file r];set data [read $f];close $f
      set n 0
      foreach line [split $data \n] {incr n;if {[regexp {IBUF|BUFG|create_clock|set_input_jitter|clk_in1|clk_in1_clocks|MMCME2} $line]} {puts "$n: $line"}}
    }
  }
  inspect [file join $work project clock_probe.gen sources_1 ip clocks]
  close_project
  puts "CLOCK_NO_BUFFER_PROBE=PASS"
} reason options]} {puts stderr "CLOCK_PROBE_FAILED=$reason";puts stderr [dict get $options -errorinfo];exit 1}
exit 0

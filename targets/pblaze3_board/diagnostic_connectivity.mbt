///|
/// Checked against actual generated AXI4 and AXI-Lite nets, including the
/// original disconnected scalar-tap design as a negative control.
fn diagnostic_connectivity_guard() -> String {
  (
    #|proc pblaze_capture_top {rtl} {
    #|  set matches [regexp -all -inline -indices -line {^module pblaze3$} $rtl]
    #|  if {[llength $matches] != 1} {error "missing/ambiguous generated pblaze3 module"}
    #|  set start [lindex [lindex $matches 0] 0]
    #|  set end [string first endmodule $rtl $start]
    #|  if {$end < $start} {error "unterminated pblaze3 module"}
    #|  return [string range $rtl $start $end]
    #|}
    #|proc pblaze_capture_instance {top instance} {
    #|  set pattern [format {^[[:blank:]]+[[:alnum:]_]+[[:blank:]]+%s[[:blank:]]*$} $instance]
    #|  set matches [regexp -all -inline -indices -line $pattern $top]
    #|  if {[llength $matches] != 1} {error "missing/ambiguous generated instance $instance"}
    #|  set start [lindex [lindex $matches 0] 0]
    #|  set end [string first {);} $top $start]
    #|  if {$end < $start} {error "unterminated instance $instance"}
    #|  return [string range $top $start $end]
    #|}
    #|proc pblaze_capture_connection {top instance port} {
    #|  set body [pblaze_capture_instance $top $instance]
    #|  set pattern [format {[.]%s[(]([^()]*)[)]} $port]
    #|  set matches [regexp -all -inline $pattern $body]
    #|  if {[llength $matches] != 2} {error "missing/ambiguous generated port $instance/$port"}
    #|  set expression [string trim [lindex $matches 1]]
    #|  if {![regexp {^([[:alpha:]_][[:alnum:]_]*)([[]([0-9]+):([0-9]+)[]])?$} $expression all net slice hi lo]} {
    #|    error "capture port is not a direct net or constant-free LSB slice: $instance/$port=$expression"
    #|  }
    #|  set declaration [format {^[[:blank:]]*wire[[:blank:]]+([[]([0-9]+):([0-9]+)[]])?[[:blank:]]*%s;} $net]
    #|  set declarations [regexp -all -inline -line $declaration $top]
    #|  if {[llength $declarations] != 4} {error "missing/ambiguous wire declaration $net"}
    #|  set left [lindex $declarations 2];set right [lindex $declarations 3]
    #|  if {$left eq ""} {set left 0;set right 0}
    #|  if {$right != 0 || $left < $right} {error "unexpected wire direction $net"}
    #|  if {$slice eq ""} {set hi $left;set lo $right}
    #|  if {$lo != 0 || $hi < $lo || $hi > $left} {error "unexpected capture slice $expression"}
    #|  return [list $net $hi $lo]
    #|}
    #|proc pblaze_assert_capture_rtl {rtl rows report} {
    #|  set top [pblaze_capture_top $rtl]
    #|  foreach row $rows {
    #|    if {[llength $row] != 9} {error "malformed capture connectivity row"}
    #|    lassign $row label source sport peer pport monitor mport width peer_width
    #|    set source_net [pblaze_capture_connection $top $source $sport]
    #|    set peer_net [pblaze_capture_connection $top $peer $pport]
    #|    set monitor_net [pblaze_capture_connection $top $monitor $mport]
    #|    if {$source_net ne $monitor_net || [lindex $source_net 0] ne [lindex $peer_net 0] || [lindex $source_net 1] != $width-1 || [lindex $peer_net 1] != $peer_width-1} {
    #|      error "capture connectivity mismatch $label source=$source_net peer=$peer_net monitor=$monitor_net expected_width=$width peer_width=$peer_width"
    #|    }
    #|    puts $report "CAPTURE_CONNECTION $label source=$source/$sport peer=$peer/$pport monitor=$monitor/$mport net=$source_net peer_net=$peer_net"
    #|  }
    #|  puts $report "CAPTURE_CONNECTIVITY=PASS count=[llength $rows]"
    #|}
    #|proc pblaze_assert_capture_connections {generated_top rows report} {
    #|  set fd [open $generated_top r];set rtl [read $fd];close $fd
    #|  pblaze_assert_capture_rtl $rtl $rows $report
    #|}
    #|
  )
}

///|
fn diagnostic_connectivity_tcl(mode : BuildMode) -> String {
  if mode == DdrStatusIla {
    return ""
  }
  let out = StringBuilder()
  out.write_string(diagnostic_connectivity_guard())
  out.write_string("set capture_rows {\n")
  for domain in capture_domains(mode) {
    if domain.name == "ila_reset50" {
      continue
    }
    for fields in domain.probes {
      for (field, source, width) in fields {
        if status_field(field) {
          continue
        }
        let control = field.has_prefix("ctrl_")
        let signal = if control { field[5:].to_owned() } else { field }
        let address = signal == "awaddr" || signal == "araddr"
        let (peer, prefix) = if control {
          if domain.name == "ila_core33" {
            ("control", "M00_AXI_")
          } else if mode == AcceleratorIla {
            ("control", "S00_AXI_")
          } else {
            ("gpio", "s_axi_")
          }
        } else {
          (
            "memory",
            match domain.name {
              "ila_mig200" => "M00_AXI_"
              "ila_xdma250" => "S00_AXI_"
              _ => "S01_AXI_"
            },
          )
        }
        let peer_width = if address && domain.name == "ila_mig200" {
          64
        } else if address && peer == "gpio" {
          9
        } else {
          width
        }
        let source = source.replace(old="/", new=" ")
        out.write_string(
          "  {\{domain.name}.\{field} \{source} \{peer} \{prefix}\{signal} \{domain.name}_monitor \{field} \{width} \{peer_width}}\n",
        )
      }
    }
  }
  out.write_string(
    (
      #|}
      #|set capture_report [open [file join $output diagnostic-connectivity.txt] w]
      #|pblaze_assert_capture_connections [file join $output project pblaze3.gen sources_1 bd pblaze3 synth pblaze3.v] $capture_rows $capture_report
      #|close $capture_report
      #|
    ),
  )
  out.to_string()
}

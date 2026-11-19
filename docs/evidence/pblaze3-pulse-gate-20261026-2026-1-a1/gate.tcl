report_pulse_width -warn_on_violation -verbose -file pulse-width.rpt
set pulse_warnings [get_msg_config -count -severity {CRITICAL WARNING}]
puts "PULSE_WARNING_COUNT=$pulse_warnings"
if {![string is integer -strict $pulse_warnings] || $pulse_warnings != 0} {
  error "pulse-width gate or preceding critical warning failed"
}

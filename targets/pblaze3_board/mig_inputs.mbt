///|
/// Keep the immutable exported XML separate from the vendor's mutable input.
/// The one allowed capability update is qualified by the actual 2026.1 audit.
fn mig_inputs_tcl() -> String {
  (
    #|proc pblaze_mig_read {path} {
    #|  set channel [open $path rb]
    #|  set bytes [read $channel]
    #|  close $channel
    #|  return $bytes
    #|}
    #|proc pblaze_assert_mig_xml {source effective mode report} {
    #|  set before [pblaze_mig_read $source]
    #|  set after [pblaze_mig_read $effective]
    #|  set old {<C0_S_AXI_SUPPORTS_NARROW_BURST>0</C0_S_AXI_SUPPORTS_NARROW_BURST>}
    #|  set new {<C0_S_AXI_SUPPORTS_NARROW_BURST>1</C0_S_AXI_SUPPORTS_NARROW_BURST>}
    #|  if {[regexp -all -- $old $before] != 1} {error "source MIG narrow-burst setting differs"}
    #|  if {$mode eq "accelerator"} {
    #|    if {$after ne [string map [list $old $new] $before]} {error "unexpected accelerator MIG XML mutation"}
    #|    puts $report "ALLOWED_TRANSFORMATION exactly one C0_S_AXI_SUPPORTS_NARROW_BURST 0->1; all other bytes identical"
    #|  } elseif {$mode in {ddr-smoke vendor-baseline}} {
    #|    if {$after ne $before} {error "smoke/baseline MIG XML must remain byte-identical"}
    #|    puts $report "ALLOWED_TRANSFORMATION none; source and effective bytes identical"
    #|  } else {error "unknown MIG build mode"}
    #|  set row [expr {$mode eq "vendor-baseline" ? 16 : 15}]
    #|  set address [expr {$mode eq "vendor-baseline" ? 32 : 31}]
    #|  set memory [expr {$mode eq "vendor-baseline" ? 4294967296 : 2147483648}]
    #|  set part [expr {$mode eq "vendor-baseline" ? "MT41K512M8XX-125" : "MT41K256M8XX-125"}]
    #|  set id [expr {$mode eq "accelerator" ? 5 : 4}]
    #|  foreach {name expected} [list MemoryDevice "DDR3_SDRAM/Components/$part" DataWidth 64 ECC Disabled RowAddress $row ColAddress 10 BankAddress 3 C0_MEM_SIZE $memory C0_S_AXI_ADDR_WIDTH $address C0_S_AXI_DATA_WIDTH 128 C0_S_AXI_ID_WIDTH $id] {
    #|    set tag "<$name>$expected</$name>"
    #|    if {[regexp -all -- $tag $after] != 1} {error "effective MIG geometry differs: $name"}
    #|    puts $report "XML $name=$expected"
    #|  }
    #|}
    #|proc pblaze_record_mig_input {bundle output mode} {
    #|  set source [file join $output mig-source.prj]
    #|  set effective [file join $output mig-effective.prj]
    #|  set report [open [file join $output mig-input-properties.txt] w]
    #|  if {[pblaze_mig_read [file join $bundle mig.prj]] ne [pblaze_mig_read $source]} {error "exported MIG source changed during tool execution"}
    #|  if {[auto_execok sha256sum] ne ""} {
    #|    set hashing [list sha256sum]
    #|  } elseif {[auto_execok shasum] ne ""} {
    #|    set hashing [list shasum -a 256]
    #|  } else {error "SHA256 utility required for effective MIG evidence"}
    #|  set hashes [open [file join $output mig-inputs.sha256] w]
    #|  puts $hashes [exec {*}$hashing [file join $bundle mig.prj] $source $effective]
    #|  close $hashes
    #|  pblaze_assert_mig_xml $source $effective $mode $report
    #|  set address [expr {$mode eq "vendor-baseline" ? 32 : 31}]
    #|  set id [expr {$mode eq "accelerator" ? 5 : 4}]
    #|  set narrow [expr {$mode eq "accelerator" ? 1 : 0}]
    #|  foreach {name expected} [list ADDR_WIDTH $address DATA_WIDTH 128 ID_WIDTH $id SUPPORTS_NARROW_BURST $narrow] {
    #|    set actual [get_property CONFIG.$name [get_bd_intf_pins mig/S_AXI]]
    #|    if {$actual ne $expected} {error "effective MIG interface differs: $name=$actual, expected $expected"}
    #|    puts $report "BD mig/S_AXI $name=$actual"
    #|  }
    #|  if {[get_property CONFIG.SUPPORTS_NARROW_BURST [get_bd_intf_pins xdma/M_AXI]] ne "0"} {error "XDMA narrow-burst contract changed"}
    #|  if {$mode eq "accelerator" && [get_property CONFIG.SUPPORTS_NARROW_BURST [get_bd_intf_pins accelerator/M_AXI_DDR]] ne "1"} {error "accelerator narrow-burst metadata changed"}
    #|  close $report
    #|}
    #|
  )
}

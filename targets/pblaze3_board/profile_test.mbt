///|
fn vendor_fixture() -> String {
  (
    #|<Project>
    #|<MemoryDevice>DDR3_SDRAM/Components/MT41K512M8XX-125</MemoryDevice>
    #|<RowAddress>16</RowAddress>
    #|<ColAddress>10</ColAddress>
    #|<BankAddress>3</BankAddress>
    #|<DataWidth>64</DataWidth>
    #|<ECC>Disabled</ECC>
    #|<C0_MEM_SIZE>4294967296</C0_MEM_SIZE>
    #|<C0_S_AXI_ADDR_WIDTH>32</C0_S_AXI_ADDR_WIDTH>
    #|<C0_S_AXI_ID_WIDTH>4</C0_S_AXI_ID_WIDTH>
    #|<Pin PADName="AK9" name="ddr3_addr[14]"/>
    #|<Pin PADName="AE13" name="ddr3_addr[15]"/>
    #|<Pin PADName="AJ4" name="ddr3_dq[63]"/>
    #|<Pin PADName="AA10" name="ddr3_dq[64]"/>
    #|<Pin PADName="AA13" name="ddr3_dm[8]"/>
    #|<Pin PADName="AC9" name="ddr3_dqs_n[8]"/>
    #|<Pin PADName="AB9" name="ddr3_dqs_p[8]"/>
    #|<Parameters trfc="260"/>
    #|</Project>
    #|
  )
}

///|
test "Vivado reset core declares input net kinds without changing canonical logic" {
  let ordinary = @pblaze3_board.transport_reset_ordinary_source()
  let target = @pblaze3_board.transport_reset_core_source()
  for line in target.split("\n") {
    assert_false(line.has_prefix("  input logic "))
  }
  assert_eq(target.split("  input wire logic ").to_array().length(), 3)
  assert_eq(
    target
    .split("  input wire logic ")
    .map(part => part.to_owned())
    .to_array()
    .join("  input logic "),
    ordinary,
  )
  assert_true(target.contains("`default_nettype none"))
}

///|
test "known malformed vendor prefix normalizes without relying on decoder recovery" {
  let original = b"\xef\xbb\x3f<?xml version=\"1.0\"?><Project/>"
  assert_eq(
    @pblaze3_board.normalize_vendor_xml(original),
    "<?xml version=\"1.0\"?><Project/>",
  )
  for
    changed in [b"\xef\xbb\x3e<?xml version=\"1.0\"?>", b"\xef\xbb\x3fgarbage"] {
    try @pblaze3_board.normalize_vendor_xml(changed) catch {
      InvalidVendorInput(_) => ()
      _ => fail("unexpected error category")
    } noraise {
      _ => fail("unknown malformed prefix accepted")
    }
  }
}

///|
test "2GiB geometry excludes ninth byte and preserves active pins" {
  let result = @pblaze3_board.mig_project(vendor_fixture(), DdrSmoke)
  assert_true(result.contains("<RowAddress>15</RowAddress>"))
  assert_true(result.contains("<C0_MEM_SIZE>2147483648</C0_MEM_SIZE>"))
  assert_true(result.contains("<C0_S_AXI_ADDR_WIDTH>31</C0_S_AXI_ADDR_WIDTH>"))
  assert_true(result.contains("PADName=\"AK9\" name=\"ddr3_addr[14]\""))
  assert_true(result.contains("PADName=\"AJ4\" name=\"ddr3_dq[63]\""))
  for
    inactive in [
      "ddr3_addr[15]", "ddr3_dq[64]", "ddr3_dm[8]", "ddr3_dqs_n[8]", "ddr3_dqs_p[8]",
    ] {
    assert_false(result.contains(inactive))
  }
  // Eight x8 devices, 15 row +10 column +3 bank bits =2GiB.
  assert_eq(
    (1UL << (15 + 10 + 3)) * 8UL,
    @pblaze3_board.BuildMode::DdrSmoke.memory_bytes(),
  )
}

///|
test "baseline geometry bytes remain unchanged" {
  let vendor = vendor_fixture().replace(old="\n", new="\r\n")
  assert_eq(@pblaze3_board.mig_project(vendor, VendorBaseline), vendor)
  assert_eq(
    @pblaze3_board.BuildMode::VendorBaseline.memory_bytes(),
    4294967296UL,
  )
  assert_eq(@pblaze3_board.BuildMode::Accelerator.memory_bytes(), 2147483648UL)
}

///|
test "two-master accelerator preserves the prefixed AXI transaction ID" {
  for mode in [@pblaze3_board.BuildMode::VendorBaseline, DdrSmoke] {
    assert_true(
      @pblaze3_board.mig_project(vendor_fixture(), mode).contains(
        "<C0_S_AXI_ID_WIDTH>4</C0_S_AXI_ID_WIDTH>",
      ),
    )
  }
  assert_true(
    @pblaze3_board.mig_project(vendor_fixture(), Accelerator).contains(
      "<C0_S_AXI_ID_WIDTH>5</C0_S_AXI_ID_WIDTH>",
    ),
  )
}

///|
test "unknown vendor geometry rejected before transformed output" {
  for
    changed in [
      vendor_fixture().replace(
        old="<DataWidth>64</DataWidth>",
        new="<DataWidth>72</DataWidth>",
      ),
      vendor_fixture().replace(
        old="<ECC>Disabled</ECC>",
        new="<ECC>Enabled</ECC>",
      ),
      vendor_fixture().replace(old="MT41K512M8XX-125", new="UNKNOWN"),
    ] {
    try @pblaze3_board.mig_project(changed, Accelerator) catch {
      InvalidVendorInput(_) => ()
      _ => fail("unexpected error category")
    } noraise {
      _ => fail("unexpected vendor geometry accepted")
    }
  }
}

///|
test "mode parsing does not silently accept misspelling" {
  assert_eq(@pblaze3_board.parse_mode("accelerator"), Accelerator)
  try @pblaze3_board.parse_mode("accelerater") catch {
    InvalidProfile(_) => ()
    _ => fail("unexpected error category")
  } noraise {
    _ => fail("invalid mode accepted")
  }
}

///|
test "recipes isolate tool releases and gate both timing coverage and implementation" {
  let target = @pblaze3_board.build_tcl(Accelerator)
  assert_true(target.contains("set required_release {2025.2}"))
  assert_true(target.contains("set memory_range 2147483648"))
  assert_true(target.contains("-reference pblaze3_layer_system"))
  assert_true(target.contains("-range 1M"))
  assert_true(target.contains("no_clock unconstrained_internal_endpoints"))
  assert_true(target.contains("hold timing failed"))
  assert_false(target.contains("program_hw_devices"))
  assert_false(target.contains("write_cfgmem"))
  assert_true(
    @pblaze3_board.build_tcl(VendorBaseline).contains(
      "set required_release {2024.2}",
    ),
  )
}

///|
test "final bitstream acceptance checks errors and nonempty output after write" {
  let recipe = @pblaze3_board.build_tcl(Accelerator)
  let phases = recipe.split("write_bitstream -force pblaze3.bit\n").to_array()
  assert_eq(phases.length(), 2)
  let final_gate = phases[1]
    .split("set done [open BUILD_COMPLETE w]")
    .to_array()
  assert_eq(final_gate.length(), 2)
  assert_true(
    final_gate[0].contains("get_msg_config -count -severity {CRITICAL WARNING}"),
  )
  assert_true(final_gate[0].contains("get_msg_config -count -severity ERROR"))
  assert_true(final_gate[0].contains("[file size pblaze3.bit] == 0"))
}

///|
test "MIG source is isolated and only the qualified capability rewrite is allowed" {
  let recipe = @pblaze3_board.build_tcl(Accelerator)
  assert_true(
    recipe.contains(
      "file copy [file join $bundle mig.prj] [file join $output mig-source.prj]",
    ),
  )
  assert_true(
    recipe.contains(
      "CONFIG.XML_INPUT_FILE [file join $output mig-effective.prj]",
    ),
  )
  assert_false(
    recipe.contains("CONFIG.XML_INPUT_FILE [file join $bundle mig.prj]"),
  )
  assert_true(recipe.contains("unexpected accelerator MIG XML mutation"))
  assert_true(
    recipe.contains("smoke/baseline MIG XML must remain byte-identical"),
  )
  let generation = recipe
    .split("generate_target all [get_files pblaze3.bd]\n")
    .to_array()
  assert_eq(generation.length(), 2)
  assert_true(
    generation[1].contains(
      "pblaze_record_mig_input $bundle $output $build_mode",
    ),
  )
  assert_true(recipe.contains("get_cells -quiet -include_replicated_objects"))
  assert_true(recipe.contains("PHYS_OPT_MODIFIED"))
}

///|
test "board XDC contains only supported constraint commands and one owned primary clock" {
  let constraints = @pblaze3_board.constraints()
  let mut clocks = 0
  for line in constraints.split("\n") {
    if line == "" || line.has_prefix("#") {
      continue
    }
    assert_true(
      line.has_prefix("set_property ") ||
      line.has_prefix("create_clock ") ||
      line.has_prefix("set_false_path "),
    )
    if line.has_prefix("create_clock ") {
      clocks += 1
      assert_true(line.contains("pcie_ref100 -period 10.000"))
      assert_true(line.contains("CLK_IN_D_0_clk_p[0]"))
    }
  }
  assert_eq(clocks, 1)
}

///|
test "manifest distinguishes user capacity assumption from hardware evidence" {
  guard @pblaze3_board.manifest(Accelerator)
    is {
      "physical_component_identity_verified": False,
      "qualified_on_board": False,
      "memory_bytes": String("2147483648"),
      "control_aperture_bytes": Number(1048576.0, ..),
      ..
    } else {
    fail("manifest overclaims or capacity differs")
  }
}

///|
test "explicit release selection preserves defaults and rejects unsupported pairs" {
  for mode in [@pblaze3_board.BuildMode::VendorBaseline, DdrSmoke, Accelerator] {
    assert_eq(
      @pblaze3_board.build_tcl_for_release(mode, mode.vivado_release()),
      @pblaze3_board.build_tcl(mode),
    )
    assert_eq(
      @pblaze3_board.manifest_for_release(mode, mode.vivado_release()),
      @pblaze3_board.manifest(mode),
    )
  }
  for
    (mode, release) in [
      (@pblaze3_board.BuildMode::VendorBaseline, "2025.2"),
      (VendorBaseline, "2026.1"),
      (DdrSmoke, "2024.2"),
      (Accelerator, "2026.2"),
      (Accelerator, "2026.1.1"),
    ] {
    try @pblaze3_board.build_tcl_for_release(mode, release) catch {
      InvalidProfile(_) => ()
      _ => fail("unexpected error category")
    } noraise {
      _ => fail("unsupported mode/release accepted")
    }
    try @pblaze3_board.manifest_for_release(mode, release) catch {
      InvalidProfile(_) => ()
      _ => fail("unexpected error category")
    } noraise {
      _ => fail("manifest accepted unsupported mode/release")
    }
  }
}

///|
test "explicit 2026.1 profile binds the inspected catalog without changing capacity" {
  for mode in [@pblaze3_board.BuildMode::DdrSmoke, Accelerator] {
    let recipe = @pblaze3_board.build_tcl_for_release(mode, "2026.1")
    assert_true(recipe.contains("set required_release {2026.1}"))
    assert_true(recipe.contains("set xdma_vlnv xilinx.com:ip:xdma:4.2"))
    guard @pblaze3_board.manifest_for_release(mode, "2026.1")
      is {
        "vivado_release": String("2026.1"),
        "memory_bytes": String("2147483648"),
        "qualified_on_board": False,
        ..
      } else {
      fail("tool release must not change the provisional physical capacity")
    }
    assert_eq(mode.vivado_release(), "2025.2")
  }
}

///|
test "DDR smoke status contract is distinct from accelerator and vendor baseline" {
  guard @pblaze3_board.manifest(DdrSmoke)
    is {
      "smoke_status": {
        "bar_offset": String("0x8"),
        "access": String("read-only"),
        "calibrated_mask": Number(1.0, ..),
        "pcie_link_up_mask": Number(2.0, ..),
        "ui_reset_released_mask": Number(4.0, ..),
        "ready_value": Number(7.0, ..),
        ..
      },
      ..
    } else {
    fail("smoke health register contract differs")
  }
  for mode in [@pblaze3_board.BuildMode::VendorBaseline, Accelerator] {
    guard @pblaze3_board.manifest(mode) is { "smoke_status": Null, .. } else {
      fail("GPIO smoke status falsely advertised for another image")
    }
  }
}

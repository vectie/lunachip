///|
test "diagnostic modes retain functional board geometry and explicit tool scope" {
  for
    (text, base) in [
      ("ddr-status-ila", @pblaze3_board.BuildMode::DdrSmoke),
      ("ddr-smoke-ila", DdrSmoke),
      ("accelerator-ila", Accelerator),
      ("ddr-mig-ila", DdrSmoke),
      ("ddr-xdma-ila", DdrSmoke),
      ("accelerator-core-ila", Accelerator),
    ] {
    let mode = @pblaze3_board.parse_mode(text)
    assert_true(mode.is_diagnostic())
    assert_eq(mode.production_mode(), base)
    assert_eq(mode.memory_bytes(), base.memory_bytes())
    assert_eq(mode.vivado_release(), "2026.1")
    guard @pblaze3_board.manifest(mode)
      is {
        "diagnostic_capture_performed": False,
        "physical_component_identity_verified": False,
        "qualified_on_board": False,
        "mode": String(actual),
        ..
      } &&
      actual == text else {
      fail("diagnostic manifest overclaims")
    }
    try @pblaze3_board.build_tcl_for_release(mode, "2025.2") catch {
      InvalidProfile(_) => ()
      _ => fail("unexpected error")
    } noraise {
      _ => fail("unqualified diagnostic release accepted")
    }
  }
  try @pblaze3_board.diagnostic_manifest(DdrSmoke) catch {
    InvalidProfile(_) => ()
    _ => fail("unexpected error")
  } noraise {
    _ => fail("production profile advertised diagnostic capture")
  }
}

///|
test "ILA packing has complete nonoverlapping fields and bounded native probes" {
  for
    (mode, count) in [
      (@pblaze3_board.BuildMode::DdrStatusIla, 1),
      (DdrSmokeIla, 3),
      (AcceleratorIla, 4),
      (DdrMigIla, 1),
      (DdrXdmaIla, 1),
      (AcceleratorCoreIla, 1),
    ] {
    guard @pblaze3_board.diagnostic_manifest(mode)
      is { "cores": Array(cores), .. } else {
      fail("missing capture layout")
    }
    assert_eq(cores.length(), count)
    for core in cores {
      guard core
        is {
          "name": String(name),
          "depth": Number(1024.0, ..),
          "input_pipeline_stages": Number(1.0, ..),
          "probes": Array(probes),
          ..
        } else {
        fail("missing bounded ILA properties")
      }
      assert_true(probes.length() >= 1 && probes.length() <= 5)
      for probe in probes {
        guard probe
          is { "width": Number(width, ..), "fields": Array(fields), .. } else {
          fail("missing probe layout")
        }
        assert_true(width >= 1.0 && width <= 1024.0)
        let mut end = 0.0
        for field in fields {
          guard field
            is { "lsb": Number(lsb, ..), "width": Number(bits, ..), .. } else {
            fail("field layout missing")
          }
          assert_eq(lsb, end)
          assert_true(bits > 0.0)
          end += bits
        }
        assert_eq(end, width)
      }
      if name != "ila_reset50" {
        assert_eq(probes.length(), 5)
      }
    }
  }
}

///|
test "status-only diagnostics avoid stopped bus clocks and preserve reset boundary" {
  let recipe = @pblaze3_board.build_tcl(DdrStatusIla)
  assert_true(recipe.contains("CONFIG.PRIM_SOURCE No_buffer"))
  assert_true(
    recipe.contains("wire diagnostic_clock/clock50 diagnostic_status/clock50"),
  )
  assert_true(recipe.contains("wire diagnostic_clock/clock50 ila_reset50/clk"))
  assert_false(recipe.contains("ip ila_xdma250 "))
  assert_false(recipe.contains("ip ila_mig200 "))
  assert_false(recipe.contains("ip ila_core33 "))
  assert_true(
    recipe.contains("wire clocks/reset_clk50 transport_supervisor/clock50"),
  )
  assert_true(recipe.contains("wire transport_reset_gate/Res xdma/sys_rst_n"))
  assert_true(
    recipe.contains(
      "CONFIG.C_MONITOR_TYPE Native CONFIG.C_ENABLE_ILA_AXI_MON false",
    ),
  )
  assert_false(recipe.contains("create_debug_core"))
  assert_false(recipe.contains("MARK_DEBUG"))
  assert_true(recipe.contains("write_debug_probes -force pblaze3.ltx"))
  let before_write = recipe
    .split("write_bitstream -force pblaze3.bit")
    .to_array()
  assert_eq(before_write.length(), 2)
  assert_true(before_write[0].contains("diagnostic LTX missing"))
  assert_true(
    before_write[1].contains(
      "final bitstream warnings/errors prevent acceptance",
    ),
  )
}

///|
test "AXI observations use local clocks and actual unequal address widths" {
  let recipe = @pblaze3_board.build_tcl(AcceleratorIla)
  for
    expected in [
      "wire mig/ui_clk ila_mig200/clk", "wire xdma/axi_aclk ila_xdma250/clk", "wire clocks/core_clk ila_core33/clk",
      "pblaze_attach_monitor mig/S_AXI ila_mig200_monitor/MON_AXI", "pblaze_attach_monitor xdma/M_AXI ila_xdma250_monitor/MON_AXI",
      "pblaze_attach_monitor accelerator/M_AXI_DDR ila_core33_monitor/MON_AXI", "pblaze_attach_monitor xdma/M_AXI_LITE ila_xdma250_monitor/MON_CTRL",
      "pblaze_attach_monitor accelerator/S_AXI_CTRL ila_core33_monitor/MON_CTRL",
    ] {
    assert_true(recipe.contains(expected))
  }
  for
    constituent in [
      "wire xdma/m_axi_", "wire mig/s_axi_", "wire accelerator/m_axi_",
    ] {
    assert_false(recipe.contains(constituent))
  }
  assert_false(recipe.contains("wire transport_reset_gate/Res ila_"))
  for mode in [@pblaze3_board.BuildMode::VendorBaseline, DdrSmoke, Accelerator] {
    assert_false(@pblaze3_board.build_tcl(mode).contains("diagnostic"))
    assert_false(@pblaze3_board.build_tcl(mode).contains("write_debug_probes"))
  }
}

///|
test "passive AXI monitors cannot drive functional handshake signals" {
  let wrappers = @pblaze3_board.diagnostic_axi_wrappers(AcceleratorIla)
  assert_eq(wrappers.length(), 3)
  assert_eq(@pblaze3_board.diagnostic_axi_wrappers(DdrStatusIla).length(), 0)
  for (filename, source) in wrappers {
    for signal in ["awready", "wready", "bvalid", "arready", "rvalid"] {
      assert_true(source.contains("input wire \{signal},"))
    }
    for line in source.split("\n") {
      if line.contains("output wire") {
        assert_true(line.contains("probe"))
      }
    }
    assert_true(source.contains("X_INTERFACE_MODE = \"monitor\""))
    assert_true(source.contains("wdata, wstrb, wlast, wready, wvalid};"))
    if filename.contains("xdma250") {
      assert_true(source.contains("input wire [63:0] awaddr,"))
    } else if filename.contains("mig200") {
      assert_true(source.contains("input wire [30:0] awaddr,"))
      assert_true(source.contains("input wire [4:0] awid,"))
    } else {
      assert_true(source.contains("input wire [31:0] awaddr,"))
      assert_false(source.contains(" awid,"))
    }
  }
}

///|
test "diagnostic acceptance checks skew and queries the exact standalone route" {
  for
    mode in [
      @pblaze3_board.BuildMode::DdrStatusIla,
      DdrSmokeIla,
      AcceleratorIla,
      DdrMigIla,
      DdrXdmaIla,
      AcceleratorCoreIla,
    ] {
    let recipe = @pblaze3_board.build_tcl(mode)
    let gates = recipe.split("set critical_count [get_msg_config").to_array()
    assert_eq(gates.length(), 2)
    assert_true(
      gates[0].contains("report_bus_skew -warn_on_violation -file bus-skew.rpt"),
    )
    let route = gates[1]
      .split("close_project\nopen_checkpoint [file join $output routed.dcp]\n")
      .to_array()
    assert_eq(route.length(), 2)
    assert_true(route[0].contains("write_checkpoint -force routed.dcp\n"))
    assert_false(route[0].contains("get_debug_cores"))
    assert_true(
      route[1].contains(
        "pblaze_assert_diagnostic_physical $diagnostic_rows $diagnostic_report",
      ),
    )
    assert_true(
      route[1].contains(
        "puts $diagnostic_report PBLAZE3_ILA_ROUTED_GUARD_COMPLETE",
      ),
    )
    assert_true(route[1].contains("write_bitstream -force pblaze3.bit"))
  }
}

///|
test "BASIC single-domain images preserve selected bus layout and omit status logic" {
  for
    (mode, original, selected) in [
      (
        @pblaze3_board.BuildMode::DdrMigIla,
        @pblaze3_board.BuildMode::DdrSmokeIla,
        "ila_mig200",
      ),
      (DdrXdmaIla, DdrSmokeIla, "ila_xdma250"),
      (AcceleratorCoreIla, AcceleratorIla, "ila_core33"),
    ] {
    guard @pblaze3_board.diagnostic_manifest(mode)
      is {
        "cores": Array([core]),
        "status_bits_lsb_first": Array([]),
        "status_sync_stages": Number(0.0, ..),
        ..
      } else {
      fail("single-domain manifest has unexpected status/core metadata")
    }
    guard @pblaze3_board.diagnostic_manifest(original)
      is { "cores": Array(prior), .. } else {
      fail("missing original layout")
    }
    let matches = prior.filter(value => {
      value is { "name": String(name), .. } && name == selected
    })
    assert_eq(matches.length(), 1)
    assert_eq(core, matches[0])
    let recipe = @pblaze3_board.build_tcl(mode)
    assert_eq(recipe.split("ip ila_").count(), 2)
    assert_true(recipe.contains("ip " + selected + " xilinx.com:ip:ila:6.2"))
    assert_false(
      recipe.contains(
        "create_bd_cell -type module -reference pblaze3_diagnostic_status",
      ),
    )
    assert_false(
      recipe.contains("  pblaze_assert_diagnostic_status_sync $report\n"),
    )
    assert_true(recipe.contains("pblaze_assert_diagnostic_raw_clock $report"))
    assert_true(recipe.contains("pblaze_assert_capture_connections"))
    assert_eq(@pblaze3_board.diagnostic_axi_wrappers(mode).length(), 1)
  }
}

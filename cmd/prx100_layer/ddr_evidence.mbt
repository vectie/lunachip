///|
fn ddr_evidence(
  root : String,
  formal : Bool,
  negative : Bool,
  wide~ : Bool = false,
  batch~ : Bool = false,
  clock_ratio~ : Int32 = 4,
  streaming~ : Bool = false,
  read_ahead~ : Bool = false,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
  aligned_extent~ : Bool = false,
  delivery~ : Bool = false,
) -> Unit raise {
  guard !@fs.path_exists(root) else {
    fail("fresh evidence directory required")
  }
  @fs.create_dir(root)
  let hw = if delivery {
    @ddr.delivery_bridge()
  } else if sixteen_row {
    @ddr.sixteen_row_bridge()
  } else if aligned_extent {
    @ddr.aligned_eight_row_bridge()
  } else if eight_row {
    @ddr.eight_row_bridge()
  } else if read_ahead {
    @ddr.read_ahead_bridge()
  } else if streaming {
    @ddr.streaming_bridge()
  } else if batch {
    @ddr.batched_bridge()
  } else if wide {
    @ddr.wide_bridge()
  } else {
    @ddr.bridge()
  }
  let e = @sv.emit_design(
    @ir.Design::single("prx100-ddr-projection-bridge/v1", hw),
  )
  let physical = preserve_bridge(hw, e)
  let artifacts = if formal {
    @ddrtest.formal_bundle(
      physical,
      negative~,
      wide~,
      batch~,
      clock_ratio~,
      streaming~,
      read_ahead~,
      eight_row~,
      sixteen_row~,
      aligned_extent~,
      delivery~,
    )
  } else {
    @ddrtest.bridge_replay_bundle(
      wide~,
      batch~,
      streaming~,
      period=clock_ratio,
      read_ahead~,
      eight_row~,
      sixteen_row~,
      aligned_extent~,
      delivery~,
    )
  }
  for a in artifacts {
    save(
      root,
      a.path,
      if !formal &&
        (a.path == "bridge.sv" || a.path == e.modules()[0].filename()) {
        physical
      } else {
        a.content
      },
    )
  }
  if !formal {
    save(
      root,
      "job.json",
      (
        {
          "schema_version": "lunachip.yosys-job/v1",
          "top_module": e.modules()[0].identifier(),
          "sources": [
            { "path": "bridge.sv", "sha256": @v.sha256_hex(physical) },
          ],
          "formal_tasks": [],
        } : Json).stringify(indent=2) +
      "\n",
    )
  }
}

///|
fn address_formal(
  root : String,
  negative : Bool,
  sixteen_row~ : Bool = false,
) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh address formal root") }
  @fs.create_dir(root)
  let hw = @ddr.address_validation_equivalence(negative~, sixteen_row~)
  let design = @ir.Design::single("prx100-address-validation/v1", hw)
  let e = @sv.emit_design(design)
  save(root, "dut.lcir", @codec.serialize(design))
  save(root, "dut.sv", e.source())
  save(
    root,
    "formal.sv",
    "module address_formal(input wire [63:0] header);\nwire legacy, aligned;\n" +
    e.modules()[0].identifier() +
    " dut(." +
    mapped(e, "header", InputPort) +
    "(header), ." +
    mapped(e, "legacy", OutputPort) +
    "(legacy), ." +
    mapped(e, "aligned", OutputPort) +
    "(aligned));\nalways @* begin p_address_equivalence: assert(legacy==aligned); end\nendmodule\n",
  )
  save(
    root,
    "job.sby",
    "[options]\nmode bmc\ndepth 1\ntimeout 120\nexpect " +
    (if negative { "fail" } else { "pass" }) +
    "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv dut.sv formal.sv\nprep -top address_formal\n[files]\ndut.sv\nformal.sv\n",
  )
  save(
    root,
    "claim.txt",
    if sixteen_row {
      "Actual canonical MoonBit full-header rejection equivalence over all64binaryinputbits. Sixteen-row extent uses explicit21bit aligned address/stride units and25bit A+15*S sum, compared with the32bit byte extent. Alignment,reserved,shape and zero-stride checks are retained. One symbolic frame covers every header. The negative changes only > to >= and must produce a last-valid-line counterexample. This is not a sequential bridge or analog theorem.\n"
    } else {
      "Actual canonical MoonBit combinational header-rejection miter over all64inputbits. Aligned eight-row extent uses explicit21bit address/stride units and24bit sum; existing alignment,reserved,shape and zero-stride checks retained. One symbolic frame covers all headers. Negative changes only aligned extent comparison from > to >=, rejecting the last valid line; complete counterexample required. This is not a sequential bridge or analog theorem.\n"
    },
  )
}

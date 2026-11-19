///|
/// Bounded controller safety with unconstrained host, core and DDR inputs.
/// This proves launch/staging exclusion and fault gating, not DDR liveness.
pub fn resident_formal_bundle(
  negative~ : Bool = false,
  profile~ : Bool = false,
  chain~ : Bool = false,
  program_bursts~ : Bool = false,
  stream_unary~ : Bool = false,
  indirect_bf16~ : Bool = false,
  deep_batch~ : Bool = false,
  strided_rows~ : Bool = false,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let hw = @control.controller(
    profile=profile || chain,
    wide512=chain,
    wide1024=chain,
    scalar_lines=chain,
    store_bursts=chain,
    chain~,
    program_bursts~,
    stream_unary~,
    indirect_bf16~,
    deep_batch~,
    strided_rows~,
  )
  let design = @ir.Design::single("pblaze3-resident-controller/v1", hw)
  let emitted = @sv.emit_design(design)
  let ports = @v.collect_ports(hw, emitted.manifest())
  let inputs : Array[String] = ["input wire clock"]
  let wires : Array[String] = []
  let bindings : Array[String] = []
  for p in ports {
    let range = if p.width() == 1 { "" } else { "[\{p.width()-1}:0] " }
    if p.is_input() && !["clock", "reset"].contains(p.source_name()) {
      inputs.push("input wire " + range + p.source_name())
    }
    if p.is_output() {
      wires.push("wire " + range + p.source_name() + ";")
    }
    bindings.push("." + p.emitted_name() + "(" + p.source_name() + ")")
  }
  let checks =
    #|reg [1:0] boot=0;
    #|always @(posedge clock) if(boot<2) boot<=boot+1;
    #|wire reset=boot<2;
    #|reg seen=0;
    #|always @(posedge clock) begin
    #| seen<=1;
    #| if(!reset) begin
    #|  assert(!start || (memory_healthy && !observe_protocol));
    #|  assert(!start || (observe_loader_state==0 || observe_loader_state==3));
    #|  if(observe_loader_state!=0) begin
    #|   assert(!ddr_request_ready_to_core);
    #|   assert(!program_write || (observe_loader_result && !observe_protocol));
    #|   assert(!start || observe_loader_state==3);
    #|  end
    #|  if(observe_owner==2 && ddr_request_valid) begin
    #|   assert(!ddr_request_write && !ddr_request_line && !ddr_request_burst);
    #|   assert(ddr_request_address<32'h80000000 && ddr_request_address[1:0]==0);
    #|   assert(!ddr_response_valid_to_core);
    #|  end
    #|  if(observe_loader_fault) assert(!start && !program_write && !ddr_request_valid);
    #|  if(seen && $past(!reset && observe_loader_state==4)) assert(observe_loader_state==4);
    #|  if(seen && $past(!reset && observe_owner==2 && ddr_request_valid && !ddr_request_ready) && !observe_protocol && memory_healthy) begin
    #|   assert(ddr_request_valid);
    #|   assert(ddr_request_address==$past(ddr_request_address));
    #|  end
    #| end
    #|end
  let checks = if program_bursts {
    checks
    .replace(
      old="observe_loader_result && !observe_protocol",
      new="ddr_response_valid && observe_issued && observe_owner==2 && !observe_protocol && !ddr_response_valid_to_core",
    )
    .replace(
      old="assert(!ddr_request_write && !ddr_request_line && !ddr_request_burst);",
      new="assert(!ddr_request_write && ddr_request_line==ddr_request_burst && ddr_request_wide==ddr_request_burst); if(ddr_request_wide) begin assert(ddr_request_address[6:0]==0); if(ddr_request_data[31]) begin assert(ddr_request_data==32'hc0000200); assert(ddr_request_address[8:0]==0); end end",
    )
  } else {
    checks
  }
  let chain_checks = if chain {
    "\nalways @(posedge clock) if (!reset && observe_loader_state==3 && start) begin assert(program_count>=1 && program_count<=2048); assert(memory_healthy); end\n"
  } else {
    ""
  }
  let checks = if stream_unary {
    checks +
    "\nalways @(posedge clock) if (seen && !reset) begin if ($past(reset)) assert(!unary_legacy); if ($past(!reset && (c_busy || observe_loader_state!=0 || observe_owner!=0))) assert($stable(unary_legacy)); end\n"
  } else {
    checks
  }
  let negative_check = if negative && stream_unary {
    "\nalways @(posedge clock) if(!reset) assert(!unary_legacy);\n"
  } else if negative && program_bursts {
    "\nalways @(posedge clock) if(!reset) assert(!(observe_owner==2 && ddr_request_valid && ddr_request_ready && ddr_request_wide));\n"
  } else if negative && chain {
    "\nalways @(posedge clock) if (!reset) assert(!(s_axi_awaddr==16 && s_axi_awvalid && s_axi_wvalid && s_axi_wdata==2 && $past(observe_loader_state==0) && observe_loader_state==1));\n"
  } else if negative {
    "\nalways @(posedge clock) if(!reset) assert(observe_loader_state==0);\n"
  } else {
    ""
  }
  let wrapper = "module resident_formal(" +
    inputs.join(",\n") +
    ");\n" +
    wires.join("\n") +
    "\n" +
    emitted.modules()[0].identifier() +
    " dut(" +
    bindings.join(",\n") +
    ");\n" +
    checks +
    chain_checks +
    negative_check +
    "\nendmodule\n"
  ReadOnlyArray::from_array([
    { path: "dut.sv", content: emitted.source(), },
    { path: "design.lcir", content: @codec.serialize(design), },
    { path: "formal.sv", content: wrapper, },
    {
      path: "job.sby",
      content: "[options]\nmode bmc\ndepth 40\n" +
      (if program_bursts && negative {
        "timeout 1800\nvcd off\n"
      } else if indirect_bf16 {
        "timeout 1800\n"
      } else {
        "timeout 600\n"
      }) +
      "expect " +
      (if negative { "fail" } else { "pass" }) +
      "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv dut.sv formal.sv\nprep -top resident_formal\n[files]\ndut.sv\nformal.sv\n",
    },
    {
      path: "claim.txt",
      content: "Bounded safety40 edges after two-edge coordinated reset. Unconstrained AXIL, core and DDR inputs. Resident staging excludes core launch/DDR ownership; owned loads are read-only/aligned/in2GiB; stalled addresses stable unless poisoned; bad data cannot write RAM or launch; loader poison sticky. No fairness, completion, full-program or physical timing claim. " +
      (if stream_unary {
        "Unary mode resets to streaming and stays stable during core execution, program staging and occupied memory transactions. Negative control forbids selecting the legacy mode.\n"
      } else if program_bursts {
        "Negative control forbids an accepted wide resident read; the counterexample must exercise that bus operation.\n"
      } else {
        "Negative asserts loader never starts and must find accepted START.\n"
      }),
    },
  ])
}

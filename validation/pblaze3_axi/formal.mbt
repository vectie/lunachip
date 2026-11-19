///|
/// Bounded safety fixture with unconstrained AXI/source inputs and coordinated
/// initial reset. Negative replaces the valid2GiB aperture assertion with256MiB.
/// No fairness or response-liveness claim is made.
pub fn formal_bundle(
  negative~ : Bool = false,
  streaming~ : Bool = false,
  wide512~ : Bool = false,
  wide1024~ : Bool = false,
  deep_batch~ : Bool = false,
  strided_rows~ : Bool = false,
  group64_rows~ : Bool = false,
  stripe512~ : Bool = false,
  prefetch_row_blocks~ : Bool = false,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let hw = @axi.bridge(
    streaming~,
    wide512~,
    wide1024~,
    deep_batch~,
    strided_rows~,
    store_bursts=deep_batch,
    staged_fill=group64_rows,
    group64_rows~,
    stripe512~,
    prefetch_row_blocks~,
  )
  let design = @ir.Design::single("pblaze3-axi/v1", hw)
  let e = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hw, e.manifest())
  let inputs : Array[String] = ["input wire clock"]
  let wires : Array[String] = []
  let bindings : Array[String] = []
  for p in ports {
    let range = if p.width() == 1 {
      ""
    } else {
      "[" + (p.width() - 1).to_string() + ":0] "
    }
    if p.is_input() && !["clock", "reset"].contains(p.source_name()) {
      inputs.push("input wire " + range + p.source_name())
    }
    if p.is_output() {
      wires.push("wire " + range + p.source_name() + ";")
    }
    bindings.push("." + p.emitted_name() + "(" + p.source_name() + ")")
  }
  let hold_checks : Array[String] = []
  for
    (valid, ready, fields) in [
      (
        "m_axi_awvalid",
        "m_axi_awready",
        ["m_axi_awaddr", "m_axi_awlen", "m_axi_awsize", "m_axi_awburst"],
      ),
      (
        "m_axi_arvalid",
        "m_axi_arready",
        ["m_axi_araddr", "m_axi_arlen", "m_axi_arsize", "m_axi_arburst"],
      ),
      (
        "m_axi_wvalid",
        "m_axi_wready",
        [
          "m_axi_wword0", "m_axi_wword1", "m_axi_wword2", "m_axi_wword3", "m_axi_wstrb",
          "m_axi_wlast",
        ],
      ),
      (
        "response_valid",
        "response_ready",
        [
          "response_data", "response_data1", "response_data2", "response_data3",
          "response_data4", "response_data5", "response_data6", "response_data7",
          "response_fault", "response_last", "response_wide",
        ],
      ),
    ] {
    if streaming && valid == "m_axi_wvalid" {
      if wide1024 {
        fields.push("m_axi_wstrb_hi")
      }
      for lane in 4..<(if wide1024 { 32 } else if wide512 { 16 } else { 8 }) {
        fields.push("m_axi_wword" + lane.to_string())
      }
    }
    if wide512 && valid == "response_valid" {
      for lane in 8..<(if wide1024 { 32 } else { 16 }) {
        fields.push("response_data" + lane.to_string())
      }
    }
    hold_checks.push(
      "if(f_seen && $past(!reset && " +
      valid +
      " && !" +
      ready +
      ")) begin\nassert(" +
      valid +
      ");\n" +
      fields.map(s => "assert(" + s + "==$past(" + s + "));").join("\n") +
      "\nend",
    )
  }
  let address_bits = if wide1024 { 7 } else if wide512 { 6 } else { 5 }
  let lanes = if wide1024 { 32 } else if wide512 { 16 } else { 8 }
  let strobe = if wide1024 {
    "{m_axi_wstrb_hi,m_axi_wstrb}"
  } else {
    "m_axi_wstrb"
  }
  let masks = Array::makei(lanes, i => {
    strobe +
    "==(" +
    (lanes * 4).to_string() +
    "'hf<<" +
    (i * 4).to_string() +
    ")"
  })
  for i in 0..<(lanes / 4) {
    masks.push(
      strobe +
      "==(" +
      (lanes * 4).to_string() +
      "'hffff<<" +
      (i * 16).to_string() +
      ")",
    )
  }
  let long_len = if wide1024 { 3 } else { 32 / lanes - 1 }
  let align_high = if wide1024 { 8 } else { 6 }
  let extra_burst = if stripe512 {
    " || (m_axi_arlen==7 && m_axi_araddr[9:0]==0)"
  } else {
    ""
  }
  let deep_properties = if deep_batch {
    // Isolate the new read protocol on the complete production bridge.
    // Responses, health, stalls, address and alignment remain unconstrained.
    (
      #|always @* if(request_valid) begin
      #| assume(!request_write && request_wide && request_line && request_burst);
      #| assume(request_data==32'he0000200);
      #|end
      #|reg [31:0] expected_ar;
      #|reg [6:0] count_ar;
      #|always @(posedge clock) if (!reset) begin
      #| if(request_valid && request_ready) begin expected_ar<=request_address;count_ar<=0;end
      #| if(m_axi_arvalid) begin assert(m_axi_araddr==expected_ar); assert(m_axi_arlen==3);assert(count_ar<64);end
      #| if(m_axi_arvalid && m_axi_arready) begin expected_ar<=expected_ar+512;count_ar<=count_ar+1;end
      #|end
    )
  } else {
    ""
  }
  let deep_properties = if prefetch_row_blocks {
    (
      #|always @* if(request_valid) begin
      #| assume(!request_write && request_wide && request_line && request_burst);
      #| assume(request_data==32'hfc000800 || request_data==32'hfc001000 || request_data==32'hfc001800);
      #|end
      #|reg [35:0] expected_ar, last_byte;
      #|reg [12:0] row_step;
      #|reg [9:0] count_ar;
      #|always @(posedge clock) if(!reset) begin
      #| if(request_valid && request_ready) begin
      #|   expected_ar<={4'b0,request_address}; count_ar<=0; row_step<=request_data[12:0];
      #|   last_byte<={4'b0,request_address}+511*{23'b0,request_data[12:0]}+1023;
      #| end
      #| if(m_axi_arvalid) begin
      #|   assert({4'b0,m_axi_araddr}==expected_ar && last_byte<36'h080000000);
      #|   assert(m_axi_araddr[9:0]==0 && m_axi_arlen==7 && count_ar<512);
      #| end
      #| if(m_axi_arvalid && m_axi_arready) begin expected_ar<=expected_ar+row_step; count_ar<=count_ar+1; end
      #|end
    )
  } else if stripe512 {
    (
      #|always @* if(request_valid) begin
      #| assume(!request_write && request_wide && request_line && request_burst);
      #| assume((request_data & 32'hf7ffffff)==32'hf0000800 ||
      #|        (request_data & 32'hf7ffffff)==32'hf0001000 ||
      #|        (request_data & 32'hf7ffffff)==32'hf0001800);
      #|end
      #|reg [35:0] expected_ar;
      #|reg [12:0] row_step;
      #|reg [6:0] count_ar;
      #|reg wide_row;
      #|always @(posedge clock) if(!reset) begin
      #| if(request_valid && request_ready) begin
      #|   expected_ar<={4'b0,request_address}; count_ar<=0;
      #|   row_step<=request_data[12:0]; wide_row<=request_data[27];
      #| end
      #| if(m_axi_arvalid) begin
      #|   assert({4'b0,m_axi_araddr}==expected_ar);
      #|   if(wide_row) begin
      #|     assert(m_axi_araddr[9:0]==0 && expected_ar+1023 < 36'h080000000);
      #|     assert(m_axi_arlen==7 && count_ar<32);
      #|   end else begin
      #|     assert(m_axi_araddr[8:0]==0 && expected_ar+511 < 36'h080000000);
      #|     assert(m_axi_arlen==3 && count_ar<64);
      #|   end
      #| end
      #| if(m_axi_arvalid && m_axi_arready) begin expected_ar<=expected_ar+row_step; count_ar<=count_ar+1; end
      #|end
    )
  } else if group64_rows {
    (
      #|always @* if(request_valid) begin
      #| assume(!request_write && request_wide && request_line && request_burst);
      #| assume(request_data==32'hf0000800 || request_data==32'hf0001000 || request_data==32'hf0001800);
      #|end
      #|reg [35:0] expected_ar;
      #|reg [31:0] row_step;
      #|reg [6:0] count_ar;
      #|always @(posedge clock) if(!reset) begin
      #| if(request_valid && request_ready) begin
      #|   expected_ar<={4'b0,request_address}; count_ar<=0; row_step<=request_data[12:0];
      #| end
      #| if(m_axi_arvalid) begin
      #|   assert({4'b0,m_axi_araddr}==expected_ar && m_axi_araddr[8:0]==0);
      #|   assert(expected_ar+511 < 36'h080000000 && m_axi_arlen==3 && count_ar<64);
      #| end
      #| if(m_axi_arvalid && m_axi_arready) begin expected_ar<=expected_ar+row_step; count_ar<=count_ar+1; end
      #|end
    )
  } else if strided_rows {
    deep_properties
    .replace(
      old="assume(request_data==32'he0000200);",
      new="assume(request_data==32'he0000200 || request_data==32'he0001000 || request_data==32'he0001800);",
    )
    .replace(
      old="reg [31:0] expected_ar;",
      new="reg [31:0] expected_ar, row_step;",
    )
    .replace(
      old="expected_ar<=request_address;count_ar<=0;",
      new="expected_ar<=request_address;count_ar<=0;row_step<=request_data==32'he0001000 ? 2560 : request_data==32'he0001800 ? 4608 : 512;",
    )
    .replace(
      old="expected_ar+512",
      new="expected_ar+(count_ar[1:0]==3 ? row_step : 32'd512)",
    )
  } else {
    deep_properties
  }
  let properties = (
      #|reg [1:0] f_boot=0;
      #|always @(posedge clock) if(f_boot<2) f_boot<=f_boot+1;
      #|wire reset=f_boot<2;
      #|reg f_seen=0, f_owner=0;
      #|reg [4:0] f_read=0;
      #|reg f_aw=0, f_w=0;
      #|always @(posedge clock) begin
      #|  f_seen<=1;
      #|  if(reset) begin f_owner<=0; f_read<=0; f_aw<=0; f_w<=0; end
      #|  else begin
      #|    if(request_valid && request_ready) begin assert(!f_owner); f_owner<=1; end
      #|    if(response_valid && response_ready && response_last) f_owner<=0;
      #|    assert(!response_valid || f_owner);
      #|    assert(!(request_ready && response_valid));
      #|    if(m_axi_awvalid && m_axi_awready) begin assert(!f_aw); f_aw<=1; end
      #|    if(m_axi_wvalid && m_axi_wready) begin assert(!f_w); f_w<=1; end
      #|    if(m_axi_bvalid && m_axi_bready) begin assert(f_aw && f_w); f_aw<=0; f_w<=0; end
      #|    assert(!m_axi_arvalid || (m_axi_araddr[3:0]==0 && m_axi_araddr<32'h80000000));
      #|    assert(!m_axi_awvalid || (m_axi_awaddr[3:0]==0 && m_axi_awaddr<32'h80000000));
      #|    assert(m_axi_awburst==1 && m_axi_arburst==1 && m_axi_wlast);
      #|    if(f_seen && $past(!reset && bridge_poisoned)) assert(bridge_poisoned);
    ) +
    "\n" +
    (if streaming {
      (
        $|    case ({m_axi_arvalid && m_axi_arready, m_axi_rvalid && m_axi_rready && m_axi_rlast})
        $|      2'b10: f_read <= f_read+1;
        $|      2'b01: f_read <= f_read-1;
        $|    endcase
        $|    assert(f_read<=16);
        $|    if(m_axi_rvalid && m_axi_rready) assert(f_read!=0);
        $|    assert(m_axi_awlen==0 && m_axi_awsize==\{address_bits} && m_axi_arsize==\{address_bits});
        $|    if(m_axi_awvalid) assert(m_axi_awaddr[\{address_bits-1}:0]==0);
        $|    if(m_axi_arvalid) begin
        $|      assert(m_axi_araddr[\{address_bits-1}:0]==0);
        $|      assert(m_axi_arlen==0 || (m_axi_arlen==\{long_len} && m_axi_araddr[\{align_high}:0]==0)\{extra_burst});
        $|    end
        $|    if(m_axi_wvalid) assert(\{masks.join(" || ")});
      )
    } else {
      (
        #|    if(m_axi_arvalid && m_axi_arready) begin assert(!f_read); f_read<=1; end
        #|    if(m_axi_rvalid && m_axi_rready) begin assert(f_read); f_read<=0; end
        #|    assert(m_axi_awlen==0 && m_axi_arlen==0 && m_axi_awsize==4 && m_axi_arsize==4);
        #|    assert(!m_axi_wvalid || m_axi_wstrb==16'hffff || m_axi_wstrb==16'h000f || m_axi_wstrb==16'h00f0 || m_axi_wstrb==16'h0f00 || m_axi_wstrb==16'hf000);
      )
    }) +
    "\n" +
    hold_checks.join("\n") +
    (if negative && deep_batch {
      "\nassert(f_read<=4);"
    } else if negative {
      "\nassert(!m_axi_arvalid || m_axi_araddr<32'h10000000);"
    } else {
      ""
    }) +
    "\nend\nend\n"
  let properties = if deep_batch {
    properties
    .replace(old=" && m_axi_wlast);", new=");")
    .replace(
      old="assert(m_axi_awlen==0 && m_axi_awsize==7 && m_axi_arsize==7);",
      new="assert(!m_axi_awvalid && !m_axi_wvalid); assert(m_axi_arsize==7);",
    )
  } else {
    properties
  }
  let wrapper = "module pblaze3_axi_formal(" +
    inputs.join(",\n") +
    ");\n" +
    wires.join("\n") +
    "\n" +
    e.modules()[0].identifier() +
    " dut(" +
    bindings.join(",\n") +
    ");\n" +
    properties +
    "\n" +
    deep_properties +
    "\nendmodule\n"
  ReadOnlyArray::from_array([
    { path: "dut.sv", content: e.source(), },
    { path: "design.lcir", content: @codec.serialize(design), },
    { path: "formal.sv", content: wrapper, },
    {
      path: "job.sby",
      content: "[options]\nmode bmc\ndepth 40\ntimeout " +
      (if strided_rows { "7200" } else if deep_batch { "5400" } else { "600" }) +
      "\nexpect " +
      (if negative { "fail" } else { "pass" }) +
      "\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv dut.sv formal.sv\nprep -top pblaze3_axi_formal\n[files]\ndut.sv\nformal.sv\n",
    },
    {
      path: "claim.txt",
      content: if prefetch_row_blocks {
        "40-edge bounded check on the 512-row lookahead reader. Check full extent, ordered 1 KiB addresses, stall stability and outstanding credit at each Qwen pitch. Negative control forbids the fifth outstanding read. Full-length transactions are exercised in simulation."
      } else if stripe512 {
        "Bounded to 40 edges on the deployed bridge. Symbolic 512 B and 1 KiB row slices at all three Qwen strides, addresses, stalls, DDR health and AXI responses. Check each burst address, size, credit, aperture and stability. Negative control forbids a fifth outstanding read.\n"
      } else if group64_rows {
        "Bounded 40-edge safety check on the deployed 64-row reader. All three Qwen row pitches, request addresses, memory health, stalls and AXI responses are symbolic. Check burst start addresses, alignment, aperture, credit limits and backpressure. The negative control forbids a fifth outstanding read.\n"
      } else if strided_rows {
        "Forty core-clock edges on the production bridge with arbitrary request addresses, stalls and AXI responses. The three 32 KiB requests use 512-byte bursts in row-major order with row pitches of 2048, 4096 or 6144 bytes. Every issued burst is checked against a reference address counter. Negative control forbids a fifth outstanding read.\n"
      } else if deep_batch {
        "Forty core-clock edges after a two-edge reset on the production bridge. Requests select the 32 KiB read command. Addresses, stalls, DDR health and AXI responses remain unconstrained. The checks cover sequential 512-byte bursts, the 2 GiB aperture, outstanding credits, stable payload under backpressure and fault poisoning. The negative control forbids a fifth outstanding read.\n"
      } else {
        "Bounded safety40 core-clock edges, initial two-edge coordinated reset, unconstrained AXI/source inputs. Request ownership, read credits, single outstanding write, valid/payload hold, 2GiB aligned addresses, burst bounds, write strobes and sticky poison. Streaming=\{streaming}. Negative intentionally rejects valid addresses>=256MiB.\n"
      },
    },
  ])
}

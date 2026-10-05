///|
fn queue_harness(
  fixture : QueueFormalFixture,
  dut : QueueFormalDut,
  exported : String,
) -> String raise FormalGateError {
  if dut.observation_ports.length() != 115 {
    raise InvalidFormalBundleIdentity(
      "queue harness requires all 115 observations",
    )
  }
  let out = StringBuilder()
  let header =
    #|`default_nettype none
    #|// Structural queue conservation only; no packet identity or liveness.
    #|module lc_formal_queue_top;
    #|  logic lc_clock = 1'b0;
    #|  always @($global_clock) lc_clock <= ~lc_clock;
    #|
  out.write_string(header)
  for port in dut.ports {
    if port.role != "clock" {
      let symbolic = if port.input { "(* anyseq *) " } else { "" }
      out.write_string(
        "  \{symbolic}logic \{toggle_formal_width_range(port.width)}lc_\{port.role};\n",
      )
    }
  }
  for port in dut.observation_ports {
    out.write_string(
      "  logic \{toggle_formal_width_range(port.width)}lc_o_\{port.role};\n",
    )
  }
  out.write_string("  \{dut.identifier} lc_dut (\n")
  for port in dut.ports {
    out.write_string("    .\{port.identifier}(lc_\{port.role}),\n")
  }
  for index, port in dut.observation_ports {
    out.write_string("    .\{port.identifier}(lc_o_\{port.role})")
    out.write_string(
      if index + 1 == dut.observation_ports.length() {
        "\n"
      } else {
        ",\n"
      },
    )
  }
  out.write_string("  );\n")
  // These are the existing direct-device public-peer assumptions verbatim.
  // In particular, tag/status/success and later reset remain unconstrained.
  let host =
    #|  logic lc_seen_edge = 1'b0;
    #|  logic lc_previous_descriptor_hold = 1'b0;
    #|  logic lc_previous_response_hold = 1'b0;
    #|  logic [255:0] lc_previous_descriptor_payload = 256'd0;
    #|  logic [65:0] lc_previous_response_payload = 66'd0;
    #|  wire [255:0] lc_descriptor_payload = {lc_descriptor_lane_3,
    #|    lc_descriptor_lane_2, lc_descriptor_lane_1, lc_descriptor_lane_0};
    #|  wire [65:0] lc_response_payload = {lc_memory_response_tag,
    #|    lc_memory_response_fault, lc_memory_response_data};
    #|  always_ff @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    if (lc_reset) begin
    #|      lc_previous_descriptor_hold <= 1'b0;
    #|      lc_previous_response_hold <= 1'b0;
    #|    end else begin
    #|      lc_previous_descriptor_hold <= lc_descriptor_valid && !lc_descriptor_ready;
    #|      lc_previous_response_hold <= lc_memory_response_valid && !lc_memory_response_ready;
    #|      lc_previous_descriptor_payload <= lc_descriptor_payload;
    #|      lc_previous_response_payload <= lc_response_payload;
    #|    end
    #|  end
    #|  wire lc_initial_joint_reset = lc_seen_edge || lc_reset;
    #|  wire lc_host_descriptor_stable_until_accept = lc_reset || !lc_previous_descriptor_hold
    #|    || (lc_descriptor_valid && lc_descriptor_payload == lc_previous_descriptor_payload);
    #|  wire lc_host_response_stable_until_accept = lc_reset || !lc_previous_response_hold
    #|    || (lc_memory_response_valid && lc_response_payload == lc_previous_response_payload);
    #|  // No tag/status/success assumption: faults and poison remain symbolic.
    #|  wire lc_host_response_flushed_during_reset = !lc_reset || !lc_memory_response_valid;
    #|
  out.write_string(host)
  let base_fixture = if queue_records_profile(fixture) {
    QueueFormalFixture::Conservation
  } else {
    fixture
  }
  out.write_string(queue_monitor_source(base_fixture))
  if queue_records_profile(fixture) {
    out.write_string(
      queue_retirement_records_source(fixture is NegativeHeldPayload),
    )
  }
  out.write_string(exported)
  out.write_string("endmodule\n`default_nettype wire\n")
  out.to_string()
}

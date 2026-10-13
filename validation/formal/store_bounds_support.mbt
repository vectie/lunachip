///|
// The non-power-of-two descriptor memories use the ORIGINAL UInt2 pointer
// registers. Resolve through actual port addresses and verify their actual
// reset/wrap/fire recurrence; no synthetic FIFO, shadow pointer or free leaf.
fn store_bounds_pointer_identifier(
  inputs : StorePreservationProofInputs,
  address : @ir.NodeId,
  fire : @ir.NodeId,
) -> String raise {
  let source = inputs.projection.plan.probe.source
  let pointer = dependency_generation_node(source, address)
  guard pointer.signal_type() == @wire.uint(2) &&
    pointer.kind() is Register(spec) &&
    spec.domain() == @ir.ClockDomain::rising(inputs.projection.plan.probe.clock) &&
    spec.initial() == None &&
    spec.enable() == None &&
    spec.reset() is Some(reset) &&
    reset.signal() == inputs.projection.plan.probe.reset &&
    reset.mode() is Synchronous &&
    reset.polarity() is ActiveHigh &&
    reset.value() == 0UL else {
    raise InvalidFormalBundleIdentity(
      "Store bounds: original UInt2 synchronous-zero-reset pointer",
    )
  }
  let (actual_fire, advanced, held) = dependency_generation_decoder_mux(
    source,
    spec.next(),
  )
  let (at_last, zero, incremented) = dependency_generation_decoder_mux(
    source, advanced,
  )
  if actual_fire != fire ||
    held != address ||
    dependency_generation_decoder_equal_constant(source, at_last, 2, 2UL) !=
    address {
    raise InvalidFormalBundleIdentity(
      "Store bounds: actual memory-port fire/hold/wrap identity",
    )
  }
  dependency_generation_decoder_constant(source, zero, @wire.uint(2), 0UL)
  guard dependency_generation_node(source, incremented).signal_type() ==
    @wire.uint(2) &&
    dependency_generation_node(source, incremented).kind() is Add(left, right) &&
    left == address else {
    raise InvalidFormalBundleIdentity(
      "Store bounds: actual modular pointer increment",
    )
  }
  dependency_generation_decoder_constant(source, right, @wire.uint(2), 1UL)
  store_preservation_node_identifier(inputs.projection, inputs.emitted, address)
}

///|
// Eight unconditional-after-startup range conclusions strengthen induction for
// all eight original descriptor port bounds. Startup history/reset assumptions
// remain owned by the caller's ORIGINAL observer, not recreated here. Original
// C memories have depth4/UInt2 ports: their four emitted address-known checks
// are Boolean helper tautologies, not logical rectangle/payload conclusions.
fn store_bounds_support_source(
  inputs : StorePreservationProofInputs,
) -> String raise {
  let out = StringBuilder()
  let assertions = StringBuilder()
  let names : Array[String] = []
  let pointers : Array[@ir.NodeId] = []
  for memory in inputs.projection.plan.memories {
    guard memory.read_ports() is [read] &&
      memory.write_ports() is [write] &&
      read.enable() is Some(read_fire) &&
      write.enable() is Some(write_fire) &&
      memory.bounds_policy() is Fault else {
      raise InvalidFormalBundleIdentity("Store bounds: original memory ports")
    }
    if memory.name() == "c_result_slot_0" || memory.name() == "c_result_slot_1" {
      if memory.depth().elements() != 4 ||
        memory.element_type() != @wire.sint(32) ||
        dependency_generation_node(
          inputs.projection.plan.probe.source,
          read.address(),
        ).signal_type() !=
        @wire.uint(2) ||
        dependency_generation_node(
          inputs.projection.plan.probe.source,
          write.address(),
        ).signal_type() !=
        @wire.uint(2) {
        raise InvalidFormalBundleIdentity(
          "Store bounds: power-of-two C address-width identity",
        )
      }
      continue
    }
    guard memory.depth().elements() == 3 &&
      memory.element_type() == @wire.bits(64) &&
      memory.name().has_prefix("descriptor_lane_") &&
      memory.name().has_suffix(".storage") else {
      raise InvalidFormalBundleIdentity(
        "Store bounds: original descriptor lane memory identity",
      )
    }
    names.push(memory.name())
    for
      (access, address, fire) in [
        ("read", read.address(), read_fire),
        ("write", write.address(), write_fire),
      ] {
      if pointers.contains(address) {
        raise InvalidFormalBundleIdentity(
          "Store bounds: distinct original lane pointers",
        )
      }
      pointers.push(address)
      let identifier = store_bounds_pointer_identifier(inputs, address, fire)
      let lane = names.length() - 1
      let pointer_alias = "lc_bounds_lane_\{lane}_\{access}_pointer"
      out.write_string("  wire [1:0] \{pointer_alias} = \{identifier};\n")
      assertions.write_string(
        "    lc_bounds_lane_\{lane}_\{access}_range: assert ((!lc_seen_edge || \{pointer_alias} < 2'd3) === 1'b1);\n",
      )
    }
  }
  if inputs.projection.plan.memories.length() != 6 ||
    names !=
    [
      "descriptor_lane_0.storage", "descriptor_lane_1.storage", "descriptor_lane_2.storage",
      "descriptor_lane_3.storage",
    ] ||
    pointers.length() != 8 {
    raise InvalidFormalBundleIdentity(
      "Store bounds: exact six-memory/eight-pointer inventory",
    )
  }
  out.write_string("  always @(posedge lc_clock) begin\n")
  out.write_string(assertions.to_string())
  out.write_string("  end\n")
  out.to_string()
}

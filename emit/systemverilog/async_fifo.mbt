///|
fn module_has_async_fifo(hardware_module : @ir.Module) -> Bool {
  hardware_module.cdc_primitives().any(primitive => primitive is AsyncFifo(_))
}

///|
fn async_fifo_read_address(
  hardware_module : @ir.Module,
  primitive : @ir.CdcPrimitiveId,
) -> String raise EmitError {
  for candidate in hardware_module.cdc_primitives() {
    match candidate {
      AsyncFifo(fifo) if fifo.id() == primitive =>
        return node_name(fifo.read_address())
      _ => ()
    }
  }
  raise InvalidNodeReference(
    module_name=hardware_module.name(),
    node=primitive.ordinal(),
  )
}

///|
fn async_fifo_dependencies(
  hardware_module : @ir.Module,
  fifo : @ir.AsyncFifoPrimitive,
) -> Array[@ir.NodeId] raise EmitError {
  guard hardware_module.domain(fifo.source_domain()) is Some(source_domain) else {
    raise InvalidNodeReference(
      module_name=hardware_module.name(),
      node=fifo.source_domain().ordinal(),
    )
  }
  let dependencies : Array[@ir.NodeId] = [
    source_domain.clock(),
    fifo.source_transfer(),
    fifo.write_address(),
    fifo.read_address(),
  ]
  for node in fifo.source_payload() {
    dependencies.push(node)
  }
  for node in fifo.raw_reads() {
    dependencies.push(node)
  }
  dependencies
}

///|
fn async_fifo_declarations(
  hardware_module : @ir.Module,
  fifo : @ir.AsyncFifoPrimitive,
) -> String raise EmitError {
  let out = StringBuilder()
  for leaf, payload in fifo.source_payload() {
    let node = node_at(hardware_module, payload)
    out.write_string(
      "  \{sv_logic_type(node.signal_type())} \{async_fifo_lane_identifier(fifo.id().ordinal(), leaf)} [0:\{fifo.depth() - 1}];\n",
    )
  }
  let width = fifo.pointer_width() - 1
  let known = async_fifo_address_known_identifier(fifo.id().ordinal())
  out.write_string(
    "  function automatic logic \{known}(input logic [\{width - 1}:0] lc_address);\n",
  )
  out.write_string("`ifdef FORMAL\n")
  out.write_string("    \{known} = 1'b1;\n")
  out.write_string("`else\n")
  out.write_string("    \{known} = ((^lc_address) !== 1'bx);\n")
  out.write_string("`endif\n")
  out.write_string("  endfunction\n")
  out.to_string()
}

///|
fn emit_async_fifo(
  hardware_module : @ir.Module,
  fifo : @ir.AsyncFifoPrimitive,
) -> String raise EmitError {
  guard hardware_module.domain(fifo.source_domain()) is Some(source_domain) else {
    raise InvalidNodeReference(
      module_name=hardware_module.name(),
      node=fifo.source_domain().ordinal(),
    )
  }
  let out = StringBuilder()
  let address = node_name(fifo.write_address())
  let known = async_fifo_address_known_identifier(fifo.id().ordinal())
  out.write_string(
    "  always_ff @(posedge \{node_name(source_domain.clock())}) begin\n",
  )
  out.write_string(
    "    if ((\{node_name(fifo.source_transfer())} === 1'b1) && (\{known}(\{address}) === 1'b1)) begin\n",
  )
  for leaf, payload in fifo.source_payload() {
    out.write_string(
      "      \{async_fifo_lane_identifier(fifo.id().ordinal(), leaf)}[\{address}] <= \{node_name(payload)};\n",
    )
  }
  out.write_string("    end\n")
  out.write_string("  end\n")
  out.to_string()
}

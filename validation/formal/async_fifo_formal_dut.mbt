///|
struct AsyncFifoFormalObservation {
  role : String
  width : Int
  port : String
  node : String
} derive(Debug, Eq)

///|
struct AsyncFifoFormalDut {
  identifier : String
  filename : String
  source : String
  observations : Array[AsyncFifoFormalObservation]
} derive(Debug, Eq)

///|
fn async_fifo_require_unique_marker(
  source : String,
  marker : String,
  label : String,
) -> Unit raise FormalGateError {
  if source.split(marker).length() != 2 {
    raise InvalidAsyncFifoFormalBundle(
      "formal DUT expected exactly one emitted module \{label}",
    )
  }
}

///|
fn async_fifo_validate_formal_observations(
  observations : Array[AsyncFifoFormalObservation],
) -> Unit raise FormalGateError {
  if observations.length() != 20 {
    raise InvalidAsyncFifoFormalBundle(
      "formal DUT expected exactly twenty observation roles",
    )
  }
  for index, observation in observations {
    if observation.width < 1 ||
      observation.role == "" ||
      observation.port == "" ||
      observation.node == "" {
      raise InvalidAsyncFifoFormalBundle(
        "formal DUT observation roles must be fully typed",
      )
    }
    for prior_index in 0..<index {
      let prior = observations[prior_index]
      if observation.role == prior.role ||
        observation.port == prior.port ||
        observation.node == prior.node {
        raise InvalidAsyncFifoFormalBundle(
          "formal DUT observation roles, ports, and nodes must be unique",
        )
      }
    }
  }
}

///|
fn async_fifo_formal_observation(
  emitted : @rtl.EmittedDesign,
  role : String,
  width : Int,
  id : @ir.NodeId,
) -> AsyncFifoFormalObservation raise FormalGateError {
  {
    role,
    width,
    port: "lc_formal_observe_\{role}",
    node: emitted_node_identifier(emitted, id.ordinal()),
  }
}

///|
fn async_fifo_formal_observations(
  design : @ir.Design,
  emitted : @rtl.EmittedDesign,
) -> Array[AsyncFifoFormalObservation] raise FormalGateError {
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  guard hardware_module.cdc_primitives() is [AsyncFifo(spec)] else {
    raise InvalidAsyncFifoFormalBundle("expected one asynchronous FIFO")
  }
  [
    async_fifo_formal_observation(
      emitted,
      "source_transfer",
      1,
      spec.source_transfer(),
    ),
    async_fifo_formal_observation(
      emitted,
      "destination_transfer",
      1,
      spec.destination_transfer(),
    ),
    async_fifo_formal_observation(
      emitted,
      "write_binary",
      3,
      spec.write_binary(),
    ),
    async_fifo_formal_observation(
      emitted,
      "write_binary_next",
      3,
      spec.write_binary_next(),
    ),
    async_fifo_formal_observation(emitted, "read_binary", 3, spec.read_binary()),
    async_fifo_formal_observation(
      emitted,
      "read_binary_next",
      3,
      spec.read_binary_next(),
    ),
    async_fifo_formal_observation(emitted, "write_gray", 3, spec.write_gray()),
    async_fifo_formal_observation(
      emitted,
      "write_gray_next",
      3,
      spec.write_gray_next(),
    ),
    async_fifo_formal_observation(emitted, "read_gray", 3, spec.read_gray()),
    async_fifo_formal_observation(
      emitted,
      "read_gray_next",
      3,
      spec.read_gray_next(),
    ),
    async_fifo_formal_observation(
      emitted,
      "read_gray_stage0",
      3,
      spec.read_gray_stages()[0],
    ),
    async_fifo_formal_observation(
      emitted,
      "read_gray_stage1",
      3,
      spec.read_gray_stages()[1],
    ),
    async_fifo_formal_observation(
      emitted,
      "write_gray_stage0",
      3,
      spec.write_gray_stages()[0],
    ),
    async_fifo_formal_observation(
      emitted,
      "write_gray_stage1",
      3,
      spec.write_gray_stages()[1],
    ),
    async_fifo_formal_observation(emitted, "full", 1, spec.full()),
    async_fifo_formal_observation(emitted, "full_next", 1, spec.full_next()),
    async_fifo_formal_observation(emitted, "nonempty", 1, spec.nonempty()),
    async_fifo_formal_observation(
      emitted,
      "nonempty_next",
      1,
      spec.nonempty_next(),
    ),
    async_fifo_formal_observation(
      emitted,
      "write_address",
      2,
      spec.write_address(),
    ),
    async_fifo_formal_observation(
      emitted,
      "read_address",
      2,
      spec.read_address(),
    ),
  ]
}

///|
/// Builds the isolated formal DUT without changing canonical production RTL.
///
/// The public FIFO builder handle does not expose its internal roles after the
/// module is finished, and the completed IR has no formal-only port-extension
/// operation. This adapter therefore binds typed emitted-node identities into
/// explicit ports using the emitter's deterministic text contract. Every
/// structural assumption is checked for exact uniqueness before returning;
/// emitter-format drift fails bundle generation instead of silently editing an
/// ambiguous location.
fn async_fifo_formal_dut(
  design : @ir.Design,
  emitted : @rtl.EmittedDesign,
  production_dut : @rtl.EmittedModule,
) -> AsyncFifoFormalDut raise FormalGateError {
  let observations = async_fifo_formal_observations(design, emitted)
  async_fifo_validate_formal_observations(observations)
  let ports = observations
    .map(observation => {
      "  output logic \{if observation.width == 1 { "" } else { "[\{observation.width - 1}:0] " }}\{observation.port}"
    })
    .join(",\n")
  let port_boundary = "\n);\n\n"
  let module_end = "endmodule\n\n`default_nettype wire"
  async_fifo_require_unique_marker(
    production_dut.source(),
    port_boundary,
    "port boundary",
  )
  async_fifo_require_unique_marker(production_dut.source(), module_end, "end")
  let source_with_ports = production_dut
    .source()
    .replace(old=port_boundary, new=",\n\{ports}\{port_boundary}")
  let assignments = observations
    .map(observation => "  assign \{observation.port} = \{observation.node};\n")
    .join("")
  let source = source_with_ports.replace(
    old=module_end,
    new="\{assignments}\{module_end}",
  )
  for index, observation in observations {
    let declaration = "  output logic \{if observation.width == 1 { "" } else { "[\{observation.width - 1}:0] " }}\{observation.port}"
    let declaration_suffix = if index + 1 == observations.length() {
      "\n);\n\n"
    } else {
      ",\n"
    }
    let delimited_declaration = declaration + declaration_suffix
    let assignment = "  assign \{observation.port} = \{observation.node};\n"
    if source.split(delimited_declaration).length() != 2 ||
      source.split(assignment).length() != 2 {
      raise InvalidAsyncFifoFormalBundle(
        "formal DUT observation port and assignment must each occur once",
      )
    }
  }
  {
    identifier: production_dut.identifier(),
    filename: production_dut.filename(),
    source,
    observations,
  }
}

///|
pub extend AsyncFifoFormalObservation with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend AsyncFifoFormalObservation with Eq::{not_equal, equal}

///|
pub extend AsyncFifoFormalDut with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AsyncFifoFormalDut with Eq::{not_equal, equal}

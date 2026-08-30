///|
fn is_one_bit_data(signal_type : SignalType) -> Bool {
  signal_type.is_data() && signal_type.width().bits() == 1
}

///|
fn node_uses(node : Node, requested : NodeId) -> Bool {
  match node.kind() {
    Input(_) | Constant(_) | MemoryRead(..) => false
    BitNot(value)
    | Slice(value~, ..)
    | ZeroExtend(value)
    | SignExtend(value)
    | Truncate(value)
    | Reinterpret(value) => value == requested
    Add(left, right)
    | Sub(left, right)
    | MulLow(left, right)
    | MulFull(left, right)
    | BitAnd(left, right)
    | BitOr(left, right)
    | BitXor(left, right)
    | Equal(left, right)
    | LessThan(left, right)
    | LessEqual(left, right)
    | ShiftLeft(value=left, amount=right)
    | LogicalShiftRight(value=left, amount=right)
    | ArithmeticShiftRight(value=left, amount=right)
    | Concat(most_significant=left, least_significant=right) =>
      left == requested || right == requested
    Mux(select~, when_true~, when_false~) =>
      select == requested || when_true == requested || when_false == requested
    Register(spec) => {
      let reset_uses = match spec.reset() {
        Some(reset) => reset.signal() == requested
        None => false
      }
      spec.next() == requested || spec.enable() == Some(requested) || reset_uses
    }
  }
}

///|
fn memory_use(memory : MemorySpec, requested : NodeId) -> String? {
  for port in memory.read_ports() {
    if port.address() == requested {
      return Some(
        "memory:\{memory.id().ordinal()}:read:\{port.id().ordinal()}:address",
      )
    }
    if port.enable() == Some(requested) {
      return Some(
        "memory:\{memory.id().ordinal()}:read:\{port.id().ordinal()}:enable",
      )
    }
  }
  for port in memory.write_ports() {
    if port.address() == requested {
      return Some(
        "memory:\{memory.id().ordinal()}:write:\{port.id().ordinal()}:address",
      )
    }
    if port.data() == requested {
      return Some(
        "memory:\{memory.id().ordinal()}:write:\{port.id().ordinal()}:data",
      )
    }
    if port.enable() == Some(requested) {
      return Some(
        "memory:\{memory.id().ordinal()}:write:\{port.id().ordinal()}:enable",
      )
    }
    match port.mask() {
      Granular(signal~, ..) if signal == requested =>
        return Some(
          "memory:\{memory.id().ordinal()}:write:\{port.id().ordinal()}:mask",
        )
      _ => ()
    }
  }
  None
}

///|
fn validate_intermediate_fanout(
  primitive : Int,
  stage : Int,
  requested : NodeId,
  allowed_consumer : NodeId,
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
  outputs : ArrayView[OutputPort],
) -> Unit raise IrError {
  for node in nodes {
    if node.id() != allowed_consumer && node_uses(node, requested) {
      raise CdcPrimitiveIntermediateFanout(
        primitive~,
        stage~,
        node=requested.ordinal(),
        consumer="node:\{node.id().ordinal()}",
      )
    }
  }
  for memory in memories {
    match memory_use(memory, requested) {
      Some(consumer) =>
        raise CdcPrimitiveIntermediateFanout(
          primitive~,
          stage~,
          node=requested.ordinal(),
          consumer~,
        )
      None => ()
    }
  }
  for output in outputs {
    if output.driver() == requested {
      raise CdcPrimitiveIntermediateFanout(
        primitive~,
        stage~,
        node=requested.ordinal(),
        consumer="output:\{output.name()}",
      )
    }
  }
}

///|
fn validate_bit_synchronizer(
  spec : BitSynchronizerPrimitive,
  domains : ArrayView[ClockDomain],
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
  outputs : ArrayView[OutputPort],
) -> Unit raise IrError {
  let primitive = spec.id().ordinal()
  guard nodes.get(spec.source().ordinal()) is Some(source) else {
    raise UnknownCdcPrimitiveSourceNode(
      primitive~,
      node=spec.source().ordinal(),
    )
  }
  if !is_one_bit_data(source.signal_type()) {
    raise InvalidCdcPrimitiveSourceType(
      primitive~,
      node=spec.source().ordinal(),
    )
  }
  let mut found_destination : ClockDomain? = None
  for domain in domains {
    if domain.id() == spec.destination() {
      found_destination = Some(domain)
    }
  }
  let destination = match found_destination {
    Some(domain) => domain
    None =>
      raise UnknownCdcPrimitiveDomain(
        primitive~,
        domain=spec.destination().ordinal(),
      )
  }
  match spec.source_domain() {
    AsynchronousSource => ()
    SourceDomain(source_domain) => {
      let mut source_exists = false
      for domain in domains {
        if domain.id() == source_domain {
          source_exists = true
        }
      }
      if !source_exists {
        raise UnknownCdcPrimitiveDomain(
          primitive~,
          domain=source_domain.ordinal(),
        )
      }
      if source_domain == destination.id() {
        raise EqualCdcPrimitiveDomains(
          primitive~,
          domain=source_domain.ordinal(),
        )
      }
    }
  }
  for index, stage_id in spec.stages() {
    guard nodes.get(stage_id.ordinal()) is Some(stage) else {
      raise UnknownCdcPrimitiveStageNode(
        primitive~,
        stage=index,
        node=stage_id.ordinal(),
      )
    }
    if !is_one_bit_data(stage.signal_type()) ||
      stage.signal_type() != source.signal_type() {
      raise InvalidCdcPrimitiveStageType(
        primitive~,
        stage=index,
        node=stage_id.ordinal(),
      )
    }
    guard stage.kind() is Register(register) else {
      raise InvalidCdcPrimitiveStageKind(
        primitive~,
        stage=index,
        node=stage_id.ordinal(),
      )
    }
    if register.domain().id() != destination.id() {
      raise CdcPrimitiveStageDomainMismatch(
        primitive~,
        stage=index,
        expected=destination.id().ordinal(),
        actual=register.domain().id().ordinal(),
      )
    }
    let expected_next = if index == 0 {
      spec.source()
    } else {
      spec.stages()[index - 1]
    }
    if register.next() != expected_next {
      raise CdcPrimitiveStageNextMismatch(
        primitive~,
        stage=index,
        expected=expected_next.ordinal(),
        actual=register.next().ordinal(),
      )
    }
    if register.enable() is Some(_) {
      raise CdcPrimitiveStageHasEnable(
        primitive~,
        stage=index,
        node=stage_id.ordinal(),
      )
    }
    if register.reset() != spec.reset() {
      raise CdcPrimitiveStageResetMismatch(
        primitive~,
        stage=index,
        node=stage_id.ordinal(),
      )
    }
    if index + 1 < spec.stages().length() {
      validate_intermediate_fanout(
        primitive,
        index,
        stage_id,
        spec.stages()[index + 1],
        nodes,
        memories,
        outputs,
      )
    }
  }
}

///|
fn validate_cdc_primitives(
  domains : ArrayView[ClockDomain],
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
  outputs : ArrayView[OutputPort],
  metadata : ModuleMetadata,
) -> Unit raise IrError {
  for primitive in metadata.cdc_primitives() {
    match primitive {
      BitSynchronizer(spec) =>
        validate_bit_synchronizer(spec, domains, nodes, memories, outputs)
    }
  }
}

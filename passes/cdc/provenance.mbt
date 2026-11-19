///|
fn witness(origin : CdcOrigin, node : @ir.NodeId) -> CdcWitness {
  { origin, path: ReadOnlyArray::from_array([node]), }
}

///|
fn origin_node(origin : CdcOrigin) -> @ir.NodeId {
  match origin {
    AsynchronousInput(node) => node
    TimedInput(input~, ..) => input
    RegisterState(node~, ..) => node
    MemoryReadState(node~, ..) => node
    AsyncFifoReadState(node~, ..) => node
  }
}

///|
fn origin_rank(origin : CdcOrigin) -> Int32 {
  match origin {
    AsynchronousInput(_) => 0
    TimedInput(..) => 1
    RegisterState(..) => 2
    MemoryReadState(..) => 3
    AsyncFifoReadState(..) => 4
  }
}

///|
fn origin_domain_ordinal(origin : CdcOrigin) -> Int32 {
  match origin {
    AsynchronousInput(_) => -1
    TimedInput(domain~, ..)
    | RegisterState(domain~, ..)
    | MemoryReadState(domain~, ..) => domain.ordinal()
    AsyncFifoReadState(domain~, ..) => domain.ordinal()
  }
}

///|
fn compare_witness(left : CdcWitness, right : CdcWitness) -> Int32 {
  let length_difference = left.path().length() - right.path().length()
  if length_difference != 0 {
    return length_difference
  }
  for index in 0..<left.path().length() {
    let difference = left.path()[index].ordinal() -
      right.path()[index].ordinal()
    if difference != 0 {
      return difference
    }
  }
  let node_difference = origin_node(left.origin()).ordinal() -
    origin_node(right.origin()).ordinal()
  if node_difference != 0 {
    return node_difference
  }
  let rank_difference = origin_rank(left.origin()) - origin_rank(right.origin())
  if rank_difference != 0 {
    return rank_difference
  }
  origin_domain_ordinal(left.origin()) - origin_domain_ordinal(right.origin())
}

///|
fn minimum_witness(left : CdcWitness, right : CdcWitness) -> CdcWitness {
  if compare_witness(left, right) <= 0 {
    left
  } else {
    right
  }
}

///|
fn extend_witness(current : CdcWitness, node : @ir.NodeId) -> CdcWitness {
  let path : Array[@ir.NodeId] = []
  for item in current.path() {
    path.push(item)
  }
  path.push(node)
  { origin: current.origin(), path: ReadOnlyArray::from_array(path), }
}

///|
fn neutral_analysis(node : @ir.NodeId) -> CdcNodeAnalysis {
  {
    node,
    provenance: {
      has_asynchronous: false,
      domains: ReadOnlyArray::from_array([]),
    },
    asynchronous_witness: None,
    domain_witnesses: ReadOnlyArray::from_array([]),
  }
}

///|
fn asynchronous_analysis(node : @ir.NodeId) -> CdcNodeAnalysis {
  {
    node,
    provenance: {
      has_asynchronous: true,
      domains: ReadOnlyArray::from_array([]),
    },
    asynchronous_witness: Some(witness(AsynchronousInput(node), node)),
    domain_witnesses: ReadOnlyArray::from_array([]),
  }
}

///|
fn domain_analysis(
  node : @ir.NodeId,
  domain : @ir.ClockDomainId,
  origin : CdcOrigin,
) -> CdcNodeAnalysis {
  let source = witness(origin, node)
  {
    node,
    provenance: {
      has_asynchronous: false,
      domains: ReadOnlyArray::from_array([domain]),
    },
    asynchronous_witness: None,
    domain_witnesses: ReadOnlyArray::from_array([{ domain, witness: source, }]),
  }
}

///|
fn merge_domain_witnesses(
  left : ReadOnlyArray[CdcDomainWitness],
  right : ReadOnlyArray[CdcDomainWitness],
) -> Array[CdcDomainWitness] {
  let merged : Array[CdcDomainWitness] = []
  let mut left_index = 0
  let mut right_index = 0
  while left_index < left.length() || right_index < right.length() {
    if left_index >= left.length() {
      merged.push(right[right_index])
      right_index += 1
    } else if right_index >= right.length() {
      merged.push(left[left_index])
      left_index += 1
    } else {
      let left_item = left[left_index]
      let right_item = right[right_index]
      let comparison = left_item.domain().ordinal() -
        right_item.domain().ordinal()
      if comparison < 0 {
        merged.push(left_item)
        left_index += 1
      } else if comparison > 0 {
        merged.push(right_item)
        right_index += 1
      } else {
        merged.push({
          domain: left_item.domain(),
          witness: minimum_witness(left_item.witness(), right_item.witness()),
        })
        left_index += 1
        right_index += 1
      }
    }
  }
  merged
}

///|
fn merge_analysis(
  left : CdcNodeAnalysis,
  right : CdcNodeAnalysis,
  node : @ir.NodeId,
) -> CdcNodeAnalysis {
  let asynchronous_witness = match
    (left.asynchronous_witness(), right.asynchronous_witness()) {
    (None, None) => None
    (Some(item), None) | (None, Some(item)) => Some(item)
    (Some(first), Some(second)) => Some(minimum_witness(first, second))
  }
  let domains = merge_domain_witnesses(
    left.domain_witnesses(),
    right.domain_witnesses(),
  )
  {
    node,
    provenance: {
      has_asynchronous: asynchronous_witness is Some(_),
      domains: ReadOnlyArray::from_array(domains.map(item => item.domain())),
    },
    asynchronous_witness,
    domain_witnesses: ReadOnlyArray::from_array(domains),
  }
}

///|
fn through_node(
  current : CdcNodeAnalysis,
  node : @ir.NodeId,
) -> CdcNodeAnalysis {
  let asynchronous_witness = match current.asynchronous_witness() {
    Some(item) => Some(extend_witness(item, node))
    None => None
  }
  let domains = current
    .domain_witnesses()
    .map(item => {
      domain: item.domain(),
      witness: extend_witness(item.witness(), node),
    })
  {
    node,
    provenance: current.provenance(),
    asynchronous_witness,
    domain_witnesses: ReadOnlyArray::from_array(domains),
  }
}

///|
fn node_analysis(
  nodes : Array[CdcNodeAnalysis],
  requested : @ir.NodeId,
) -> CdcNodeAnalysis {
  nodes[requested.ordinal()]
}

///|
fn combine_two(
  nodes : Array[CdcNodeAnalysis],
  node : @ir.NodeId,
  left : @ir.NodeId,
  right : @ir.NodeId,
) -> CdcNodeAnalysis {
  through_node(
    merge_analysis(
      node_analysis(nodes, left),
      node_analysis(nodes, right),
      node,
    ),
    node,
  )
}

///|
fn combine_three(
  nodes : Array[CdcNodeAnalysis],
  node : @ir.NodeId,
  first : @ir.NodeId,
  second : @ir.NodeId,
  third : @ir.NodeId,
) -> CdcNodeAnalysis {
  let first_two = merge_analysis(
    node_analysis(nodes, first),
    node_analysis(nodes, second),
    node,
  )
  through_node(
    merge_analysis(first_two, node_analysis(nodes, third), node),
    node,
  )
}

///|
fn explicit_input_timing(
  hardware_module : @ir.Module,
  id : @ir.NodeId,
) -> @ir.InputTiming? {
  for binding in hardware_module.input_timings() {
    if binding.input() == id {
      return Some(binding.timing())
    }
  }
  None
}

///|
fn memory_read_domain(
  hardware_module : @ir.Module,
  memory_id : @ir.MemoryId,
  port_id : @ir.MemoryReadPortId,
) -> @ir.ClockDomainId {
  for memory in hardware_module.memories() {
    if memory.id() == memory_id {
      for port in memory.read_ports() {
        if port.id() == port_id {
          return port.domain().id()
        }
      }
    }
  }
  abort("validated memory read port unexpectedly absent")
}

///|
fn fifo_read_domain(
  hardware_module : @ir.Module,
  primitive : @ir.CdcPrimitiveId,
) -> @ir.ClockDomainId {
  for declaration in hardware_module.cdc_primitives() {
    match declaration {
      AsyncFifo(spec) if spec.id() == primitive =>
        return spec.destination_domain()
      _ => ()
    }
  }
  abort("validated asynchronous FIFO read unexpectedly absent")
}

///|
fn ensure_timing_available(hardware_module : @ir.Module) -> Unit raise CdcError {
  if !hardware_module.metadata().declares_port_timing() &&
    hardware_module.domains().length() > 1 {
    raise TimingUnavailable(module_name=hardware_module.name())
  }
}

///|
/// Compute deterministic provenance and minimal witnesses for every current IR
/// node. Legacy zero-domain inputs are asynchronous; legacy single-domain inputs
/// belong to that sole domain. Legacy multi-domain timing is unavailable.
pub fn analyze_module(
  hardware_module : @ir.Module,
) -> CdcAnalysis raise CdcError {
  ensure_timing_available(hardware_module)
  let analyses : Array[CdcNodeAnalysis] = []
  let explicit = hardware_module.metadata().declares_port_timing()
  for node in hardware_module.nodes() {
    let current = match node.kind() {
      Input(_) =>
        if node.signal_type().is_clock() {
          neutral_analysis(node.id())
        } else if explicit {
          match explicit_input_timing(hardware_module, node.id()) {
            Some(Asynchronous) => asynchronous_analysis(node.id())
            Some(SampledIn(domain)) =>
              domain_analysis(
                node.id(),
                domain,
                TimedInput(input=node.id(), domain~),
              )
            None => raise TimingUnavailable(module_name=hardware_module.name())
          }
        } else if hardware_module.domains().is_empty() {
          asynchronous_analysis(node.id())
        } else {
          let domain = hardware_module.domains()[0].id()
          domain_analysis(
            node.id(),
            domain,
            TimedInput(input=node.id(), domain~),
          )
        }
      Constant(_) => neutral_analysis(node.id())
      BitNot(value)
      | Slice(value~, ..)
      | ZeroExtend(value)
      | SignExtend(value)
      | Truncate(value)
      | Reinterpret(value) =>
        through_node(node_analysis(analyses, value), node.id())
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
        combine_two(analyses, node.id(), left, right)
      Mux(select~, when_true~, when_false~) =>
        combine_three(analyses, node.id(), select, when_true, when_false)
      Register(spec) => {
        let domain = spec.domain().id()
        domain_analysis(
          node.id(),
          domain,
          RegisterState(node=node.id(), domain~),
        )
      }
      MemoryRead(memory~, port~) => {
        let domain = memory_read_domain(hardware_module, memory, port)
        domain_analysis(
          node.id(),
          domain,
          MemoryReadState(node=node.id(), memory~, port~, domain~),
        )
      }
      AsyncFifoRead(primitive~, leaf~) => {
        let domain = fifo_read_domain(hardware_module, primitive)
        domain_analysis(
          node.id(),
          domain,
          AsyncFifoReadState(node=node.id(), primitive~, leaf~, domain~),
        )
      }
    }
    analyses.push(current)
  }
  { nodes: ReadOnlyArray::from_array(analyses), }
}

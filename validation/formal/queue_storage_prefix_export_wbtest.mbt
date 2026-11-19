///|
// Independent manifest lookup: do not reuse the export adapter's naming helpers.
fn queue_storage_export_test_name(
  emitted : @rtl.EmittedDesign,
  kind : @rtl.SymbolKind,
  ordinal : Int32,
) -> String raise {
  guard emitted
    .manifest()
    .mappings()
    .filter(mapping => {
      mapping.kind() == kind &&
      mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
      mapping.local_ordinal() == ordinal
    })
    is [mapping] else {
    fail("nonunique original emitted identity")
  }
  mapping.identifier()
}

///|
fn queue_storage_export_test_type(signal_type : @ir.SignalType) -> String {
  let signed = if signal_type is SInt(_) { " signed" } else { "" }
  let width = signal_type.width().bits()
  "logic" + signed + (if width == 1 { "" } else { " [\{width - 1}:0]" })
}

///|
// Independently enumerate typed comparison helpers. Replace whole functions
// only; every byte outside these bodies, including arithmetic and address-
// knownness helpers, must stay identical to the production emitter artifact.
fn queue_storage_export_test_boolean(
  hardware : @ir.Module,
  source : String,
) -> String raise {
  let names : Array[String] = []
  let mut adapted = source
  for node in hardware.nodes() {
    let comparison = match node.kind() {
      Equal(left, _) => Some(("eq", left))
      LessThan(left, _) | LessEqual(left, _) => Some(("lt", left))
      _ => None
    }
    guard comparison is Some((operation, left)) else { continue }
    guard hardware.node(left) is Some(operand) else {
      fail("missing actual comparison operand")
    }
    let operation = if operation == "eq" {
      "eq"
    } else if operand.signal_type() is SInt(_) {
      "lt_s"
    } else {
      "lt_u"
    }
    let width = operand.signal_type().width().bits()
    let name = "lc_fn_\{operation}_w\{width}"
    if names.contains(name) {
      continue
    }
    names.push(name)
    let start = "  function automatic logic \{name}(\n"
    guard source.split(start).to_array() is [_, tail] else {
      fail("missing unique production comparison helper")
    }
    guard tail.split("  endfunction\n").to_array() is [body, _, ..] else {
      fail("unterminated comparison helper")
    }
    let original = start + body.to_owned() + "  endfunction\n"
    assert_eq(adapted.split(original).count(), 2)
    let expression = match operation {
      "eq" => "a == b"
      "lt_s" => "$signed(a) < $signed(b)"
      _ => "$unsigned(a) < $unsigned(b)"
    }
    let replacement = "  function automatic logic \{name}(\n    input logic [\{width - 1}:0] a,\n    input logic [\{width - 1}:0] b\n  );\n    begin\n      \{name} = \{expression};\n    end\n  endfunction\n"
    adapted = adapted.replace(old=original, new=replacement)
  }
  assert_true(names.length() > 0)
  adapted
}

///|
// Construct the complete canonical header and replacement independently, then
// split at the complete original body. Every byte of every production equation
// must precede the observer unchanged, not merely a selected equation subset.
fn queue_storage_export_test_observer(
  exported : QueueStoragePrefixExport,
  source : String,
) -> String raise {
  let sequential = exported.sequential
  guard exported.emitted
    .modules()
    .filter(emitted_module => {
      emitted_module.module_ordinal() ==
      exported.emitted.manifest().top_module_ordinal()
    })
    is [dut] else {
    fail("nonunique emitted top")
  }
  let lines : Array[String] = []
  let locals = StringBuilder()
  for node in sequential.hardware.nodes() {
    guard node.kind() is Input(name) else { continue }
    let identifier = queue_storage_export_test_name(
      exported.emitted,
      InputPort,
      node.id().ordinal(),
    )
    let signal_type = queue_storage_export_test_type(node.signal_type())
    lines.push("input \{signal_type} \{identifier}")
    if name == "clock" {
      locals.write_string(
        "  logic \{identifier} = 1'b0;\n  always @($global_clock) \{identifier} <= ~\{identifier};\n  wire lc_clock = \{identifier};\n",
      )
    } else {
      locals.write_string("  (* anyseq *) \{signal_type} \{identifier};\n")
    }
  }
  for ordinal, output in sequential.hardware.outputs() {
    let identifier = queue_storage_export_test_name(
      exported.emitted,
      OutputPort,
      ordinal,
    )
    let signal_type = queue_storage_export_test_type(output.signal_type())
    lines.push("output \{signal_type} \{identifier}")
    locals.write_string("  \{signal_type} \{identifier};\n")
  }
  assert_eq(lines.length(), 138)
  let ports = StringBuilder()
  for ordinal, line in lines {
    let comma = if ordinal + 1 == lines.length() { "" } else { "," }
    ports.write_string("  \{line}\{comma}\n")
  }
  let header = "module \{dut.identifier()} (\n" + ports.to_string() + ");\n\n"
  let replacement = "module \{dut.identifier()};\n" + locals.to_string() + "\n"
  let boolean = queue_storage_export_test_boolean(
    sequential.hardware,
    dut.source(),
  )
  assert_eq(exported.boolean_source, boolean)
  guard boolean.split(header).to_array() is [preamble, original_tail] else {
    fail("independently reconstructed header mismatch")
  }
  guard original_tail.split("endmodule\n").to_array() is [body, suffix] else {
    fail("noncanonical original body")
  }
  let prefix = preamble.to_owned() + replacement + body.to_owned()
  guard source.split(prefix).to_array() is ["", observed_tail] else {
    fail("production body changed during observer adaptation")
  }
  guard observed_tail.split("endmodule\n").to_array()
    is [observer, observed_suffix] else {
    fail("noncanonical observer suffix")
  }
  assert_eq(observed_suffix, suffix)
  assert_eq(
    source,
    preamble.to_owned() +
    replacement +
    body.to_owned() +
    observer.to_owned() +
    "endmodule\n" +
    suffix.to_owned(),
  )
  observer.to_owned()
}

///|
test "FIFO prefix export independently preserves complete production RTL and typed free boundaries" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let before = @ir_codec.serialize(
    @ir.Design::single(
      "QueuedConcurrentQueueConservationPilot",
      fixture.hardware(),
    ),
  )
  let exported = queue_storage_prefix_export(fixture)
  let repeated = queue_storage_prefix_export(fixture)
  assert_eq(exported.positive, repeated.positive)
  assert_eq(exported.negative, repeated.negative)
  assert_eq(exported.emitted, repeated.emitted)
  assert_eq(exported.boolean_source, repeated.boolean_source)
  assert_eq(exported.properties, repeated.properties)
  assert_eq(exported.memory_identifiers, repeated.memory_identifiers)
  assert_eq(exported.memory_bounds, repeated.memory_bounds)
  assert_eq(exported.global_assertions, ["lc_storage_nonrising_hold"])
  assert_eq(
    exported.sequential.hardware,
    queue_storage_sequential(fixture).hardware,
  )
  assert_eq(
    exported.emitted,
    @rtl.emit_design(
      @ir.Design::single("QueueStorageSequential", exported.sequential.hardware),
    ),
  )
  assert_eq(
    @ir_codec.serialize(
      @ir.Design::single(
        "QueuedConcurrentQueueConservationPilot",
        fixture.hardware(),
      ),
    ),
    before,
  )
  assert_eq(
    exported.positive,
    queue_storage_prefix_source(fixture, exported.sequential, exported.emitted),
  )
  assert_eq(
    exported.negative,
    queue_storage_prefix_source(
      fixture,
      exported.sequential,
      exported.emitted,
      negative=true,
    ),
  )
  let positive_observer = queue_storage_export_test_observer(
    exported,
    exported.positive,
  )
  let negative_observer = queue_storage_export_test_observer(
    exported,
    exported.negative,
  )
  assert_eq(positive_observer.split("(* anyseq *)").count(), 2)
  assert_eq(negative_observer.split("(* anyseq *)").count(), 2)
  assert_eq(exported.positive.split("(* anyseq *)").count(), 61)
  assert_eq(exported.negative.split("(* anyseq *)").count(), 61)
  assert_eq(exported.sequential.cuts.length(), 59)
  assert_eq(
    exported.sequential.cuts
    .iter()
    .fold(init=0, (bits, cut) => bits + cut.signal_type.width().bits()),
    805,
  )
  for cut in exported.sequential.cuts {
    let mapped_node = queue_storage_test_node(
      exported.sequential.original_to_local,
      cut.node,
    )
    let name = queue_storage_export_test_name(
      exported.emitted,
      InputPort,
      mapped_node.ordinal(),
    )
    let declaration = "  (* anyseq *) \{queue_storage_export_test_type(cut.signal_type)} \{name};\n"
    assert_eq(exported.positive.split(declaration).count(), 2)
    assert_eq(exported.negative.split(declaration).count(), 2)
    assert_false(positive_observer.contains(declaration))
    assert_false(negative_observer.contains(declaration))
  }
  assert_false(exported.positive.contains(".dut."))
  assert_false(exported.positive.contains("dut["))
  assert_false(exported.positive.contains("initial begin"))
  assert_false(exported.emitted.source().contains("initial "))
  assert_true(
    exported.emitted
    .source()
    .contains(
      "Memory cells and read results intentionally have no initializer.",
    ),
  )
  assert_eq(
    exported.emitted.manifest().initialization_policy(),
    ImplicitFourStateXRejectExplicitInitial,
  )
}

///|
test "FIFO prefix export rejects source reset mapping and production emitter drift" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let exported = queue_storage_prefix_export(fixture)
  let sequential = exported.sequential
  let mapping = sequential.original_to_local.iter().to_array()
  mapping[sequential.probe.reset.ordinal()] = mapping[sequential.probe.clock.ordinal()]
  let invalid : QueueStorageSequential = {
    ..sequential,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
  try queue_storage_prefix_source(fixture, invalid, exported.emitted) catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong original reset inventory rejection")
  } noraise {
    _ => fail("remapped reset accepted")
  }
  let cuts = sequential.cuts.filter(cut => cut.node != sequential.probe.reset)
  let missing_reset : QueueStorageSequential = {
    ..sequential,
    cuts: ReadOnlyArray::from_array(cuts),
  }
  try
    queue_storage_prefix_source(fixture, missing_reset, exported.emitted)
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong missing original reset rejection")
  } noraise {
    _ => fail("omitted reset cut accepted")
  }
  let changed_probe : QueueStorageProbe = {
    ..sequential.probe,
    reset: sequential.probe.clock,
  }
  let changed_source : QueueStorageSequential = {
    ..sequential,
    probe: changed_probe,
  }
  try
    queue_storage_prefix_source(fixture, changed_source, exported.emitted)
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong source reset reference rejection")
  } noraise {
    _ => fail("changed original reset reference accepted")
  }
  let wrong_hardware = @ir.Module::checked_with_memories(
    "WrongQueueStorageSequential",
    sequential.hardware.nodes(),
    sequential.hardware.memories(),
    sequential.hardware.outputs(),
  )
  let wrong_emitter = @rtl.emit_design(
    @ir.Design::single("QueueStorageSequential", wrong_hardware),
  )
  try queue_storage_prefix_source(fixture, sequential, wrong_emitter) catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong emitter identity rejection")
  } noraise {
    _ => fail("different production emitter accepted")
  }
  let nodes = sequential.hardware.nodes().iter().to_array()
  let root = nodes[queue_storage_test_node(
      sequential.original_to_local,
      sequential.probe.roots[0].node,
    ).ordinal()]
  guard root.kind() is Register(spec) && spec.reset() is Some(reset) else {
    fail("missing actual root reset")
  }
  let changed_reset = @ir.ResetSpec::explicit(
    reset.signal(),
    1UL,
    reset.mode(),
    reset.polarity(),
  )
  let changed_spec = @ir.RegisterSpec::new(
    spec.domain(),
    spec.next(),
    reset=changed_reset,
  )
  assert_eq(reset.value(), 0UL)
  nodes[root.id().ordinal()] = @ir.Node::new(
    root.id(),
    root.signal_type(),
    Register(changed_spec),
  )
  let changed_hardware = @ir.Module::checked_with_memories(
    sequential.hardware.name(),
    nodes,
    sequential.hardware.memories(),
    sequential.hardware.outputs(),
  )
  let changed_sequential : QueueStorageSequential = {
    ..sequential,
    hardware: changed_hardware,
  }
  let changed_emitter = @rtl.emit_design(
    @ir.Design::single("QueueStorageSequential", changed_hardware),
  )
  try
    queue_storage_prefix_source(fixture, changed_sequential, changed_emitter)
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong jointly changed reset/emitter rejection")
  } noraise {
    _ => fail("changed reset equation with matching emitter accepted")
  }
  let wrong_memory_map = sequential.original_to_local_memory.iter().to_array()
  wrong_memory_map[sequential.probe.lanes[0].memory.id().ordinal()] = None
  let missing_memory : QueueStorageSequential = {
    ..sequential,
    original_to_local_memory: ReadOnlyArray::from_array(wrong_memory_map),
  }
  try
    queue_storage_prefix_source(fixture, missing_memory, exported.emitted)
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong memory identity rejection")
  } noraise {
    _ => fail("missing actual memory mapping accepted")
  }
}

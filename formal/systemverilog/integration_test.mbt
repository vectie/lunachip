///|
fn property_signal(name : String) -> @property.PropertySignal raise {
  @property.PropertySignal::named("Top", name)
}

///|
fn auxiliary_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("Auxiliary")
  let input = builder.input("input", @wire.bits(1))
  let output = builder.output("output", @wire.bits(1))
  builder.connect(output, input)
  builder.finish()
}

///|
fn top_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("Top")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let predicate = builder.input("predicate", @wire.bits(1))
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let state = builder.register_state_in(domain, @wire.bits(1), reset~)
  builder.connect_next(state, predicate)
  let output = builder.output("state", @wire.bits(1))
  builder.connect(output, state.value())
  builder.finish()
}

///|
fn fixture_design() -> @ir.Design raise {
  @ir.Design::checked(
    "formal-integration",
    [auxiliary_module(), top_module()],
    "Top",
  )
}

///|
fn semantically_different_top_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("Top")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let predicate = builder.input("predicate", @wire.bits(1))
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let state = builder.register_state_in(domain, @wire.bits(1), reset~)
  builder.connect_next(state, builder.bit_not(predicate))
  let output = builder.output("state", @wire.bits(1))
  builder.connect(output, state.value())
  builder.finish()
}

///|
fn semantically_different_design() -> @ir.Design raise {
  @ir.Design::checked(
    "formal-integration",
    [auxiliary_module(), semantically_different_top_module()],
    "Top",
  )
}

///|
fn fixture_plan() -> @formal.FormalPropertyPlan raise {
  let clock = property_signal("clock")
  let reset = property_signal("reset")
  let domain = @formal.ObservationDomain::rising_pre_edge(clock)
  let disable = @formal.DisableBehavior::when_known_high_asynchronous(reset)
  @formal.FormalPropertyPlan::checked([
    @formal.FormalProperty::checked(
      @property.PropertyId::new(1),
      "node_assertion",
      Assertion,
      @property.PropertySignal::node("Top", @ir.NodeId::new(2)),
      domain,
      disable,
    ),
    @formal.FormalProperty::assumption(
      @property.PropertyId::new(0),
      "input_assumption",
      property_signal("predicate"),
      domain,
      disable,
    ),
    @formal.FormalProperty::checked(
      @property.PropertyId::new(2),
      "output_cover",
      Cover,
      property_signal("state"),
      domain,
      NeverDisabled,
    ),
  ])
}

///|
test "integration rejects emitted RTL from a shape-compatible different design" {
  let design = fixture_design()
  let wrong_emission = @rtl.emit_design(semantically_different_design())
  let path = @systemverilog.TopModulePath::checked(design, "Top")
  try
    @systemverilog.integrate(design, wrong_emission, path, fixture_plan())
  catch {
    @systemverilog.IntegrationError::EmittedDesignMismatch => ()
    _ => fail("expected exact emitted-design identity rejection")
  } noraise {
    _ => fail("expected exact emitted-design identity rejection")
  }
}

///|
test "bindings come only from exact top manifest identities" {
  let design = fixture_design()
  let emitted = @rtl.emit_design(design)
  let path = @systemverilog.TopModulePath::checked(design, "Top")
  let bindings = @systemverilog.derive_bindings(
    design,
    emitted,
    path,
    fixture_plan(),
  )
  assert_eq(bindings.length(), 5)
  assert_eq(bindings[0].signal(), property_signal("clock"))
  assert_eq(bindings[0].identifier(), "lc_i0_b63_b6c_b6f_b63_b6b")
  assert_eq(bindings[1].signal(), property_signal("predicate"))
  assert_eq(
    bindings[1].identifier(),
    "lc_i2_b70_b72_b65_b64_b69_b63_b61_b74_b65",
  )
  assert_eq(bindings[2].signal(), property_signal("reset"))
  assert_eq(bindings[2].identifier(), "lc_i1_b72_b65_b73_b65_b74")
  assert_eq(bindings[3].identifier(), "lc_n2")
  assert_eq(bindings[4].signal(), property_signal("state"))
  assert_eq(bindings[4].identifier(), "lc_o0_b73_b74_b61_b74_b65")
}

///|
test "integration preserves non-top bytes and content-addresses formalized RTL" {
  let design = fixture_design()
  let emitted = @rtl.emit_design(design)
  let path = @systemverilog.TopModulePath::checked(design, "Top")
  let first = @systemverilog.integrate(design, emitted, path, fixture_plan())
  let second = @systemverilog.integrate(design, emitted, path, fixture_plan())
  assert_eq(first, second)
  assert_eq(first.top_module_ordinal(), 1)
  assert_eq(first.modules().length(), 2)
  assert_eq(first.modules()[0].source(), emitted.modules()[0].source())
  assert_eq(first.modules()[0].sha256().length(), 64)
  assert_eq(first.top_module().sha256().length(), 64)
  assert_eq(first.top_artifact().name(), first.top_module().filename())
  assert_eq(first.top_artifact().sha256(), first.top_module().sha256())
  assert_true(first.top_module().source().contains("assume property"))
  assert_true(first.top_module().source().contains("assert property"))
  assert_true(first.top_module().source().contains("cover property"))
  guard first.top_module().source().split_once("`ifdef FORMAL")
    is Some((_, after_formal)) &&
    after_formal.split_once("endmodule") is Some(_) else {
    fail("formal source must precede the exact endmodule")
  }
  assert_true(
    first
    .source_set_identity()
    .has_prefix("LUNACHIP-FORMAL-SYSTEMVERILOG-SOURCE-SET 1\n"),
  )
  assert_true(first.source_set_identity().contains("PROPERTY-MANIFEST sha256"))
  assert_true(first.source_set_identity().contains("NAME-MANIFEST sha256"))
  assert_true(first.source_set_identity().contains("CANONICAL-IR sha256"))
  assert_eq(first.source_set_sha256().length(), 64)
  assert_eq(
    first.top_module().sha256(),
    "a6f56b6b45938424144d7d4155bbbed42c4ac23dbf00aaaa1dbe69b3a26d3df5",
  )
  assert_eq(
    first.source_set_sha256(),
    "a0b28f99d6c3864f4b7409e8cc951c7b83c9fcb2b60c8b3f110a42e7299c349a",
  )
  let set_artifact = first.source_set_artifact("rtl/formal-source-set.lcsv")
  assert_eq(set_artifact.sha256(), first.source_set_sha256())
}

///|
test "clock and predicate roles are type checked against canonical IR" {
  let design = fixture_design()
  let emitted = @rtl.emit_design(design)
  let path = @systemverilog.TopModulePath::checked(design, "Top")
  let bad_clock = property_signal("predicate")
  let bad_domain = @formal.ObservationDomain::rising_pre_edge(bad_clock)
  let bad_clock_plan = @formal.FormalPropertyPlan::checked([
    @formal.FormalProperty::checked(
      @property.PropertyId::new(0),
      "bad_clock",
      Assertion,
      property_signal("state"),
      bad_domain,
      NeverDisabled,
    ),
  ])
  try
    @systemverilog.derive_bindings(design, emitted, path, bad_clock_plan)
  catch {
    ExpectedClockSignal(actual) => assert_eq(actual, bad_clock)
    _ => fail("expected clock type rejection")
  } noraise {
    _ => fail("expected clock type rejection")
  }
  let clock = property_signal("clock")
  let domain = @formal.ObservationDomain::rising_pre_edge(clock)
  let clock_predicate_plan = @formal.FormalPropertyPlan::checked([
    @formal.FormalProperty::checked(
      @property.PropertyId::new(0),
      "clock_is_not_data",
      Assertion,
      clock,
      domain,
      NeverDisabled,
    ),
  ])
  try
    @systemverilog.derive_bindings(design, emitted, path, clock_predicate_plan)
  catch {
    ExpectedOneBitSignal(role="predicate", signal=actual) =>
      assert_eq(actual, clock)
    _ => fail("expected predicate type rejection")
  } noraise {
    _ => fail("expected predicate type rejection")
  }
}

///|
test "exact top path and signal path mismatches fail closed" {
  let design = fixture_design()
  try @systemverilog.TopModulePath::checked(design, "top") catch {
    TopModulePathMismatch(expected="Top", actual="top") => ()
    _ => fail("expected exact top-path rejection")
  } noraise {
    _ => fail("expected exact top-path rejection")
  }
  let emitted = @rtl.emit_design(design)
  let path = @systemverilog.TopModulePath::checked(design, "Top")
  let clock = property_signal("clock")
  let domain = @formal.ObservationDomain::rising_pre_edge(clock)
  let wrong_path_plan = @formal.FormalPropertyPlan::checked([
    @formal.FormalProperty::checked(
      @property.PropertyId::new(0),
      "wrong_path",
      Assertion,
      @property.PropertySignal::named("Other", "predicate"),
      domain,
      NeverDisabled,
    ),
  ])
  try
    @systemverilog.derive_bindings(design, emitted, path, wrong_path_plan)
  catch {
    SignalOutsideTopModulePath(expected="Top", actual="Other") => ()
    _ => fail("expected property path rejection")
  } noraise {
    _ => fail("expected property path rejection")
  }
}

///|
test "missing names and unknown nodes are rejected without name synthesis" {
  let design = fixture_design()
  let emitted = @rtl.emit_design(design)
  let path = @systemverilog.TopModulePath::checked(design, "Top")
  let domain = @formal.ObservationDomain::rising_pre_edge(
    property_signal("clock"),
  )
  let missing = @formal.FormalPropertyPlan::checked([
    @formal.FormalProperty::checked(
      @property.PropertyId::new(0),
      "missing",
      Assertion,
      property_signal("does_not_exist"),
      domain,
      NeverDisabled,
    ),
  ])
  try @systemverilog.derive_bindings(design, emitted, path, missing) catch {
    MissingNamedSignal(path="Top", name="does_not_exist") => ()
    _ => fail("expected missing named signal rejection")
  } noraise {
    _ => fail("expected missing named signal rejection")
  }
  let unknown = @formal.FormalPropertyPlan::checked([
    @formal.FormalProperty::checked(
      @property.PropertyId::new(0),
      "unknown_node",
      Assertion,
      @property.PropertySignal::node("Top", @ir.NodeId::new(99)),
      domain,
      NeverDisabled,
    ),
  ])
  try @systemverilog.derive_bindings(design, emitted, path, unknown) catch {
    UnknownTopNode(99) => ()
    _ => fail("expected unknown node rejection")
  } noraise {
    _ => fail("expected unknown node rejection")
  }
}

///|
fn ambiguous_design() -> @ir.Design raise {
  let builder = @wire.ModuleBuilder::new("Ambiguous")
  let clock = builder.input("clock", @wire.clock())
  let same = builder.input("same", @wire.bits(1))
  let domain = builder.rising_edge(clock)
  let state = builder.register_state_in(domain, @wire.bits(1))
  builder.connect_next(state, same)
  let output = builder.output("same", @wire.bits(1))
  builder.connect(output, state.value())
  @ir.Design::single("ambiguous", builder.finish())
}

///|
test "same-named top input and output are an explicit ambiguity" {
  let design = ambiguous_design()
  let emitted = @rtl.emit_design(design)
  let path = @systemverilog.TopModulePath::checked(design, "Ambiguous")
  let clock = @property.PropertySignal::named("Ambiguous", "clock")
  let domain = @formal.ObservationDomain::rising_pre_edge(clock)
  let plan = @formal.FormalPropertyPlan::checked([
    @formal.FormalProperty::checked(
      @property.PropertyId::new(0),
      "ambiguous",
      Assertion,
      @property.PropertySignal::named("Ambiguous", "same"),
      domain,
      NeverDisabled,
    ),
  ])
  try @systemverilog.derive_bindings(design, emitted, path, plan) catch {
    AmbiguousNamedSignal(path="Ambiguous", name="same", matches=2) => ()
    _ => fail("expected named signal ambiguity")
  } noraise {
    _ => fail("expected named signal ambiguity")
  }
}

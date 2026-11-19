///|
fn dependency_boolean_test_module() -> @ir.Module raise {
  let nodes : Array[@ir.Node] = []
  let outputs : Array[@ir.OutputPort] = []
  for width in [1, 3, 8] {
    let u : @ir.SignalType = UInt(@ir.Width::new(width))
    let s : @ir.SignalType = SInt(@ir.Width::new(width))
    let bit : @ir.SignalType = Bits(@ir.Width::new(1))
    let first = nodes.length()
    let a = @ir.NodeId::new(first)
    let b = @ir.NodeId::new(first + 1)
    let sa = @ir.NodeId::new(first + 2)
    let sb = @ir.NodeId::new(first + 3)
    nodes.push(@ir.Node::new(a, u, Input("a_u\{width}")))
    nodes.push(@ir.Node::new(b, u, Input("b_u\{width}")))
    nodes.push(@ir.Node::new(sa, s, Input("a_s\{width}")))
    nodes.push(@ir.Node::new(sb, s, Input("b_s\{width}")))
    let comparisons : Array[@ir.NodeKind] = [
      Equal(a, b),
      Equal(sa, sb),
      LessThan(a, b),
      LessEqual(a, b),
      LessThan(sa, sb),
      LessEqual(sa, sb),
    ]
    for index, kind in comparisons {
      let id = @ir.NodeId::new(nodes.length())
      nodes.push(@ir.Node::new(id, bit, kind))
      outputs.push(@ir.OutputPort::new("compare_\{width}_\{index}", bit, id))
    }
    let add = @ir.NodeId::new(nodes.length())
    nodes.push(@ir.Node::new(add, u, Add(a, b)))
    outputs.push(@ir.OutputPort::new("sum_\{width}", u, add))
  }
  @ir.Module::checked("BooleanHelperCandidate", nodes, outputs)
}

///|
fn dependency_boolean_test_source(hardware : @ir.Module) -> String raise {
  @rtl.emit_design(@ir.Design::single("BooleanHelperCandidate", hardware)).modules()[0].source()
}

///|
test "dependency Boolean adaptation preserves every non-helper byte on the exact q3 graph" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let hardware = fixture.hardware()
  let production = @rtl.emit_design(
    @ir.Design::single("QueuedConcurrentDependencyPilot", hardware),
  ).modules()[0].source()
  let (adapted, plans) = dependency_boolean_helpers(hardware, production)
  assert_eq(plans.length(), 19)
  assert_eq(
    plans.filter(plan => plan.function_name.has_prefix("lc_fn_eq_")).length(),
    12,
  )
  assert_eq(
    plans.filter(plan => plan.function_name.has_prefix("lc_fn_lt_u_")).length(),
    7,
  )
  assert_false(plans.any(plan => plan.function_name.has_prefix("lc_fn_lt_s_")))
  let mut restored = adapted
  for plan in plans {
    restored = restored.replace(old=plan.replacement, new=plan.original)
  }
  assert_eq(restored, production)
  // Real state and invalid-memory X choices are not comparison helpers.
  assert_true(adapted.contains("'bx"))
  assert_eq(
    adapted.split("always_ff @").count(),
    production.split("always_ff @").count(),
  )
  assert_eq(
    adapted.split("/* verilator lint_off UNUSEDSIGNAL */").count(),
    production.split("/* verilator lint_off UNUSEDSIGNAL */").count(),
  )
  assert_eq(hardware.memories().length(), 10)
  assert_eq(fixture.observations().length(), 48)
}

///|
fn dependency_boolean_expect_failure(
  hardware : @ir.Module,
  source : String,
) -> Unit raise {
  try dependency_boolean_helper_plans(hardware, source) catch {
    InvalidFormalBundleIdentity(_) => ()
    error => fail("unexpected Boolean helper rejection: \{Repr(error)}")
  } noraise {
    _ => fail("comparison helper extraction drift was accepted")
  }
}

///|
test "dependency Boolean plans select exact typed widths and signed comparison helpers" {
  let hardware = dependency_boolean_test_module()
  let source = dependency_boolean_test_source(hardware)
  let (replaced, plans) = dependency_boolean_helpers(hardware, source)
  assert_eq(plans.map(plan => plan.function_name), [
    "lc_fn_eq_w1", "lc_fn_lt_u_w1", "lc_fn_lt_s_w1", "lc_fn_eq_w3", "lc_fn_lt_u_w3",
    "lc_fn_lt_s_w3", "lc_fn_eq_w8", "lc_fn_lt_u_w8", "lc_fn_lt_s_w8",
  ])
  assert_eq(dependency_apply_boolean_helper_plans(source, plans), replaced)
  for plan in plans {
    assert_eq(source.split(plan.original).count(), 2)
    assert_eq(replaced.split(plan.replacement).count(), 2)
    assert_true(plan.original.contains("1'bx"))
    assert_false(plan.replacement.contains("1'bx"))
    assert_false(plan.replacement.contains("case ("))
    assert_eq(
      dependency_boolean_extract_helper(source, plan.function_name),
      plan.original,
    )
    assert_eq(
      dependency_boolean_extract_helper(replaced, plan.function_name),
      plan.replacement,
    )
    let expected_expression = if plan.function_name.has_prefix("lc_fn_lt_s_") {
      "$signed(a) < $signed(b)"
    } else if plan.function_name.has_prefix("lc_fn_eq_") {
      "a == b"
    } else {
      "$unsigned(a) < $unsigned(b)"
    }
    assert_true(plan.replacement.contains(" = " + expected_expression + ";"))
  }
  // Reverse exactly the selected blocks: every other source byte, including
  // ports, node assignments and add helpers, must be identical to production.
  let mut restored = replaced
  for plan in plans {
    restored = restored.replace(old=plan.replacement, new=plan.original)
  }
  assert_eq(restored, source)
  assert_eq(replaced.split("function automatic logic ").count(), 13)
  assert_eq(replaced.split("function automatic logic [").count(), 4)
  assert_true(
    replaced.contains(
      "carry = (a[i] & b[i]) | (a[i] & carry) | (b[i] & carry);",
    ),
  )
  assert_false(replaced.contains("1'bx"))
}

///|
test "dependency Boolean helper candidate rejects missing duplicate and changed scalar blocks" {
  let hardware = dependency_boolean_test_module()
  let source = dependency_boolean_test_source(hardware)
  let plans = dependency_boolean_helper_plans(hardware, source)
  let first = plans[0]
  dependency_boolean_expect_failure(
    hardware,
    source.replace(old=first.original, new=""),
  )
  dependency_boolean_expect_failure(hardware, source + first.original)
  dependency_boolean_expect_failure(
    hardware,
    source.replace(old="    logic mismatch;", new="    logic mismatch_drift;"),
  )
  dependency_boolean_expect_failure(
    hardware,
    source.replace(old="  endfunction\n", new="  endfunction_drift\n"),
  )
  dependency_boolean_expect_failure(
    hardware,
    source.replace(
      old="function automatic logic lc_fn_eq_w1(",
      new="function automatic logic [0:0] lc_fn_eq_w1(",
    ),
  )
  try
    dependency_apply_boolean_helper_plans(source + first.original, plans)
  catch {
    InvalidFormalBundleIdentity(_) => ()
    error => fail("unexpected application rejection: \{Repr(error)}")
  } noraise {
    _ => fail("duplicate application marker was accepted")
  }
}

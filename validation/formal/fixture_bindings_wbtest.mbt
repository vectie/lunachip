///|
fn binding_test_unbounded_task(
  properties : ReadOnlyArray[String],
) -> GateTask raise {
  let name = "selection-test-prove"
  let proof = @formal_core.UnboundedProofTask::checked(
    name,
    checked_artifact("source-set.lcfs", sha256_hex("selection test source")),
    formal_tool(),
    "smtbmc-bitwuzla",
    @formal_core.InductionMethod::k_induction(12),
    ["a0", "a1", "a2", "a3"],
    properties,
  )
  {
    name,
    task: Unbounded(proof),
    task_class: UnboundedSafetyTask,
    bound: 12,
    timeout_seconds: 600,
    expected_status: "pass",
  }
}

///|
test "unbounded binding defaults to the exact three or seven assertion set" {
  let scopes : ReadOnlyArray[ReadOnlyArray[String]] = [
    ["p0", "p1", "p2"],
    ["p0", "p1", "p2", "p3", "p4", "p5", "p6"],
  ]
  for scope in scopes {
    validate_task_bindings(
      [binding_test_unbounded_task(scope)],
      ["a0", "a1", "a2", "a3"],
      scope,
      [],
    )
  }
}

///|
test "unbounded binding rejects truncated and extra assertion selections" {
  let scope : ReadOnlyArray[String] = ["p0", "p1", "p2", "p3", "p4", "p5", "p6"]
  let invalid : ReadOnlyArray[ReadOnlyArray[String]] = [
    ["p0", "p1", "p2", "p3"],
    ["p0", "p1", "p2", "p3", "p4", "p5"],
    ["p0", "p1", "p2", "p3", "p4", "p5", "p6", "extra"],
  ]
  for selected in invalid {
    let task = binding_test_unbounded_task(selected)
    try
      validate_task_bindings([task], ["a0", "a1", "a2", "a3"], scope, [])
    catch {
      TaskPropertyBindingMismatch(name) => assert_eq(name, task.name())
      _ => fail("unexpected task-binding error")
    } noraise {
      _ => fail("unbounded task must select exactly the owning safety scope")
    }
  }
}

///|
test "explicit induction scope is exact and limited to declared assertions" {
  let scope : ReadOnlyArray[String] = ["p0", "p1", "p2", "p3", "p4"]
  let selected : ReadOnlyArray[String] = ["p0", "p1", "p2", "p3"]
  let task = binding_test_unbounded_task(selected)
  validate_task_bindings(
    [task],
    ["a0", "a1", "a2", "a3"],
    scope,
    [],
    selected_unbounded=selected,
  )
  let invalid : ReadOnlyArray[ReadOnlyArray[String]] = [
    [],
    ["p0", "p1", "p2"],
    ["p0", "p1", "p2", "p3", "p4"],
    ["p0", "p1", "p2", "unknown"],
    ["p0", "p1", "p2", "p2"],
  ]
  for expected in invalid {
    try
      validate_task_bindings(
        [task],
        ["a0", "a1", "a2", "a3"],
        scope,
        [],
        selected_unbounded=expected,
      )
    catch {
      TaskPropertyBindingMismatch(name) => assert_eq(name, task.name())
      _ => fail("unexpected explicit-selection error")
    } noraise {
      _ => fail("explicit induction scope must be nonempty, unique and exact")
    }
  }
  // A declared task cannot make an unknown policy valid by matching it.
  let unknown : ReadOnlyArray[String] = ["p0", "p1", "p2", "unknown"]
  try
    validate_task_bindings(
      [binding_test_unbounded_task(unknown)],
      ["a0", "a1", "a2", "a3"],
      scope,
      [],
      selected_unbounded=unknown,
    )
  catch {
    TaskPropertyBindingMismatch(_) => ()
    _ => fail("unexpected undeclared-assertion error")
  } noraise {
    _ => fail("explicit induction scope cannot introduce a new assertion")
  }
}

///|
test "FIFO retains explicit four-property induction and five-property BMC" {
  let bundle = generate_fifo_bundle(ValidFifo)
  guard bundle.tasks() is [bounded, unbounded, cover] else {
    fail("FIFO task inventory changed")
  }
  guard bounded.task() is Bounded(bmc) else { fail("missing FIFO BMC") }
  guard unbounded.task() is Unbounded(prove) else {
    fail("missing FIFO induction")
  }
  assert_eq(bmc.properties().length(), 5)
  assert_eq(prove.properties().length(), 4)
  assert_eq(
    prove.properties(),
    ReadOnlyArray::from_array(bmc.properties()[0:4].to_owned()),
  )
  assert_eq(cover.task_class(), BoundedCoverTask)
  assert_eq(prove.induction(), @formal_core.InductionMethod::k_induction(12))
}

///|
fn named(
  name : String,
) -> @property.PropertySignal raise @property.PropertyError {
  @property.PropertySignal::named("top", name)
}

///|
fn assertion(
  id : Int,
  name : String,
  signal : @property.PropertySignal,
) -> @property.PropertySpec raise @property.PropertyError {
  @property.PropertySpec::checked(
    @property.PropertyId::new(id),
    name,
    Assertion,
    signal,
  )
}

///|
fn cover(
  id : Int,
  name : String,
  signal : @property.PropertySignal,
) -> @property.PropertySpec raise @property.PropertyError {
  @property.PropertySpec::checked(
    @property.PropertyId::new(id),
    name,
    Cover,
    signal,
  )
}

///|
fn sample(
  signal : @property.PropertySignal,
  value : @semantics.LogicValue,
) -> @property.PropertySample raise @property.PropertyError {
  @property.PropertySample::new(signal, value)
}

///|
test "assertions produce deterministic cycle-stamped pass and false failure" {
  let ready = named("ready")
  let valid = named("valid")
  let plan = @property.PropertyPlan::checked([
    assertion(9, "valid_is_high", valid),
    assertion(2, "ready_is_high", ready),
  ])
  let observations = plan.evaluate(17, 4, PreEdge, [
    sample(valid, @semantics.LogicValue::zero(width=1)),
    sample(ready, @semantics.LogicValue::one(width=1)),
  ])
  assert_eq(observations.length(), 2)
  assert_eq(observations[0].property_id().ordinal(), 2)
  assert_eq(observations[0].cycle(), 17UL)
  assert_eq(observations[0].boundary(), 4UL)
  assert_eq(observations[0].point(), PreEdge)
  assert_eq(observations[0].outcome(), AssertionPass)
  match observations[1].outcome() {
    AssertionFail(failure) => {
      assert_eq(failure.code(), "LC2001")
      assert_eq(failure.reason(), PredicateFalse)
      assert_eq(failure.actual().to_bit_string(), "0")
    }
    outcome => fail("expected assertion failure, got \{Repr(outcome)}")
  }
}

///|
test "unknown assertions fail closed with stable machine-readable data" {
  let signal = @property.PropertySignal::node(
    "top.pipeline",
    @ir.NodeId::new(12),
  )
  let plan = @property.PropertyPlan::checked([
    assertion(3, "stage_valid_known", signal),
  ])
  let observations = plan.evaluate(8, 1, PostEdge, [
    sample(signal, @semantics.LogicValue::unknown(width=1)),
  ])
  match observations[0].outcome() {
    AssertionFail(failure) => {
      assert_eq(failure.code(), "LC2002")
      assert_eq(failure.reason(), PredicateUnknown)
      assert_eq(failure.actual().to_bit_string(), "x")
      assert_eq(observations[0].predicate(), signal)
      assert_eq(observations[0].point(), PostEdge)
    }
    outcome => fail("expected unknown assertion failure, got \{Repr(outcome)}")
  }
}

///|
test "cover distinguishes hit, known miss, and unknown" {
  let hit = named("hit")
  let miss = named("miss")
  let unknown = named("unknown")
  let plan = @property.PropertyPlan::checked([
    cover(0, "hit_cover", hit),
    cover(1, "miss_cover", miss),
    cover(2, "unknown_cover", unknown),
  ])
  let observations = plan.evaluate(21, 0, PostEdge, [
    sample(unknown, @semantics.LogicValue::unknown(width=1)),
    sample(hit, @semantics.LogicValue::one(width=1)),
    sample(miss, @semantics.LogicValue::zero(width=1)),
  ])
  assert_eq(observations[0].outcome(), CoverHit)
  assert_eq(observations[1].outcome(), CoverMiss)
  assert_eq(observations[2].outcome(), CoverUnknown)
}

///|
test "property evaluation rejects malformed plans and samples" {
  let signal = named("predicate")
  let valid_id = @property.PropertyId::new(4)
  try
    @property.PropertySpec::checked(
      valid_id,
      "bad_signal",
      Assertion,
      Named(path="", name="predicate"),
    )
  catch {
    EmptySignalPath => ()
    error => fail("unexpected invalid-signal error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid signal rejection")
  }
  try
    @property.PropertyPlan::checked([
      assertion(0, "same", signal),
      cover(0, "other", signal),
    ])
  catch {
    DuplicatePropertyId(0) => ()
    error => fail("unexpected duplicate-id error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate property ID rejection")
  }
  let plan = @property.PropertyPlan::checked([
    assertion(0, "predicate_is_high", signal),
  ])
  let duplicate_samples = [
    sample(signal, @semantics.LogicValue::zero(width=1)),
    sample(signal, @semantics.LogicValue::zero(width=1)),
  ]
  try plan.evaluate(0, 0, PreEdge, duplicate_samples) catch {
    DuplicateSample(found) => assert_eq(found, signal)
    error => fail("unexpected duplicate-sample error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate sample rejection")
  }
  let wide_sample = [sample(signal, @semantics.LogicValue::zero(width=2))]
  try plan.evaluate(0, 0, PreEdge, wide_sample) catch {
    PredicateWidthMismatch(property_id=0, expected=1, actual=2) => ()
    error => fail("unexpected width error: \{Repr(error)}")
  } noraise {
    _ => fail("expected predicate width rejection")
  }
  try plan.evaluate(0, 0, PreEdge, []) catch {
    MissingSample(found) => assert_eq(found, signal)
    error => fail("unexpected missing-sample error: \{Repr(error)}")
  } noraise {
    _ => fail("expected missing sample rejection")
  }
}

///|
test "Vec snapshots input and checks empty and bounds" {
  let source = [10, 20, 30]
  let vector = @aggregate.Vec::checked(source)
  source[0] = 99
  assert_eq(vector.length(), 3)
  assert_eq(vector.at(0), 10)
  assert_eq(vector.at(2), 30)
  assert_eq(vector.items(), [10, 20, 30])
  for index in [-1, 3] {
    try vector.at(index) catch {
      VecIndexOutOfBounds(index=actual, length~) => {
        assert_eq(actual, index)
        assert_eq(length, 3)
      }
      error => fail("unexpected bounds error: \{Repr(error)}")
    } noraise {
      _ => fail("expected bounds rejection")
    }
  }
  try {
    let _ : @aggregate.Vec[Int] = @aggregate.Vec::checked([])
  } catch {
    EmptyVec => ()
    error => fail("unexpected empty Vec error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty Vec rejection")
  }
}

///|
test "Bundle snapshots declaration order and validates names" {
  let source = [("alpha", 1), ("数据", 2), ("omega", 3)]
  let bundle = @aggregate.Bundle::checked(source)
  source[0] = ("changed", 99)
  assert_eq(bundle.length(), 3)
  assert_eq(bundle.fields().map(field => field.name()), [
    "alpha", "数据", "omega",
  ])
  assert_eq(bundle.fields().map(field => field.value()), [1, 2, 3])
  assert_eq(bundle.field("数据").map(field => field.value()), Some(2))
  assert_eq(bundle.field("missing"), None)
  try {
    let _ : @aggregate.Bundle[Int] = @aggregate.Bundle::checked([])
  } catch {
    EmptyBundle => ()
    error => fail("unexpected empty Bundle error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty Bundle rejection")
  }
  try @aggregate.Bundle::checked([("", 1)]) catch {
    EmptyFieldName => ()
    error => fail("unexpected field-name error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty field-name rejection")
  }
  try @aggregate.Bundle::checked([("same", 1), ("same", 2)]) catch {
    DuplicateFieldName(name) => assert_eq(name, "same")
    error => fail("unexpected duplicate-field error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate field rejection")
  }
}

///|
fn nested_template() -> @aggregate.Aggregate[Int] raise {
  @aggregate.Aggregate::record([
    ("header🔥", @aggregate.Aggregate::leaf(10)),
    (
      "lanes",
      @aggregate.Aggregate::vector([
        @aggregate.Aggregate::record([
          ("valid", @aggregate.Aggregate::leaf(20)),
          ("payload", @aggregate.Aggregate::leaf(21)),
        ]),
        @aggregate.Aggregate::record([
          ("valid", @aggregate.Aggregate::leaf(30)),
          ("payload", @aggregate.Aggregate::leaf(31)),
        ]),
      ]),
    ),
  ])
}

///|
test "nested aggregate flattening has stable ordinals paths and values" {
  let aggregate = nested_template()
  assert_eq(aggregate.leaf_count(), 5)
  let leaves = aggregate.flatten()
  assert_eq(leaves.map(leaf => leaf.ordinal()), [0, 1, 2, 3, 4])
  assert_eq(leaves.map(leaf => leaf.value()), [10, 20, 21, 30, 31])
  assert_eq(leaves[0].path().segments(), [Field("header🔥")])
  assert_eq(leaves[1].path().segments(), [
    Field("lanes"),
    Index(0),
    Field("valid"),
  ])
  assert_eq(leaves[2].path().segments(), [
    Field("lanes"),
    Index(0),
    Field("payload"),
  ])
  assert_eq(leaves[3].path().segments(), [
    Field("lanes"),
    Index(1),
    Field("valid"),
  ])
  assert_eq(leaves[4].path().segments(), [
    Field("lanes"),
    Index(1),
    Field("payload"),
  ])
}

///|
test "exact reconstruction preserves topology names paths and new values" {
  let template = nested_template()
  let rebuilt = template.reconstruct_like(["h", "v0", "p0", "v1", "p1"])
  assert_eq(rebuilt.leaf_count(), template.leaf_count())
  let original_paths = template.flatten().map(leaf => leaf.path())
  let rebuilt_leaves = rebuilt.flatten()
  assert_eq(rebuilt_leaves.map(leaf => leaf.path()), original_paths)
  assert_eq(rebuilt_leaves.map(leaf => leaf.value()), [
    "h", "v0", "p0", "v1", "p1",
  ])
  assert_eq(
    rebuilt,
    @aggregate.Aggregate::record([
      ("header🔥", @aggregate.Aggregate::leaf("h")),
      (
        "lanes",
        @aggregate.Aggregate::vector([
          @aggregate.Aggregate::record([
            ("valid", @aggregate.Aggregate::leaf("v0")),
            ("payload", @aggregate.Aggregate::leaf("p0")),
          ]),
          @aggregate.Aggregate::record([
            ("valid", @aggregate.Aggregate::leaf("v1")),
            ("payload", @aggregate.Aggregate::leaf("p1")),
          ]),
        ]),
      ),
    ]),
  )
}

///|
test "reconstruction rejects missing and trailing leaves exactly" {
  let template = nested_template()
  for actual in [0, 4, 6, 9] {
    let values = Array::make(actual, 0)
    try template.reconstruct_like(values) catch {
      LeafCountMismatch(expected~, actual=seen) => {
        assert_eq(expected, 5)
        assert_eq(seen, actual)
      }
      error => fail("unexpected leaf-count error: \{Repr(error)}")
    } noraise {
      _ => fail("expected exact leaf-count rejection")
    }
  }
}

///|
test "a ground aggregate flattens and reconstructs at the root path" {
  let ground = @aggregate.Aggregate::leaf(7)
  let leaves = ground.flatten()
  assert_eq(leaves.length(), 1)
  assert_true(leaves[0].path().is_root())
  assert_eq(leaves[0].path(), @aggregate.AggregatePath::root())
  assert_eq(
    ground.reconstruct_like(["replacement"]),
    @aggregate.Aggregate::leaf("replacement"),
  )
}

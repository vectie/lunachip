///|
fn direct8_engine_completed_prefix_native(
  read : (String) -> UInt64 raise,
) -> Unit raise {
  let state = read("q_engine_state_0")
  if state < 1UL || state > 3UL {
    return
  }
  let row = read("t_reader_row")
  let column = read("t_reader_column")
  let columns = read("t_reader_columns")
  let operand = read("o_load_operand")
  let slot = read("o_load_slot").to_int()
  for bank in 0..<8 {
    if operand == 0UL && bank.to_uint64() < row {
      direct8_fair_require(
        read("p_a_\{slot}_\{bank}") >= columns,
        "d8e_completed_prefix",
      )
    } else if operand == 1UL && bank.to_uint64() < columns {
      let required = row + (if bank.to_uint64() < column { 1UL } else { 0UL })
      direct8_fair_require(
        read("p_b_\{slot}_\{bank}") >= required,
        "d8e_completed_prefix",
      )
    }
  }
}

///|
fn direct8_b_prefix_complete(
  row : Int32,
  column : Int32,
  columns : Int32,
  prefixes : Array[Int32],
) -> Bool {
  for bank in 0..<columns {
    if prefixes[bank] < row + (if bank < column { 1 } else { 0 }) {
      return false
    }
  }
  true
}

///|
test "B selected prefix alone is not closed at row wrap but completed column carry is" {
  // Abstract induction-start example, NOT a reachable production trace.
  let missing = Array::make(8, 0)
  assert_true(0 <= missing[7])
  assert_false(direct8_b_prefix_complete(0, 7, 8, missing))
  missing[7] = 1
  assert_false(1 <= missing[0])
  // Check the exact prefix extension and row/column recurrence, including
  // previously longer reload prefixes, for every supported B rectangle.
  for rows in 1..<=16 {
    for columns in 1..<=8 {
      for row in 0..<rows {
        for column in 0..<columns {
          for extra in 0..<=2 {
            let prefixes = Array::makei(8, bank => {
              let minimum = row + (if bank < column { 1 } else { 0 })
              if minimum + extra > 16 {
                16
              } else {
                minimum + extra
              }
            })
            assert_true(
              direct8_b_prefix_complete(row, column, columns, prefixes),
            )
            assert_true(row <= prefixes[column])
            if row == prefixes[column] {
              prefixes[column] += 1
            }
            let next_column = if column + 1 == columns { 0 } else { column + 1 }
            let next_row = row + (if column + 1 == columns { 1 } else { 0 })
            if next_row < rows {
              assert_true(
                direct8_b_prefix_complete(
                  next_row, next_column, columns, prefixes,
                ),
              )
            }
          }
        }
      }
    }
  }
}

///|
test "completed prefix task adds one conclusion and preserves both earlier engine attempts" {
  let parent : Direct8CompletionBundle = {
    artifacts: generate_direct8_arbiter_artifacts(
      engine_progress=true,
      owner_support=true,
    ),
  }
  for
    (path, expected) in [
      (
        "formal-dut.sv", "c83c43cff4e6d508bdc7f26eae17710e9eeda75fb2de1730a4c798645381b735",
      ),
      (
        "source-set.lcfs", "164c3a46e99cac9f8b865bc31c0e4ddcbbd45db2da42465a6b7895abfd435d64",
      ),
      (
        "properties.lcfp", "60b95a630d7fcb3b7cc4868e61156c3c215359b19697cf7dec306ed8b3fb7f9c",
      ),
    ] {
    assert_eq(
      sha256_hex(direct8_completion_test_artifact(parent, path)),
      expected,
    )
  }
  let bundle : Direct8CompletionBundle = {
    artifacts: generate_direct8_arbiter_artifacts(
      engine_progress=true,
      owner_support=true,
      completed_prefix=true,
    ),
  }
  let before = @formal_core.parse_formal_property_manifest(
    direct8_completion_test_artifact(parent, "properties.lcfp"),
  )
  let after = @formal_core.parse_formal_property_manifest(
    direct8_completion_test_artifact(bundle, "properties.lcfp"),
  )
  assert_eq(after.properties().length(), 51)
  for index, property in before.properties() {
    assert_eq(after.properties()[index], property)
  }
  let task_name = direct8_engine_prefix_id + "-prove"
  guard @formal_core.parse_proof_task(
      direct8_completion_test_artifact(bundle, task_name + ".lcft"),
    )
    is Unbounded(task) else {
    fail("unbounded prefix task required")
  }
  assert_eq((task.assumptions().length(), task.properties().length()), (7, 44))
  assert_eq(task.induction(), @formal_core.InductionMethod::k_induction(32))
  assert_eq(
    regenerate_formal_artifacts(
      direct8_completion_test_artifact(bundle, "source-set.lcfs"),
    ),
    bundle.artifacts,
  )
  let source = direct8_engine_completed_prefix_source()
  assert_false(source.contains("assume"))
  assert_false(source.contains("anyseq"))
  assert_true(source.contains("13'd7 < lc_g_t_reader_column"))
  assert_true(source.contains("lc_g_t_reader_row +"))
  assert_eq(
    direct8_engine_property_names(owner_support=true, completed_prefix=true).length(),
    22,
  )
}

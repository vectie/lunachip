///|
test "dependency generation factorization preserves the exact original sequential ghost and prefix bytes" {
  // Before factorization at a97e14b, stripping each original #| marker and
  // printing its content recorded these digests. The full literal has one
  // fewer trailing newline than that diagnostic rendering; the prefix stops
  // before the ownership comment and includes its separating blank line.
  let ghost = dependency_ghost_source()
  let prefix = dependency_generation_reference_source()
  assert_eq(
    sha256_hex(ghost + "\n"),
    "7233ce8d74f074dec19f7d2f3aa7439e128583c2e083c50dd459d8c780d83454",
  )
  assert_eq(
    sha256_hex(prefix),
    "97d1452277c2dad54c0561cfe3818028a4da7b2a551a02fbfa58cc252c7b9b7c",
  )
  let boundary = "  // Ghost engine ownership comes from actual outer accept events, never\n"
  guard ghost.split(boundary).to_array() is [before, tail] else {
    fail("ownership boundary is missing or repeated")
  }
  assert_eq(before.to_owned(), prefix)
  assert_true(tail.contains("lc_g_load_owned"))
  assert_true(tail.contains("lc_g_authorized_reduction"))
  assert_false(prefix.contains("lc_g_load_owned"))
  assert_false(prefix.contains("lc_g_authorized"))
  assert_eq(ghost, prefix + boundary + tail.to_owned())
}

///|
test "dependency generation combinational reference shares real updates with free PRE and separate POST" {
  let comb = dependency_generation_comb_reference_source()
  assert_true(comb.contains(dependency_generation_predicates_source()))
  assert_true(
    comb.contains(
      dependency_generation_writer_reset_source("lc_g_post_", "=", false),
    ),
  )
  assert_true(
    comb.contains(
      dependency_generation_writer_update_source(
        "lc_g_", "lc_g_post_", "=", false,
      ),
    ),
  )
  assert_true(
    comb.contains(
      dependency_generation_snapshot_reset_source("lc_g_post_", "=", false),
    ),
  )
  assert_true(
    comb.contains(
      dependency_generation_snapshot_update_source(
        "lc_g_", "lc_g_post_", "=", false,
      ),
    ),
  )
  for
    forbidden in [
      "always_ff", "lc_clock", "<=", "lc_g_had_success", "lc_g_failed_after_success",
      "lc_priority_", "lc_bad_syntax_", "lc_g_load_owned", "lc_g_authorized", "logic [31:0] lc_g_next",
      "logic [31:0] lc_g_head", "assume (", "assert (",
    ] {
    assert_false(comb.contains(forbidden))
  }
  for line in comb.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("lc_g_post_") {
      guard trimmed.split(" = ").to_array() is [_, rhs] else {
        fail("POST write is not a blocking assignment")
      }
      assert_false(rhs.contains("lc_g_post_"))
    }
  }
  assert_true(
    comb.contains("lc_g_post_status[lc_slot] = lc_g_status[lc_slot];"),
  )
  assert_true(
    comb.contains("lc_g_post_ticket[lc_slot] = lc_g_ticket[lc_slot];"),
  )
  assert_true(comb.contains("lc_g_post_next = lc_g_next;"))
  assert_true(comb.contains("lc_g_post_head = lc_g_head;"))
  for index in 0..<2 {
    assert_true(
      comb.contains(
        "lc_g_post_snapshot_status[\{index}] = lc_g_snapshot_status[\{index}];",
      ),
    )
    assert_true(
      comb.contains(
        "lc_g_post_snapshot_ticket[\{index}] = lc_g_snapshot_ticket[\{index}];",
      ),
    )
  }
}

///|
test "dependency generation shared fragments preserve PRE snapshots matching tickets and last-intent priority" {
  let updates = dependency_generation_writer_update_source(
    "sentinel_pre_", "sentinel_post_", "=", false,
  )
  guard updates.split("if (lc_g_collect[lc_slot])").to_array()
    is [_, after_collect] else {
    fail("collect priority changed")
  }
  guard after_collect.split("if (lc_g_local_fail[lc_slot])").to_array()
    is [_, after_failure] else {
    fail("failure priority changed")
  }
  guard after_failure.split("if (lc_g_intent[lc_slot])").to_array()
    is [_, after_intent] else {
    fail("intent priority changed")
  }
  assert_true(
    after_intent.contains("sentinel_post_ticket[lc_slot] = sentinel_pre_next;"),
  )
  assert_false(after_intent.contains("sentinel_post_next"))
  let snapshots = dependency_generation_snapshot_update_source(
    "sentinel_pre_", "sentinel_post_", "=", false,
  )
  assert_true(snapshots.contains("sentinel_post_head = sentinel_pre_next;"))
  assert_true(
    snapshots.contains("sentinel_post_next = sentinel_pre_next + 32'd1;"),
  )
  for index in 0..<2 {
    assert_true(
      snapshots.contains(
        "sentinel_post_snapshot_status[\{index}] = sentinel_pre_status[lc_raw_source\{index}];",
      ),
    )
    assert_true(
      snapshots.contains(
        "sentinel_post_snapshot_ticket[\{index}] = sentinel_pre_ticket[lc_raw_source\{index}];",
      ),
    )
  }
  let predicates = dependency_generation_predicates_source()
  assert_true(predicates.contains("lc_g_snapshot_status[0] == 2'd1"))
  assert_true(predicates.contains("terminal_ticket == lc_g_ticket[lc_slot]"))
  assert_true(
    predicates.contains(
      "&& lc_g_expected_reject && lc_raw_syntax_ok && lc_raw_is_writer",
    ),
  )
  assert_false(predicates.contains("lc_o_local_reject"))
  assert_false(predicates.contains("lc_o_local_fault"))
  assert_false(predicates.contains("lc_g_post_"))
}

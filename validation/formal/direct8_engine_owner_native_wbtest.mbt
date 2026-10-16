///|
fn direct8_engine_owner_native(read : (String) -> UInt64 raise) -> Unit raise {
  let yes = name => read(name) == 1UL
  let compute = read("q_engine_state_1")
  let leased = yes("x_lease")
  let owned = yes("x_ownership")
  direct8_fair_require(
    (!leased || compute == 1UL || compute == 2UL) && (compute != 1UL || leased),
    "d8e_lease_phase",
  )
  if owned {
    direct8_fair_require(
      compute == 2UL &&
      leased &&
      ["a", "b", "c"].all(name => {
        read("o_active_" + name) == read("o_compute_" + name)
      }),
      "d8e_inner_snapshot",
    )
  }
  let loading = read("q_engine_state_0") >= 1UL &&
    read("q_engine_state_0") <= 3UL
  let storing = read("q_engine_state_2") >= 1UL &&
    read("q_engine_state_2") <= 3UL
  let operand = read("o_load_operand")
  let load_slot = read("o_load_slot")
  direct8_fair_require(
    !loading ||
    !leased ||
    load_slot !=
    read(if operand == 0UL { "o_compute_a" } else { "o_compute_b" }),
    "d8e_loader_lease",
  )
  direct8_fair_require(
    !storing || !leased || read("o_store_slot") != read("o_compute_c"),
    "d8e_store_lease",
  )
  let state = read("q_engine_state_2")
  direct8_fair_require(
    (!yes("o_pending") || state == 2UL || state == 3UL || state == 4UL) &&
    (state != 2UL || yes("o_pending")),
    "d8e_pending_owner",
  )
  for name in ["a", "b"] {
    for slot in 0..<2 {
      for bank in 0..<8 {
        let prefix = read("p_\{name}_\{slot}_\{bank}")
        direct8_fair_require(prefix <= 16UL, "d8e_prefix_bounds")
        if loading &&
          load_slot == slot.to_uint64() &&
          operand == (if name == "a" { 0UL } else { 1UL }) {
          let lane = read(
            if name == "a" {
              "t_reader_row"
            } else {
              "t_reader_column"
            },
          )
          let index = read(
            if name == "a" {
              "t_reader_column"
            } else {
              "t_reader_row"
            },
          )
          direct8_fair_require(
            read(if name == "a" { "t_reader_rows" } else { "t_reader_columns" }) <=
            8UL,
            "d8e_loader_prefix",
          )
          if lane == bank.to_uint64() {
            direct8_fair_require(index <= prefix, "d8e_loader_prefix")
          }
        }
      }
    }
  }
  direct8_engine_completed_prefix_native(read)
}

///|
test "direct8 engine supports reject orphan pending selector conflict and missing prefix" {
  for
    (frame, expected) in [
      ({ "o_pending": 1UL }, "d8e_pending_owner"),
      (
        {
          "x_ownership": 1UL,
          "x_lease": 1UL,
          "q_engine_state_1": 2UL,
          "o_active_c": 1UL,
        },
        "d8e_inner_snapshot",
      ),
      (
        { "x_lease": 1UL, "q_engine_state_1": 2UL, "q_engine_state_0": 1UL },
        "d8e_loader_lease",
      ),
      (
        {
          "q_engine_state_0": 1UL,
          "t_reader_rows": 8UL,
          "t_reader_column": 1UL,
        },
        "d8e_loader_prefix",
      ),
    ] {
    try
      direct8_engine_owner_native(name => frame.get(name).unwrap_or(0UL))
    catch {
      BadFairEdge(label) => assert_eq(label, expected)
      error => fail("unexpected support error: \{error}")
    } noraise {
      _ => fail("invalid pending/lease/prefix state must fail")
    }
  }
}

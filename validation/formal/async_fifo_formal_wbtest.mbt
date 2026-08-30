///|
test "asynchronous FIFO formal DUT has exact explicit observation boundary" {
  let built = async_fifo_formal_design()
  let emitted = @rtl.emit_design(built.design)
  let production = top_emitted_module(emitted)
  assert_eq(production.source().split("\n);\n\n").length(), 2)
  assert_eq(
    production.source().split("endmodule\n\n`default_nettype wire").length(),
    2,
  )
  let formal = async_fifo_formal_dut(built.design, emitted, production) catch {
    InvalidAsyncFifoFormalBundle(message) => fail(message)
    _ => fail("unexpected formal DUT error")
  }
  assert_false(production.source().contains("lc_formal_observe_"))
  let expected : Array[(String, Int)] = [
    ("source_transfer", 1),
    ("destination_transfer", 1),
    ("write_binary", 3),
    ("write_binary_next", 3),
    ("read_binary", 3),
    ("read_binary_next", 3),
    ("write_gray", 3),
    ("write_gray_next", 3),
    ("read_gray", 3),
    ("read_gray_next", 3),
    ("read_gray_stage0", 3),
    ("read_gray_stage1", 3),
    ("write_gray_stage0", 3),
    ("write_gray_stage1", 3),
    ("full", 1),
    ("full_next", 1),
    ("nonempty", 1),
    ("nonempty_next", 1),
    ("write_address", 2),
    ("read_address", 2),
  ]
  assert_eq(
    formal.observations.map(observation => (observation.role, observation.width)),
    expected,
  )
  for index, observation in formal.observations {
    let range = if observation.width == 1 {
      ""
    } else {
      "[\{observation.width - 1}:0] "
    }
    let declaration_suffix = if index + 1 == formal.observations.length() {
      "\n);\n\n"
    } else {
      ",\n"
    }
    let declaration = "output logic \{range}\{observation.port}" +
      declaration_suffix
    assert_eq(formal.source.split(declaration).length(), 2)
    assert_eq(
      formal.source
      .split("assign \{observation.port} = \{observation.node};")
      .length(),
      2,
    )
  }
  for invalid in ["no marker", "xMARKxMARKx"] {
    try
      async_fifo_require_unique_marker(invalid, "MARK", "test boundary")
    catch {
      InvalidAsyncFifoFormalBundle(_) => ()
      _ => fail("unexpected marker validation error")
    } noraise {
      _ => fail("missing or repeated formal splice marker must fail closed")
    }
  }
}

///|
test "asynchronous FIFO formal DUT rejects incomplete or duplicate roles" {
  let built = async_fifo_formal_design()
  let emitted = @rtl.emit_design(built.design)
  let observations = async_fifo_formal_observations(built.design, emitted)
  let missing : Array[AsyncFifoFormalObservation] = []
  try async_fifo_validate_formal_observations(missing) catch {
    InvalidAsyncFifoFormalBundle(_) => ()
    _ => fail("unexpected incomplete-observation error")
  } noraise {
    _ => fail("incomplete formal observation inventory must fail closed")
  }
  let duplicate = observations.map(observation => observation)
  duplicate[1] = duplicate[0]
  try async_fifo_validate_formal_observations(duplicate) catch {
    InvalidAsyncFifoFormalBundle(_) => ()
    _ => fail("unexpected duplicate-observation error")
  } noraise {
    _ => fail("duplicate formal observation inventory must fail closed")
  }
}

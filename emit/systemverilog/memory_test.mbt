///|
fn emitted_memory_design(
  policy : @ir.MemoryReadWritePolicy,
  masked : Bool,
) -> @ir.Design raise {
  let builder = @wire.ModuleBuilder::new("MemoryTop")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let read_address = builder.input("read_address", @wire.uint(2))
  let write_address = builder.input("write_address", @wire.uint(2))
  let data = builder.input("data", @wire.uint(8))
  let write_enable = builder.input("write_enable", @wire.bits(1))
  let read_enable = builder.input("read_enable", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "mémoire",
    @wire.uint(8),
    3,
    domain,
    read_write_policy=policy,
    multi_write_policy=LowerPortIdWins,
    bounds_policy=Fault,
  )
  if masked {
    let mask = builder.input("mask", @wire.bits(4))
    builder.memory_write_masked(
      memory,
      "write",
      write_address,
      data,
      mask,
      2,
      enable=write_enable,
    )
  } else {
    builder.memory_write(
      memory,
      "write",
      write_address,
      data,
      enable=write_enable,
    )
  }
  let result = builder.memory_read(
    memory,
    "read",
    read_address,
    enable=read_enable,
  )
  let output = builder.output("result", @wire.uint(8))
  builder.connect(output, result)
  @wire.single_design("MemoryDesign", builder.finish())
}

///|
test "memory emission is deterministic and carries manifest identity" {
  let design = emitted_memory_design(ReadNew, true)
  let first = @systemverilog.emit_design(design)
  let second = @systemverilog.emit_design(design)
  assert_eq(first, second)
  let source = first.modules()[0].source()
  assert_true(
    source.contains("// LunaChip conservative SystemVerilog-2017 backend v2"),
  )
  assert_false(source.contains("backend v3"))
  assert_false(source.contains("FIFO lane cells"))
  assert_true(
    source.contains("logic [7:0] lc_a0_b6d_bc3_ba9_b6d_b6f_b69_b72_b65 [0:2];"),
  )
  assert_false(source.contains("always_comb begin"))
  assert_true(source.contains("always_ff @(posedge lc_n0) begin"))
  assert_true(source.contains("lc_n6[3] ? lc_n3[7:6]"))
  assert_true(source.contains("lc_ak0(lc_n1)"))
  assert_true(source.contains("lc_ak0 = ((^lc_address) !== 1'bx);"))
  assert_true(source.contains("$unsigned(lc_n1) < 2'd3"))
  assert_true(source.contains("=== 1'b1"))
  let manifest = first.manifest().to_canonical_text()
  assert_true(manifest.has_prefix("LUNACHIP-SYSTEMVERILOG-NAMES 2\nTOP 0\n"))
  assert_false(manifest.contains("ASYNC-FIFO-INITIALIZATION"))
  assert_true(
    manifest.contains("MEMORY-INITIALIZATION implicit-four-state-x\n"),
  )
  assert_true(
    manifest.contains(
      "MAP memory 0 0 6d_c3_a9_6d_6f_69_72_65 lc_a0_b6d_bc3_ba9_b6d_b6f_b69_b72_b65\n",
    ),
  )
  assert_false(source.contains("__"))
}

///|
test "each supported read/write policy has an explicit lowering" {
  let old = @systemverilog.emit_design(emitted_memory_design(ReadOld, false)).modules()[0].source()
  let new = @systemverilog.emit_design(emitted_memory_design(ReadNew, false)).modules()[0].source()
  let no_change = @systemverilog.emit_design(
    emitted_memory_design(NoChange, false),
  ).modules()[0].source()
  let undefined = @systemverilog.emit_design(
    emitted_memory_design(Undefined, false),
  ).modules()[0].source()
  assert_true(old.contains("lc_a0_b6d_bc3_ba9_b6d_b6f_b69_b72_b65[lc_n1]"))
  assert_true(new.contains("((lc_n2 == lc_n1) === 1'b1)"))
  assert_true(no_change.contains("? lc_n6 : lc_a0"))
  assert_true(undefined.contains("? 8'bx : lc_a0"))
}

///|
test "memory-free backend and name-manifest versions remain unchanged" {
  let builder = @wire.ModuleBuilder::new("Plain")
  let input = builder.input("input", @wire.uint(8))
  let output = builder.output("output", @wire.uint(8))
  builder.connect(output, input)
  let emitted = @systemverilog.emit_design(
    @wire.single_design("PlainDesign", builder.finish()),
  )
  assert_true(
    emitted.modules()[0]
    .source()
    .contains("// LunaChip conservative SystemVerilog-2017 backend v1"),
  )
  assert_true(
    emitted
    .manifest()
    .to_canonical_text()
    .has_prefix("LUNACHIP-SYSTEMVERILOG-NAMES 1\n"),
  )
  assert_false(emitted.source().contains("backend v2"))
  assert_false(emitted.source().contains("backend v3"))
  assert_false(
    emitted
    .manifest()
    .to_canonical_text()
    .contains("INITIALIZATION implicit-four-state-x\n"),
  )
}

///|
test "fault bounds and rejected dynamic write collisions fail closed" {
  let builder = @wire.ModuleBuilder::new("RejectedCollision")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let address_a = builder.input("address_a", @wire.uint(2))
  let address_b = builder.input("address_b", @wire.uint(2))
  let data_a = builder.input("data_a", @wire.uint(8))
  let data_b = builder.input("data_b", @wire.uint(8))
  let enable_a = builder.input("enable_a", @wire.bits(1))
  let enable_b = builder.input("enable_b", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "memory",
    @wire.uint(8),
    3,
    domain,
    multi_write_policy=Reject,
    bounds_policy=Fault,
  )
  builder.memory_write(memory, "write_a", address_a, data_a, enable=enable_a)
  builder.memory_write(memory, "write_b", address_b, data_b, enable=enable_b)
  let source = @systemverilog.emit_design(
    @wire.single_design("RejectedCollision", builder.finish()),
  ).modules()[0].source()
  assert_true(source.contains("lc_n5 !== 1'b0"))
  assert_true(source.contains("=== 1'b1"))
  assert_true(source.contains("((lc_n1 == lc_n2) === 1'b1)) begin"))
  assert_true(
    source.contains("lc_mem0_write0_write1_collision: assert (1'b0);"),
  )
  assert_false(source.contains("always_comb"))
  assert_false(source.contains("for ("))
  assert_true(source.contains("lc_a0_b6d_b65_b6d_b6f_b72_b79[lc_n2] <="))
  assert_true(source.contains("lc_a0_b6d_b65_b6d_b6f_b72_b79[lc_n1] <="))
}

///|
test "power-of-two memories still reject unknown addresses" {
  let builder = @wire.ModuleBuilder::new("KnownAddress")
  let clock = builder.input("clock", @wire.clock())
  let address = builder.input("address", @wire.uint(2))
  let data = builder.input("data", @wire.uint(8))
  let enable = builder.input("enable", @wire.bits(1))
  let memory = builder.synchronous_memory(
    "memory",
    @wire.uint(8),
    4,
    builder.rising_edge(clock),
    bounds_policy=Fault,
  )
  builder.memory_write(memory, "write", address, data, enable~)
  let source = @systemverilog.emit_design(
    @wire.single_design("KnownAddress", builder.finish()),
  ).modules()[0].source()
  assert_true(source.contains("lc_ak0 = 1'b1;"))
  assert_true(source.contains("lc_ak0 = ((^lc_address) !== 1'bx);"))
  assert_true(
    source.contains("lc_mem0_write0_bounds: assert (lc_ak0(lc_n1) === 1'b1);"),
  )
}

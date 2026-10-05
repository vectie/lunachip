///|
fn dependency_generation_decoder_drive_lanes(
  simulator : @sim.Simulator,
  plan : DependencyGenerationPlan,
  lanes : ArrayView[UInt64],
) -> Unit raise {
  for ordinal in 0..<4 {
    let name = dependency_role_name(HeadLane(ordinal))
    guard plan.cuts.filter(cut => cut.roles.contains(name)) is [cut] else {
      fail("missing unique head-lane cut")
    }
    dependency_generation_drive_cut(simulator, cut, lanes[ordinal])
  }
  simulator.settle()
}

///|
test "generation decoder bindings are exact private cone aliases with no added cuts" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let transfer = dependency_generation_materialize(fixture)
  let expected = [
    ("decoder_syntax_fault", @wire.uint(4)),
    ("decoder_source_0", @wire.uint(3)),
    ("decoder_source_1", @wire.uint(3)),
    ("decoder_is_writer", @wire.bits(1)),
    ("decoder_writer_slot", @wire.uint(3)),
    ("decoder_unused_ok", @wire.bits(1)),
    ("decoder_dimensions_ok", @wire.bits(1)),
  ]
  assert_eq(transfer.plan.cuts.length(), 32)
  assert_eq(
    transfer.plan.cuts
    .iter()
    .fold(init=0, (sum, cut) => sum + cut.signal_type.width().bits()),
    671,
  )
  assert_eq(transfer.plan.decoder_bindings.length(), expected.length())
  for ordinal, binding in transfer.plan.decoder_bindings {
    let (name, signal_type) = expected[ordinal]
    assert_eq(binding.name, name)
    assert_eq(binding.signal_type, signal_type)
    assert_eq(
      dependency_generation_node(fixture.hardware(), binding.node).signal_type(),
      signal_type,
    )
    assert_false(transfer.plan.cuts.any(cut => cut.node == binding.node))
    assert_true(transfer.plan.cone.any(node => node.id() == binding.node))
    let output = transfer.hardware.outputs()[21 + ordinal]
    assert_eq(output.name(), name)
    assert_eq(output.signal_type(), signal_type)
    assert_eq(
      output.driver(),
      dependency_generation_mapped(transfer.original_to_local, binding.node),
    )
  }
}

///|
test "generation decoder retains full-byte opcode rejection and raw malformed source projections" {
  let transfer = dependency_generation_materialize(
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let simulator = @sim.Simulator::prepare(transfer.hardware)
  for cut in transfer.plan.cuts {
    dependency_generation_drive_cut(simulator, cut, 0UL)
  }
  for opcode in 0..<256 {
    for selectors in 0..<8 {
      let a = selectors & 1
      let b = (selectors >> 1) & 1
      let c = (selectors >> 2) & 1
      let slots = a.to_uint64() | (b.to_uint64() << 8) | (c.to_uint64() << 16)
      dependency_generation_decoder_drive_lanes(simulator, transfer.plan, [
        0x0200UL | (opcode.to_uint64() << 16),
        0UL,
        0UL,
        slots,
      ])
      assert_eq(
        simulator.output("decoder_syntax_fault").to_uint64(),
        if opcode <= 4 {
          0UL
        } else {
          1UL
        },
      )
      assert_eq(
        simulator.output("decoder_source_0").to_uint64(),
        if (opcode & 7) == 3 {
          (4 + c).to_uint64()
        } else {
          a.to_uint64()
        },
      )
      assert_eq(
        simulator.output("decoder_source_1").to_uint64(),
        (2 + b).to_uint64(),
      )
      // Do not authorize semantics from a truncated invalid opcode.
      if opcode <= 4 {
        assert_eq(
          simulator.output("decoder_is_writer").to_uint64(),
          if opcode <= 2 {
            1UL
          } else {
            0UL
          },
        )
        assert_eq(
          simulator.output("decoder_writer_slot").to_uint64(),
          if opcode == 0 {
            a.to_uint64()
          } else if opcode == 1 {
            (2 + b).to_uint64()
          } else {
            (4 + c).to_uint64()
          },
        )
      }
    }
  }
  // Invalid full-byte opcode 8 aliases low-three-bit LoadA only inside the
  // production semantic decoder. This is why identity comparisons are guarded.
  dependency_generation_decoder_drive_lanes(simulator, transfer.plan, [
    0x080200UL, 0UL, 0UL, 0UL,
  ])
  assert_eq(simulator.output("decoder_syntax_fault").to_uint64(), 1UL)
  assert_eq(simulator.output("decoder_is_writer").to_uint64(), 1UL)
}

///|
test "generation decoder syntax priority uses every raw reserved and dimension bit" {
  let transfer = dependency_generation_materialize(
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let simulator = @sim.Simulator::prepare(transfer.hardware)
  for cut in transfer.plan.cuts {
    dependency_generation_drive_cut(simulator, cut, 0UL)
  }
  let cases : Array[(UInt64, UInt64, UInt64, UInt64)] = [
    (0x00ff_0201UL, 0xffff_ffff_ffff_ffffUL, 0xffff_ffff_ffff_ffffUL, 12UL),
    (0x01ff_0200UL, 0xffff_ffff_ffff_ffffUL, 0xffff_ffff_ffff_ffffUL, 13UL),
    (0x00ff_0200UL, 8192UL, 0UL, 1UL),
    (0x0000_0200UL, 8192UL, 0UL, 14UL),
    (0x0000_0200UL, 8192UL << 16, 0UL, 14UL),
    (0x0000_0200UL, 8192UL << 32, 0UL, 14UL),
    (0x0000_0200UL, 1UL << 48, 0UL, 13UL),
  ]
  for (first, dimensions, slots, fault) in cases {
    dependency_generation_decoder_drive_lanes(simulator, transfer.plan, [
      first, dimensions, 0UL, slots,
    ])
    assert_eq(simulator.output("decoder_syntax_fault").to_uint64(), fault)
  }
  for bit in 0..<64 {
    if bit != 0 && bit != 8 && bit != 16 {
      dependency_generation_decoder_drive_lanes(simulator, transfer.plan, [
        0x0200UL,
        0UL,
        0UL,
        1UL << bit,
      ])
      assert_eq(simulator.output("decoder_syntax_fault").to_uint64(), 13UL)
    }
  }
  for bit in 24..<32 {
    dependency_generation_decoder_drive_lanes(simulator, transfer.plan, [
      0x0200UL | (1UL << bit),
      0UL,
      0UL,
      0UL,
    ])
    assert_eq(simulator.output("decoder_syntax_fault").to_uint64(), 13UL)
  }
}

///|
test "generation decoder semantic dimensions and unused fields are checked only with valid syntax" {
  let transfer = dependency_generation_materialize(
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let simulator = @sim.Simulator::prepare(transfer.hardware)
  for cut in transfer.plan.cuts {
    dependency_generation_drive_cut(simulator, cut, 0UL)
  }
  for opcode in 0..<5 {
    for rows in [0, 1, 2, 3, 8191, 8192, 65535] {
      for columns in [0, 1, 2, 3, 8191, 8192, 65535] {
        for reduction in [0, 1, 2, 3, 8191, 8192, 65535] {
          dependency_generation_decoder_drive_lanes(simulator, transfer.plan, [
            0x0200UL | (opcode.to_uint64() << 16),
            rows.to_uint64() |
            (columns.to_uint64() << 16) |
            (reduction.to_uint64() << 32),
            0UL,
            0UL,
          ])
          let syntax_ok = rows <= 8191 && columns <= 8191 && reduction <= 8191
          assert_eq(
            simulator.output("decoder_syntax_fault").to_uint64(),
            if syntax_ok {
              0UL
            } else {
              14UL
            },
          )
          if syntax_ok {
            let shape_ok = match opcode {
              0 => rows == 1 && columns >= 1 && columns <= 2
              1 => rows >= 1 && rows <= 2 && columns == 1
              2 => rows == 1 && columns == 1 && reduction >= 1 && reduction <= 2
              3 => rows == 1 && columns == 1
              _ => true
            }
            let unused_ok = match opcode {
              0 | 1 | 3 => reduction == 0
              2 => true
              _ => rows == 0 && columns == 0 && reduction == 0
            }
            assert_eq(
              simulator.output("decoder_dimensions_ok").to_uint64(),
              if shape_ok {
                1UL
              } else {
                0UL
              },
            )
            assert_eq(
              simulator.output("decoder_unused_ok").to_uint64(),
              if unused_ok {
                1UL
              } else {
                0UL
              },
            )
          }
        }
      }
    }
  }
  for opcode in 0..<5 {
    for selectors in 0..<8 {
      for address in [0UL, 1UL, 1UL << 32] {
        let a = selectors & 1
        let b = (selectors >> 1) & 1
        let c = (selectors >> 2) & 1
        dependency_generation_decoder_drive_lanes(simulator, transfer.plan, [
          0x0200UL | (opcode.to_uint64() << 16),
          0UL,
          address,
          a.to_uint64() | (b.to_uint64() << 8) | (c.to_uint64() << 16),
        ])
        let unused_ok = match opcode {
          0 => b == 0 && c == 0
          1 => a == 0 && c == 0
          2 => address == 0UL
          3 => a == 0 && b == 0
          _ => a == 0 && b == 0 && c == 0 && address == 0UL
        }
        assert_eq(
          simulator.output("decoder_unused_ok").to_uint64(),
          if unused_ok {
            1UL
          } else {
            0UL
          },
        )
      }
    }
  }
}

///|
fn dependency_generation_decoder_replace_kind(
  hardware : @ir.Module,
  id : @ir.NodeId,
  kind : @ir.NodeKind,
) -> @ir.Module raise {
  let nodes = hardware
    .nodes()
    .iter()
    .map(node => {
      if node.id() == id {
        @ir.Node::new(id, node.signal_type(), kind)
      } else {
        node
      }
    })
    .to_array()
  @ir.Module::checked_with_metadata(
    hardware.name(),
    hardware.domains(),
    nodes,
    hardware.memories(),
    hardware.outputs(),
    hardware.metadata(),
  )
}

///|
test "generation decoder extraction rejects same-type authoritative wiring drift" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let hardware = fixture.hardware()
  let bindings = dependency_generation_bindings(fixture)
  let plan = dependency_generation_discover(fixture)
  let (_, _, dispatch_fault) = dependency_generation_decoder_mux(
    hardware,
    plan.local_fault,
  )
  let (syntax_ok, _, _) = dependency_generation_decoder_mux(
    hardware, dispatch_fault,
  )
  // Corrupt constants/aliases without adding a cycle or extra graph leaves.
  guard dependency_generation_node(hardware, syntax_ok).kind() is Equal(_, zero) else {
    fail("missing syntax comparator")
  }
  let wrong_zero = dependency_generation_decoder_replace_kind(
    hardware,
    zero,
    Constant(1UL),
  )
  dependency_generation_expect_failure(wrong_zero, bindings)
  let snapshot = dependency_generation_binding(bindings, DependencyStatus(0)).node
  guard dependency_generation_node(hardware, snapshot).kind() is Register(spec) else {
    fail("missing snapshot")
  }
  let (_, selected, _) = dependency_generation_decoder_mux(
    hardware,
    spec.next(),
  )
  let (condition, _, rest) = dependency_generation_decoder_mux(
    hardware, selected,
  )
  let wrong_leaf = dependency_generation_decoder_replace_kind(
    hardware,
    selected,
    Mux(
      select=condition,
      when_true=dependency_generation_binding(bindings, WriterStatus(4)).node,
      when_false=rest,
    ),
  )
  dependency_generation_expect_failure(wrong_leaf, bindings)
  guard dependency_generation_node(hardware, condition).kind()
    is Equal(_, ordinal) else {
    fail("missing snapshot selector comparator")
  }
  let source1 = plan.decoder_bindings[2].node
  let wrong_source = dependency_generation_decoder_replace_kind(
    hardware,
    condition,
    Equal(source1, ordinal),
  )
  dependency_generation_expect_failure(wrong_source, bindings)
  let status = dependency_generation_binding(bindings, WriterStatus(0)).node
  guard dependency_generation_node(hardware, status).kind()
    is Register(writer_spec) else {
    fail("missing writer")
  }
  let (intent, _, _) = dependency_generation_decoder_mux(
    hardware,
    writer_spec.next(),
  )
  let (publish, _) = dependency_generation_decoder_and(hardware, intent)
  let (_, not_poison) = dependency_generation_decoder_and(hardware, publish)
  let reserve = dependency_generation_binding(bindings, HeadReserve).node
  let wrong_poison = dependency_generation_decoder_replace_kind(
    hardware,
    not_poison,
    BitNot(reserve),
  )
  dependency_generation_expect_failure(wrong_poison, bindings)
}

///|
test "packet composition exact selected original kinds controls and all output drivers are remapped" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let slice = queue_packet_composition_sequential(fixture)
  let repeated = queue_packet_composition_sequential(fixture)
  let probe = slice.probe
  assert_eq(slice.hardware, repeated.hardware)
  assert_eq(slice.original_to_local, repeated.original_to_local)
  assert_eq(slice.original_to_local_memory, repeated.original_to_local_memory)
  assert_eq(slice.cuts, repeated.cuts)
  assert_eq(
    slice.inventory_digest,
    sha256_hex(queue_packet_composition_report(probe)),
  )
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Register(_)).length(),
    54,
  )
  assert_eq(
    slice.hardware
    .nodes()
    .filter(node => node.kind() is MemoryRead(..))
    .length(),
    4,
  )
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Input(_)).length(),
    slice.cuts.length() + 1,
  )
  let clock = queue_storage_test_node(slice.original_to_local, probe.clock)
  assert_eq(slice.hardware.domains(), [@ir.ClockDomain::rising(clock)])
  let mut ordinal = 0
  for original in probe.source.nodes() {
    let retained = (if original.id() == probe.clock { 1 } else { 0 }) +
      probe.roots.filter(root => root.node == original.id()).length() +
      probe.candidates
      .filter(candidate => candidate.original.id() == original.id())
      .length() +
      probe.cone.filter(node => node.id() == original.id()).length() +
      probe.lanes.filter(lane => lane.result.id() == original.id()).length()
    assert_true(retained <= 1)
    match slice.original_to_local[original.id().ordinal()] {
      None => assert_eq(retained, 0)
      Some(mapped) => {
        assert_eq(retained, 1)
        assert_eq(mapped.ordinal(), ordinal)
        ordinal += 1
        let copy = slice.hardware.nodes()[mapped.ordinal()]
        assert_eq(copy.signal_type(), original.signal_type())
        if original.id() == probe.clock {
          assert_eq(copy.kind(), Input("clock"))
        } else if probe.roots.any(root => root.node == original.id()) {
          guard original.kind() is Register(actual) &&
            copy.kind() is Register(saved) else {
            fail("essential original register lost")
          }
          assert_eq(saved.domain(), @ir.ClockDomain::rising(clock))
          assert_eq(saved.initial(), actual.initial())
          assert_eq(
            saved.next(),
            queue_storage_test_node(slice.original_to_local, actual.next()),
          )
          assert_eq(
            saved.enable(),
            actual
            .enable()
            .map(id => queue_storage_test_node(slice.original_to_local, id)),
          )
          assert_eq(
            saved.reset(),
            actual
            .reset()
            .map(control => {
              @ir.ResetSpec::explicit(
                queue_storage_test_node(
                  slice.original_to_local,
                  control.signal(),
                ),
                control.value(),
                control.mode(),
                control.polarity(),
              )
            }),
          )
        } else if probe.candidates.any(candidate => {
            candidate.original.id() == original.id()
          }) {
          assert_eq(copy.kind(), Input("cut_n\{original.id().ordinal()}"))
          guard slice.cuts.filter(cut => cut.node == original.id()) is [cut] else {
            fail("candidate has no unique typed input")
          }
          assert_eq(cut.signal_type, original.signal_type())
        } else if original.kind() is MemoryRead(memory~, port~) {
          guard slice.original_to_local_memory[memory.ordinal()]
            is Some(mapped_memory) else {
            fail("registered result memory missing")
          }
          assert_eq(copy.kind(), MemoryRead(memory=mapped_memory, port~))
        } else {
          assert_eq(
            copy.kind(),
            queue_storage_test_kind(original.kind(), slice.original_to_local),
          )
        }
      }
    }
  }
  assert_eq(ordinal, slice.hardware.nodes().length())
  let expected : Array[@ir.OutputPort] = []
  for root in probe.roots {
    expected.push(
      @ir.OutputPort::new(
        "current_" + root.name,
        root.signal_type,
        queue_storage_test_node(slice.original_to_local, root.node),
      ),
    )
  }
  for binding in probe.observations {
    expected.push(
      @ir.OutputPort::new(
        binding.name,
        binding.signal_type,
        queue_storage_test_node(slice.original_to_local, binding.node),
      ),
    )
  }
  for output in probe.source.outputs() {
    expected.push(
      @ir.OutputPort::new(
        "public_" + output.name(),
        output.signal_type(),
        queue_storage_test_node(slice.original_to_local, output.driver()),
      ),
    )
  }
  for lane in probe.lanes {
    guard lane.read.enable() is Some(pop_fire) &&
      lane.write.enable() is Some(push_fire) else {
      fail("missing actual lane fire")
    }
    for
      (name, node) in [
        ("fifo_pop_fire_\{lane.lane}", pop_fire),
        ("fifo_push_fire_\{lane.lane}", push_fire),
      ] {
      expected.push(
        @ir.OutputPort::new(
          name,
          @wire.bits(1),
          queue_storage_test_node(slice.original_to_local, node),
        ),
      )
    }
  }
  assert_eq(slice.hardware.outputs(), ReadOnlyArray::from_array(expected))
  assert_eq(
    @ir_codec.serialize(@ir.Design::single("Projection", slice.hardware)),
    @ir_codec.serialize(@ir.Design::single("Projection", repeated.hardware)),
  )
}

///|
test "packet composition prints complete source and candidate projection inventory" {
  let slice = queue_packet_composition_sequential(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  let report = queue_packet_composition_sequential_report(slice)
  println(
    "PACKET-COMPOSITION-REPORT-BEGIN\n\{report}PACKET-COMPOSITION-REPORT-END",
  )
}

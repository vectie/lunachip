///|
fn dependency_conjunction_test_domain(
  domain : @ir.ClockDomain,
  mapping : ArrayView[@ir.NodeId?],
) -> @ir.ClockDomain raise {
  @ir.ClockDomain::new(
    domain.id(),
    queue_storage_test_node(mapping, domain.clock()),
    domain.edge(),
  )
}

///|
test "dependency conjunction copies every selected original operation state control and output exactly" {
  let queue_fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let dependency_fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let slice = dependency_conjunction_sequential(
    queue_fixture, dependency_fixture,
  )
  let repeated = dependency_conjunction_sequential(
    queue_fixture, dependency_fixture,
  )
  let probe = slice.probe
  let packet = probe.packet
  assert_eq(slice.hardware, repeated.hardware)
  assert_eq(slice.original_to_local, repeated.original_to_local)
  assert_eq(slice.original_to_local_memory, repeated.original_to_local_memory)
  assert_eq(slice.cuts, repeated.cuts)
  assert_eq(
    slice.inventory_digest,
    sha256_hex(dependency_conjunction_report(probe)),
  )
  assert_eq(
    slice.hardware.nodes().filter(node => node.kind() is Register(_)).length(),
    probe.roots.length(),
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
    probe.candidates.length() + 1,
  )
  let mut ordinal = 0
  for original in packet.source.nodes() {
    let retained = (if original.id() == packet.clock { 1 } else { 0 }) +
      probe.roots.filter(root => root.node == original.id()).length() +
      probe.candidates
      .filter(candidate => candidate.original.id() == original.id())
      .length() +
      probe.cone.filter(node => node.id() == original.id()).length() +
      packet.lanes.filter(lane => lane.result.id() == original.id()).length()
    assert_true(retained <= 1)
    match slice.original_to_local[original.id().ordinal()] {
      None => assert_eq(retained, 0)
      Some(mapped) => {
        assert_eq(retained, 1)
        assert_eq(mapped.ordinal(), ordinal)
        ordinal += 1
        let copy = slice.hardware.nodes()[mapped.ordinal()]
        assert_eq(copy.signal_type(), original.signal_type())
        if original.id() == packet.clock {
          assert_eq(copy.kind(), Input("clock"))
        } else if probe.roots.any(root => root.node == original.id()) {
          guard original.kind() is Register(actual) &&
            copy.kind() is Register(saved) else {
            fail("original retained register replaced")
          }
          assert_eq(
            saved.domain(),
            dependency_conjunction_test_domain(
              actual.domain(),
              slice.original_to_local,
            ),
          )
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
            fail("raw boundary missing unique cut")
          }
          assert_eq(cut.signal_type, original.signal_type())
          assert_eq(
            cut.roles,
            ReadOnlyArray::from_array([
              match original.kind() {
                Input(name) => name
                Register(_) => "foreign_n\{original.id().ordinal()}"
                _ => fail("derived expression cut")
              },
            ]),
          )
        } else if original.kind() is MemoryRead(memory~, port~) {
          guard slice.original_to_local_memory[memory.ordinal()]
            is Some(mapped_memory) else {
            fail("actual FIFO memory omitted")
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
  fn output(
    name : String,
    signal_type : @ir.SignalType,
    driver : @ir.NodeId,
  ) -> Unit raise {
    expected.push(
      @ir.OutputPort::new(
        name,
        signal_type,
        queue_storage_test_node(slice.original_to_local, driver),
      ),
    )
  }
  for root in probe.roots {
    output("current_" + root.name, root.signal_type, root.node)
  }
  for binding in probe.observations {
    output(binding.name, binding.signal_type, binding.node)
  }
  for port in packet.source.outputs() {
    output("public_" + port.name(), port.signal_type(), port.driver())
  }
  for lane in packet.lanes {
    guard lane.read.enable() is Some(pop_fire) &&
      lane.write.enable() is Some(push_fire) else {
      fail("original memory fire missing")
    }
    output("fifo_pop_fire_\{lane.lane}", @wire.bits(1), pop_fire)
    output("fifo_push_fire_\{lane.lane}", @wire.bits(1), push_fire)
  }
  guard packet.source
    .nodes()
    .filter(node => node.kind() is Input("memory_response_data"))
    is [response_data] else {
    fail("original public payload identity missing")
  }
  assert_eq(response_data.signal_type(), @wire.bits(32))
  output(
    "public_input_memory_response_data",
    response_data.signal_type(),
    response_data.id(),
  )
  assert_eq(slice.hardware.outputs(), ReadOnlyArray::from_array(expected))
  for index, port in slice.hardware.outputs() {
    assert_false(
      slice.hardware.outputs()[:index].any(prior => prior.name() == port.name()),
    )
  }
  let clock = queue_storage_test_node(slice.original_to_local, packet.clock)
  assert_eq(slice.hardware.domains(), [@ir.ClockDomain::rising(clock)])
}

///|
test "dependency conjunction preserves all original FIFO cell and read state specs without initialization" {
  let slice = dependency_conjunction_sequential(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let source = slice.probe.packet.source
  assert_eq(slice.original_to_local_memory.length(), source.memories().length())
  let mut ordinal = 0
  for memory in source.memories() {
    let lanes = slice.probe.packet.lanes.filter(lane => lane.memory == memory)
    match slice.original_to_local_memory[memory.id().ordinal()] {
      None => assert_true(lanes.is_empty())
      Some(mapped_memory) => {
        assert_eq(mapped_memory.ordinal(), ordinal)
        ordinal += 1
        guard lanes is [lane] else {
          fail("memory no longer bound to its actual lane")
        }
        assert_eq(memory.depth().elements(), 3)
        assert_eq(memory.element_type(), @wire.bits(64))
        assert_eq(memory.read_write_policy(), ReadOld)
        assert_eq(memory.multi_write_policy(), Reject)
        assert_eq(memory.bounds_policy(), Fault)
        assert_eq(memory.read_ports(), [lane.read])
        assert_eq(memory.write_ports(), [lane.write])
        assert_eq(lane.read.latency(), OneCycle)
        assert_eq(lane.read.enable_behavior(), HoldLast)
        assert_eq(lane.write.mask(), All)
        assert_eq(lane.read.address(), lane.read_pointer.node)
        assert_eq(lane.write.address(), lane.write_pointer.node)
        assert_eq(lane.write.data(), lane.public_data)
        let reads : Array[@ir.MemoryReadPort] = []
        for read in memory.read_ports() {
          let enable = read
            .enable()
            .map(id => queue_storage_test_node(slice.original_to_local, id))
          reads.push(
            @ir.MemoryReadPort::new(
              read.id(),
              read.name(),
              dependency_conjunction_test_domain(
                read.domain(),
                slice.original_to_local,
              ),
              queue_storage_test_node(slice.original_to_local, read.address()),
              enable?,
              read.latency(),
              read.enable_behavior(),
              queue_storage_test_node(slice.original_to_local, read.result()),
            ),
          )
        }
        let writes : Array[@ir.MemoryWritePort] = []
        for write in memory.write_ports() {
          let enable = write
            .enable()
            .map(id => queue_storage_test_node(slice.original_to_local, id))
          let mask : @ir.MemoryWriteMask = match write.mask() {
            All => All
            Granular(signal~, granularity~) =>
              Granular(
                signal=queue_storage_test_node(slice.original_to_local, signal),
                granularity~,
              )
          }
          writes.push(
            @ir.MemoryWritePort::new(
              write.id(),
              write.name(),
              dependency_conjunction_test_domain(
                write.domain(),
                slice.original_to_local,
              ),
              queue_storage_test_node(slice.original_to_local, write.address()),
              queue_storage_test_node(slice.original_to_local, write.data()),
              enable?,
              mask,
            ),
          )
        }
        assert_eq(
          slice.hardware.memories()[mapped_memory.ordinal()],
          @ir.MemorySpec::new(
            mapped_memory,
            memory.name(),
            memory.element_type(),
            memory.depth(),
            dependency_conjunction_test_domain(
              memory.domain(),
              slice.original_to_local,
            ),
            reads,
            writes,
            memory.read_write_policy(),
            memory.multi_write_policy(),
            memory.bounds_policy(),
          ),
        )
        assert_false(slice.cuts.any(cut => cut.node == lane.result.id()))
        assert_eq(
          source.nodes()[lane.result.id().ordinal()].kind(),
          MemoryRead(memory=memory.id(), port=lane.read.id()),
        )
      }
    }
  }
  assert_eq(ordinal, 4)
  let report = dependency_conjunction_sequential_report(slice)
  assert_true(
    report.has_prefix(
      "CANDIDATE-DEPENDENCY-CONJUNCTION not-accepted-projection-or-proof\n",
    ),
  )
  assert_eq(report, dependency_conjunction_sequential_report(slice))
  println(
    "DEPENDENCY-CONJUNCTION-REPORT-BEGIN\n" +
    report +
    "DEPENDENCY-CONJUNCTION-REPORT-END",
  )
}

///|
fn dependency_conjunction_report(probe : DependencyConjunctionProbe) -> String {
  let packet = probe.packet
  let out = StringBuilder()
  out.write_string(
    "CANDIDATE-DEPENDENCY-CONJUNCTION not-accepted-projection-or-proof\n",
  )
  out.write_string(
    "NO-CUT-AUTHORITY raw-foreign-producer-overapproximation no-private-premise no-Store-physical-data-theorem\n",
  )
  out.write_string(
    "PRODUCTION \{packet.production_digest} wrapper QueuedConcurrentQueueConservationPilot\n",
  )
  out.write_string(
    "PRECEDING packet-report-sha256 \{sha256_hex(queue_packet_composition_report(packet))}\n",
  )
  out.write_string(
    "CLOCK \{packet.clock.ordinal()} RESET \{packet.reset.ordinal()}\n",
  )
  let bits = probe.roots
    .iter()
    .fold(init=0, (n, root) => n + root.signal_type.width().bits())
  out.write_string(
    "ESSENTIAL roots \{probe.roots.length()} bits \{bits} FIFO-memories \{packet.lanes.length()} cells12 cell-bits768 read-state256 uninitialized\n",
  )
  out.write_string(
    "INVENTORY candidates \{probe.candidates.length()} cone \{probe.cone.length()} observations \{probe.observations.length()} dependency-bindings \{probe.bindings.length()} seeds \{probe.seeds.length()}\n",
  )
  out.write_string(
    "SCOPE original-dependency-p4-through-p10 four-public-premises five-original-covers three-original-negative-controls no-lemma-assumptions\n",
  )
  for root in probe.roots {
    let spec = "\{Repr(root.spec)}".replace_all(old="\n", new="")
    out.write_string(
      "ROOT \{root.name} node \{root.node.ordinal()} type \{Repr(root.signal_type)} spec \{spec}\n",
    )
  }
  for lane in packet.lanes {
    let memory = "\{Repr(lane.memory)}".replace_all(old="\n", new="")
    let read_state = "\{Repr(lane.result)}".replace_all(old="\n", new="")
    out.write_string(
      "MEMORY lane \{lane.lane} public-data \{lane.public_data.ordinal()} complete \{memory}\n",
    )
    out.write_string("READ-STATE lane \{lane.lane} complete \{read_state}\n")
  }
  for observation in probe.observations {
    out.write_string(
      "OBSERVATION \{observation.name} node \{observation.node.ordinal()} type \{Repr(observation.signal_type)}\n",
    )
  }
  for output in packet.source.outputs() {
    out.write_string(
      "PUBLIC-OUTPUT \{output.name()} node \{output.driver().ordinal()} type \{Repr(output.signal_type())}\n",
    )
  }
  for index, seed in probe.seeds {
    out.write_string(
      "SEED \{index} origin \{Repr(seed.origin)} node \{seed.node.ordinal()}\n",
    )
  }
  for node in probe.cone {
    let kind = "\{Repr(node.kind())}".replace_all(old="\n", new="")
    out.write_string(
      "CONE node \{node.id().ordinal()} type \{Repr(node.signal_type())} kind \{kind}\n",
    )
  }
  for candidate in probe.candidates {
    let node = candidate.original
    let kind = "\{Repr(node.kind())}".replace_all(old="\n", new="")
    out.write_string(
      "CANDIDATE node \{node.id().ordinal()} type \{Repr(node.signal_type())} full-kind \{kind} seeds \{Repr(candidate.provenance)}\n",
    )
  }
  out.to_string()
}

///|
#warnings("-unused_value")
fn dependency_conjunction_sequential_report(
  slice : DependencyConjunctionSequential,
) -> String raise {
  let out = StringBuilder()
  out.write_string(dependency_conjunction_report(slice.probe))
  let digest = sha256_hex(
    @ir_codec.serialize(
      @ir.Design::single("DependencyConjunctionSequential", slice.hardware),
    ),
  )
  out.write_string(
    "CANDIDATE-PROJECTION report-sha256 \{slice.inventory_digest} canonical-sha256 \{digest}\n",
  )
  for original in slice.probe.packet.source.nodes() {
    if slice.original_to_local[original.id().ordinal()] is Some(mapped) {
      let node = slice.hardware.nodes()[mapped.ordinal()]
      let kind = "\{Repr(node.kind())}".replace_all(old="\n", new="")
      out.write_string(
        "MAPPED original \{original.id().ordinal()} local \{mapped.ordinal()} type \{Repr(node.signal_type())} kind \{kind}\n",
      )
    }
  }
  for memory in slice.hardware.memories() {
    let spec = "\{Repr(memory)}".replace_all(old="\n", new="")
    out.write_string("MAPPED-MEMORY \{spec}\n")
  }
  for output in slice.hardware.outputs() {
    out.write_string(
      "MAPPED-OUTPUT \{output.name()} local \{output.driver().ordinal()} type \{Repr(output.signal_type())}\n",
    )
  }
  out.to_string()
}

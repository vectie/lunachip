///|
fn fetched_transport_probe_report(probe : FetchedTransportProbe) -> String {
  let out = StringBuilder()
  out.write_string(
    "FETCHED-TRANSPORT private-component-checkpoint-not-proof-or-full-device-write\n",
  )
  out.write_string(
    "DESIGN phase6-fetched-concurrent-1x1-k2 rows1 columns1 K2 host1024 ring4 queue2\n",
  )
  out.write_string(
    "PRODUCTION sha256 \{probe.production_digest}\nCLOCK node \{probe.clock.ordinal()} RESET node \{probe.reset.ordinal()}\n",
  )
  out.write_string(
    "ROOTS \{probe.roots.length()} BITS \{probe.roots.fold(init=0, (bits, root) => bits + root.signal_type.width().bits())}\n",
  )
  for root in probe.roots {
    out.write_string(
      "ROOT \{root.name} node \{root.node.ordinal()} type \{Repr(root.signal_type)} spec \{Repr(root.spec)}\n",
    )
  }
  let bits = probe.candidates.fold(init=0, (bits, candidate) => {
    bits + candidate.original.signal_type().width().bits()
  })
  out.write_string(
    "BOUNDARIES \{probe.boundaries.length()} CUTS \{probe.candidates.length()} CUTBITS \{bits} CONE \{probe.cone.length()} EVENTS \{probe.events.length()}\n",
  )
  for boundary in probe.boundaries {
    let node = boundary.original
    let status = if node.kind() is Constant(_) {
      "retained-constant"
    } else {
      "raw-interface"
    }
    out.write_string(
      "BOUNDARY \{status} roles \{boundary.roles.iter().to_array().join(",")} node \{node.id().ordinal()} type \{Repr(node.signal_type())} kind \{Repr(node.kind())}\n",
    )
  }
  for event in probe.events {
    out.write_string(
      "EVENT \{event.name} node \{event.node.ordinal()} type \{Repr(event.signal_type)}\n",
    )
  }
  // Report every retained combinational node, not just leaf counts.
  for node in probe.cone {
    out.write_string(
      "CONE node \{node.id().ordinal()} type \{Repr(node.signal_type())} kind \{Repr(node.kind())}\n",
    )
  }
  out.write_string(
    "SCOPE original-reader-state-byte-assembly-publication-and-three-client-cyclic-transport\n",
  )
  out.write_string(
    "OPEN full-original-fetched-Store-write-public-ACK-cover-safety-horizon-DMA-memory-dependency-and-completion\nEND\n",
  )
  out.to_string()
}

///|
// Reviewed boundary for the original seven packet assertions ONLY. This does
// not authorize Store payload, DMA bounds, numerical arithmetic or progress
// claims. Literal acceptance binds the complete base report (not the larger
// sequential mapping report), together with the canonical production source.
#warnings("-unused_value")
fn queue_packet_composition_require_inventory(
  probe : QueuePacketCompositionProbe,
) -> Unit raise {
  let production = sha256_hex(
    @ir_codec.serialize(
      @ir.Design::single("QueuedConcurrentQueueConservationPilot", probe.source),
    ),
  )
  if production !=
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc" ||
    probe.production_digest != production ||
    sha256_hex(queue_packet_composition_report(probe)) !=
    "01275b9792d9f2bd9bbb9b026a8de861931b0821dc9634f4439fa9f1c391e7b2" {
    raise InvalidFormalBundleIdentity(
      "packet composition: reviewed seven-assertion source and boundary drift",
    )
  }
}

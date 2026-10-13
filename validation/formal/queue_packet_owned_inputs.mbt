///|
fn queue_packet_owned_groups() -> ReadOnlyArray[String] {
  ["packet-retirement-composition", "packet-full-conjunction"]
}

///|
fn queue_packet_owned_original(
  inputs : QueuePacketCompositionExport,
  group : String,
) -> String raise {
  guard queue_packet_owned_groups().contains(group) else {
    raise InvalidFormalBundleIdentity("packet owned: unknown selected group")
  }
  let mut source = inputs.positive
  for property in inputs.properties.properties() {
    if property.kind() is Cover {
      source = store_full_remove_statement(
        source,
        property.stable_name(),
        "cover",
      )
    } else if group == "packet-retirement-composition" &&
      property.kind() is Assertion &&
      property.source_name() == "packet_provenance_ok" {
      source = store_full_remove_statement(
        source,
        property.stable_name(),
        "assert",
      )
    }
  }
  if group == "packet-retirement-composition" {
    for label in inputs.strengthening_assertions {
      source = store_full_remove_statement(source, label, "assert")
    }
  }
  source
}

///|
fn queue_packet_owned_source(
  inputs : QueuePacketCompositionExport,
  owner : QueueOwnerProbe,
  group : String,
) -> String raise {
  let original = queue_packet_owned_original(inputs, group)
  let support = queue_packet_owner_checked_source(inputs, owner) +
    queue_packet_fifo_checked_source(inputs)
  guard original.split("endmodule\n").count() == 2 &&
    !support.contains("endmodule") else {
    raise InvalidFormalBundleIdentity("packet owned: unique source splice")
  }
  original.replace(old="endmodule\n", new=support + "endmodule\n")
}

///|
#warnings("-unused_value")
fn queue_packet_owned_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let inputs = queue_packet_composition_export(fixture)
  let owner = queue_owner_probe(fixture)
  let artifacts : Array[FormalBundleArtifact] = []
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE exact-original-packet-retirement-and-full-seventeen-assertion-conjunction\n" +
    "ORIGINAL-BRIDGE sha256 \{sha256_hex(inputs.positive)}\n" +
    "ORIGINAL-BOOLEAN sha256 \{sha256_hex(inputs.boolean_source)}\n" +
    "PROJECTION-REPORT sha256 \{sha256_hex(queue_packet_composition_sequential_report(inputs.sequential))}\n" +
    "STATE unchanged54-original-registers876bits-four-q3-Bits64-arrays768bits-four-held-read-states256bits-total1900bits\n" +
    "BOUNDARY original101-cut-leaves-and-one-public-admission-watch-no-new-cuts\n" +
    "ASSUMPTIONS unchanged-four-public-peer-premises-symbolic-later-reset-no-internal-or-fairness-premise\n" +
    "SUPPORT checked-original-owner-ring-ticket-bijection-events-and-actual-FIFO-shape-never-assumed\n" +
    "LIMITATION no-Store-DMA-numerical-MatMul-fetched-host-address-fairness8x8-or-Phase6-pass\n",
  )
  for group in queue_packet_owned_groups() {
    let source = queue_packet_owned_source(inputs, owner, group)
    let config = store_lease_config(group, inputs.top_identifier)
    artifacts.push({ path: group + ".sv", content: source, })
    artifacts.push({ path: group + ".sby", content: config, })
    inventory.write_string(
      "TASK \{group} assertions \{source.split(": assert (").count() - 1} source-sha256 \{sha256_hex(source)} config-sha256 \{sha256_hex(config)}\n",
    )
  }
  artifacts.push({
    path: "packet-owned-inputs.txt",
    content: inventory.to_string(),
  })
  ReadOnlyArray::from_array(artifacts)
}

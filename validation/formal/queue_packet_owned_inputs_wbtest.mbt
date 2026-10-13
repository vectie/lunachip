///|
test "packet owned composition preserves original source and conclusion selection" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let inputs = queue_packet_composition_export(fixture)
  let owner = queue_owner_probe(fixture)
  assert_eq(
    sha256_hex(inputs.positive),
    "fcf4e3695af5ffdf589944719d0f20edab0c10de612508cccd468975fd96fd1b",
  )
  assert_eq(
    sha256_hex(inputs.boolean_source),
    "eb253723f215f8203f54e9b282b54e76b9a15cfa0cce384105150d47d833f05b",
  )
  let support = queue_packet_owner_checked_source(inputs, owner) +
    queue_packet_fifo_checked_source(inputs)
  assert_eq(support.split(": assert (").count() - 1, 3)
  assert_false(support.contains(": assume ("))
  assert_false(support.contains("anyseq"))
  assert_false(support.contains("logic "))
  assert_true(support.contains(queue_owner_ticket_source()))
  assert_true(support.contains(queue_owner_bijection_source()))
  assert_true(support.contains(queue_owner_event_source()))
  assert_true(support.contains("!lc_seen_edge || lc_raw_owner_invariant"))
  assert_false(support.contains("lc_reset || lc_raw_owner_invariant"))
  for group in queue_packet_owned_groups() {
    let selected = queue_packet_owned_original(inputs, group)
    let source = queue_packet_owned_source(inputs, owner, group)
    assert_eq(
      source.replace(old=support + "endmodule\n", new="endmodule\n"),
      selected,
    )
    assert_eq(
      source.split(": assert (").count() - 1,
      if group == "packet-full-conjunction" {
        20
      } else {
        18
      },
    )
    assert_eq(source.split(": assume (").count() - 1, 4)
    assert_false(source.contains(": cover ("))
    for property in inputs.properties.properties() {
      if property.kind() is Assumption || property.kind() is Assertion {
        let keep = property.kind() is Assumption ||
          group == "packet-full-conjunction" ||
          property.source_name() != "packet_provenance_ok"
        let operation = if property.kind() is Assumption {
          "assume"
        } else {
          "assert"
        }
        assert_eq(
          source.contains(property.stable_name() + ": " + operation + " ("),
          keep,
        )
      }
    }
    for labels in [inputs.memory_bounds, inputs.global_assertions] {
      for label in labels {
        assert_true(source.contains(label + ": assert ("))
      }
    }
    assert_true(
      source.contains(
        queue_packet_composition_retention_source(
          inputs.sequential,
          inputs.emitted,
        ),
      ),
    )
  }
}

///|
test "packet checked ownership rejects changed retained roots and actual event identity" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let inputs = queue_packet_composition_export(fixture)
  let owner = queue_owner_probe(fixture)
  let roots = owner.roots.iter().to_array()
  roots[0] = { ..roots[0], name: "wrong_retained_root", }
  try
    queue_packet_owner_checked_source(inputs, {
      ..owner,
      roots: ReadOnlyArray::from_array(roots),
    })
  catch {
    InvalidFormalBundleIdentity(_) => ()
    other => fail("unexpected rejection: \{other}")
  } noraise {
    _ => fail("changed owner root must be rejected")
  }
  let events = owner.events.iter().to_array()
  events[0] = { ..events[0], name: "wrong_original_event", }
  try
    queue_packet_owner_checked_source(inputs, {
      ..owner,
      events: ReadOnlyArray::from_array(events),
    })
  catch {
    InvalidFormalBundleIdentity(_) => ()
    other => fail("unexpected rejection: \{other}")
  } noraise {
    _ => fail("changed original event must be rejected")
  }
  let source = queue_packet_fifo_checked_source(inputs)
  assert_eq(source.split("  wire lc_packet_fifo_").count() - 1, 9)
  assert_true(
    source.contains("{4'd0, lc_s_fifo_write_pointer_3} == lc_pp_wrap3("),
  )
  assert_true(source.contains("lc_packet_fifo_pop_3 == lc_o_head_pop"))
  assert_true(source.contains("lc_packet_fifo_push_3 == lc_queue_admit"))
}

///|
test "packet owned collector emits original-premise locked induction tasks" {
  let artifacts = queue_packet_owned_artifacts()
  assert_eq(artifacts.length(), 5)
  for group in queue_packet_owned_groups() {
    guard artifacts.filter(artifact => artifact.path == group + ".sby")
      is [config] else {
      fail("one config per task")
    }
    assert_true(
      config.content.contains(
        "mode prove\ndepth 20\ntimeout 600\nmulticlock on\nexpect pass\n",
      ),
    )
    assert_true(config.content.contains("smtbmc bitwuzla\n"))
    assert_true(config.content.contains("logger -werror .*\n"))
  }
  if @env.get_env_var("LUNACHIP_PHASE6_PACKET_OWNED_INPUTS_PRINT") == Some("1") {
    for artifact in artifacts {
      println(
        "PACKET-OWNED-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-PACKET-OWNED-ARTIFACT \{artifact.path}")
    }
  }
}

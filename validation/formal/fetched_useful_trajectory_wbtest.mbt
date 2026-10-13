///|
// The common public byte image from fetched_useful_host_source. No owner,
// engine state or private observation participates in its address decoder.
fn fetched_useful_native_data(address : UInt64) -> UInt64 raise {
  if address < 128UL {
    let packet = fetched_useful_packet((address / 32UL).to_int())
    let offset = (address % 32UL).to_int()
    (packet[offset / 8] >> (offset % 8 * 8)) & 255UL
  } else {
    match address {
      256UL => 253UL
      257UL => 7UL
      512UL => 5UL
      513UL => 254UL
      _ => 0UL
    }
  }
}

///|
priv struct FetchedUsefulNativeRequest {
  tag : UInt64
  address : UInt64
  write : Bool
  bytes : UInt64
  mask : UInt64
  data : UInt64
}

///|
test "full fetched useful public host reaches owned numeric Store and four ordinal retirements within original horizon" {
  let design = flux_tile_formal_design()
  assert_eq(
    sha256_hex(@ir_codec.serialize(design)),
    "d47c7cccaa7dc7d8021b0fabc6a4eb7d4977bb53c1c5fa06416bbbb5e531cf79",
  )
  guard design.top_module() is Some(hardware) else { fail("full fetched top") }
  let simulator = @sim.Simulator::prepare(hardware)
  let inputs = hardware
    .nodes()
    .filter_map(node => {
      match node.kind() {
        Input(name) if name != "clock" =>
          Some((name, node.signal_type().width().bits(), node.id()))
        _ => None
      }
    })
  assert_eq(inputs.length(), 12)
  for (name, width, _) in inputs {
    records_put(simulator, name, width, 0UL)
  }
  let pre_inputs = StringBuilder()
  let pre_outputs = StringBuilder()
  let transactions = StringBuilder()
  let descriptor_acks = Array::make(128, false)
  let operand_acks = Array::make(4, false)
  let mut config_seen = false
  let mut publish_seen = false
  let mut owned : FetchedUsefulNativeRequest? = None
  let mut reads = 0
  let mut read_acks = 0
  let mut writes = 0
  let mut write_acks = 0
  let mut retirements = 0
  let mut witness_edge = -1
  for edge in 0..<512 {
    let reset = edge == 0
    records_put(simulator, "reset", 1, if reset { 1UL } else { 0UL })
    records_put(
      simulator,
      "config_valid",
      1,
      if !reset && !config_seen {
        1UL
      } else {
        0UL
      },
    )
    records_put(simulator, "config_base", 32, 0UL)
    records_put(simulator, "config_origin", 32, 0UL)
    records_put(
      simulator,
      "publish_valid",
      1,
      if !reset && config_seen && !publish_seen {
        1UL
      } else {
        0UL
      },
    )
    records_put(simulator, "publish_producer", 32, 4UL)
    records_put(simulator, "memory_request_ready", 1, 1UL)
    records_put(simulator, "completion_ready", 1, 1UL)
    records_put(
      simulator,
      "memory_response_valid",
      1,
      if owned is Some(_) && !reset {
        1UL
      } else {
        0UL
      },
    )
    records_put(simulator, "memory_response_fault", 2, 0UL)
    records_put(
      simulator,
      "memory_response_tag",
      32,
      owned.map(r => r.tag).unwrap_or(0UL),
    )
    records_put(
      simulator,
      "memory_response_data",
      32,
      match owned {
        Some(r) =>
          if r.write {
            0UL
          } else {
            fetched_useful_native_data(r.address)
          }
        None => 0UL
      },
    )
    simulator.settle()
    for (name, _, node) in inputs {
      let value = simulator.value(node)
      assert_true(value.is_fully_known())
      pre_inputs.write_string("PRE \{edge} \{name} \{value.to_bit_string()}\n")
    }
    for output in hardware.outputs() {
      pre_outputs.write_string(
        "PRE \{edge} \{output.name()} \{simulator.output(output.name()).to_bit_string()}\n",
      )
    }
    if reset {
      for
        name in [
          "config_ready", "publish_ready", "memory_request_valid", "memory_response_ready",
          "completion_valid",
        ] {
        assert_eq(records_output(simulator, name), 0UL)
      }
    } else {
      for name in ["ring_fault_valid", "transport_halted", "halted"] {
        assert_eq(records_output(simulator, name), 0UL)
      }
      let request = records_output(simulator, "memory_request_valid") == 1UL
      let response = owned is Some(_) &&
        records_output(simulator, "memory_response_ready") == 1UL
      assert_false(request && response)
      // Host availability never assumes DUT response readiness. Its actual
      // readiness and genuine saved ownership are checked here instead.
      if records_output(simulator, "memory_response_ready") == 1UL {
        assert_true(owned is Some(_))
      }
      if !config_seen && records_output(simulator, "config_ready") == 1UL {
        config_seen = true
      } else if config_seen &&
        !publish_seen &&
        records_output(simulator, "publish_ready") == 1UL {
        publish_seen = true
      }
      if request {
        assert_true(owned is None)
        let r : FetchedUsefulNativeRequest = {
          tag: records_output(simulator, "memory_request_tag"),
          address: records_output(simulator, "memory_request_address"),
          write: records_output(simulator, "memory_request_write") == 1UL,
          bytes: records_output(simulator, "memory_request_bytes"),
          mask: records_output(simulator, "memory_request_mask"),
          data: records_output(simulator, "memory_request_data"),
        }
        assert_true(r.address + r.bytes <= 1024UL)
        if r.write {
          assert_eq(
            (r.address, r.bytes, r.mask, r.data),
            (768UL, 4UL, 15UL, 4294967267UL),
          )
          assert_eq(writes, 0)
          writes += 1
        } else {
          assert_eq((r.bytes, r.mask, r.data), (1UL, 1UL, 0UL))
          assert_true(
            r.address < 128UL ||
            [256UL, 257UL, 512UL, 513UL].contains(r.address),
          )
          assert_true(reads < 132)
          reads += 1
        }
        transactions.write_string(
          "REQUEST \{edge} tag=\{r.tag} write=\{r.write} address=\{r.address} bytes=\{r.bytes} mask=\{r.mask} data=\{r.data}\n",
        )
        owned = Some(r)
      } else if response && owned is Some(r) {
        if r.write {
          assert_eq((writes, write_acks), (1, 0))
          write_acks += 1
        } else {
          assert_true(read_acks < reads)
          read_acks += 1
          if r.address < 128UL {
            assert_false(descriptor_acks[r.address.to_int()])
            descriptor_acks[r.address.to_int()] = true
          } else {
            let index = [256UL, 257UL, 512UL, 513UL].search(r.address).unwrap()
            assert_false(operand_acks[index])
            operand_acks[index] = true
          }
        }
        transactions.write_string(
          "ACK \{edge} tag=\{r.tag} write=\{r.write} address=\{r.address}\n",
        )
        owned = None
      }
      if records_output(simulator, "completion_valid") == 1UL {
        assert_true(retirements < 4)
        let progress = if retirements < 2 {
          2UL
        } else if retirements == 2 {
          0UL
        } else {
          4UL
        }
        assert_eq(records_output(simulator, "completion_id"), 73UL)
        assert_eq(records_output(simulator, "completion_fault"), 0UL)
        assert_eq(
          records_output(simulator, "completion_bytes_completed"),
          progress,
        )
        assert_eq(records_output(simulator, "completion_fault_address"), 0UL)
        transactions.write_string(
          "RETIRE \{edge} ordinal=\{retirements} id=73 fault=0 progress=\{progress} address=0\n",
        )
        retirements += 1
      } else if retirements == 4 {
        assert_eq((reads, read_acks, writes, write_acks), (132, 132, 1, 1))
        assert_true(descriptor_acks.all(value => value))
        assert_true(operand_acks.all(value => value))
        assert_true(owned is None)
        assert_eq(records_output(simulator, "configured"), 1UL)
        assert_eq(records_output(simulator, "producer_count"), 4UL)
        assert_eq(records_output(simulator, "consumer_count"), 4UL)
        witness_edge = edge
        break
      }
    }
    simulator.rising_edge("clock")
  }
  assert_true(witness_edge > 0 && witness_edge < 512)
  let summary = "WITNESS-PRE-EDGE \{witness_edge}\nREAD-ACCEPTS 132\nREAD-ACKS 132\nDISTINCT-DESCRIPTOR-ACKS 128\nDISTINCT-OPERAND-ACKS 4\nWRITE-ACCEPTS 1\nWRITE-ACKS 1\nORDINAL-RETIREMENTS 4\nSTORE address768 bytes4 mask15 word4294967267 signed-minus29\nCLAIM native-trajectory-only-no-formal-or-RTL-pass\n"
  if @env.get_env_var("LUNACHIP_PHASE6_FETCHED_TRAJECTORY_PRINT") == Some("1") {
    for
      (path, content) in [
        ("inputs.txt", pre_inputs.to_string()),
        ("outputs.txt", pre_outputs.to_string()),
        ("transactions.txt", transactions.to_string()),
        ("trajectory.txt", summary),
      ] {
      println(
        "FETCHED-TRAJECTORY-ARTIFACT \{path} sha256 \{sha256_hex(content)}",
      )
      println(content)
      println("END-FETCHED-TRAJECTORY-ARTIFACT \{path}")
    }
  }
}

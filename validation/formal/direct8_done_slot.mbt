///|
let direct8_done_slot_id : String = direct8_done_core_id + "-pending-slot"

///|
let direct8_latency_done_slot_id : String = direct8_latency_done_id +
  "-pending-slot"

///|
fn direct8_done_slot_binding(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueueControlAlias raise {
  let source = fixture.hardware()
  let owners = direct8_engine_owner_bindings(
    fixture,
    direct8_arbiter_probe(fixture),
  )
  let find = name => {
    guard owners.filter(item => item.name == name) is [item] else {
      fail("Done slot: original owner binding")
    }
    item.node
  }
  let accepted = find("o_read_accept")
  let slot = find("o_store_slot")
  let response = fetched_transport_unique(
    source,
    "original held result read slot",
    node => {
      if node.signal_type() != @wire.uint(1) || !(node.kind() is Register(_)) {
        return false
      }
      let (event, input) = fetched_safety_latch(source, node.id()) catch {
        _ => return false
      }
      event == accepted && input == slot
    },
  )
  { name: "d_response_slot", node: response, signal_type: @wire.uint(1), }
}

///|
fn direct8_done_slot_source() -> String {
  (
    #|  wire lc_d8d_pending_slot = lc_g_reset || !lc_g_o_pending || lc_g_d_response_slot == lc_g_o_store_slot;
    #|
  )
}

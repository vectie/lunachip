///|
test "Store supporting inputs retain canonical storage and isolated payload sensitivity" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let before = @ir_codec.serialize(
    @ir.Design::single("Original", fixture.hardware()),
  )
  let inputs = store_preservation_proof_inputs(fixture)
  let repeated = store_preservation_proof_inputs(fixture)
  assert_eq(inputs.positive, repeated.positive)
  assert_eq(inputs.negative, repeated.negative)
  assert_eq(inputs.properties, repeated.properties)
  assert_eq(
    @ir_codec.serialize(@ir.Design::single("Original", fixture.hardware())),
    before,
  )
  assert_eq(inputs.projection.plan.arithmetic.length(), 4)
  assert_eq(inputs.projection.hardware.memories().length(), 6)
  assert_eq(inputs.memory_bounds.length(), 12)
  assert_eq(inputs.global_assertions, ["lc_store_nonrising_hold"])
  let properties = inputs.properties.properties()
  assert_eq(
    properties.filter(property => property.kind() is Assumption).length(),
    1,
  )
  assert_eq(
    properties.filter(property => property.kind() is Assertion).length(),
    6,
  )
  assert_eq(properties.filter(property => property.kind() is Cover).length(), 1)
  assert_eq(properties[0].source_name(), "startup_reset")
  let mutation = "(lc_e_ResponseData ^ (lc_genuine_held_overlap ? 32'd1 : 32'd0))"
  assert_eq(inputs.negative.split(mutation).count(), 2)
  assert_eq(
    inputs.negative.replace(old=mutation, new="lc_e_ResponseData"),
    inputs.positive,
  )
  assert_true(!inputs.positive.contains("lc_dut."))
  assert_true(inputs.positive.contains("module " + inputs.top_identifier + ";"))
  let cuts = inputs.projection.hardware
    .nodes()
    .filter(node => node.kind() is Input(_))
  assert_eq(
    inputs.positive.split("(* anyseq *)").count() - 1,
    cuts.length() - 1,
  )
  for label in inputs.memory_bounds {
    assert_eq(inputs.positive.split(label + ": assert").count(), 2)
    assert_eq(inputs.negative.split(label + ": assert").count(), 2)
  }
  for property in properties {
    assert_true(inputs.positive.contains(property.stable_name() + ":"))
  }
  let producers = store_preservation_producers(inputs.projection)
  assert_eq(producers.length(), 4)
  for producer in producers {
    assert_true(
      inputs.projection.plan.arithmetic.any(cut => cut.id() == producer),
    )
  }
  let names = store_preservation_memory_identifiers(
    inputs.projection,
    inputs.emitted,
  )
  assert_eq(names.length(), 6)
  for name in names {
    assert_true(inputs.positive.contains(name + "[0]"))
  }
}

///|
test "Store observer supports all legal rectangle masks and real pregrant read drain" {
  let source = store_preservation_production_source() +
    store_preservation_control_source() +
    store_preservation_transfer_source(false)
  for
    line in [
      "8'h11: lc_rectangle_mask = 4'b0001;", "8'h12: lc_rectangle_mask = 4'b0011;",
      "8'h21: lc_rectangle_mask = 4'b0101;", "8'h22: lc_rectangle_mask = 4'b1111;",
      "lc_e_SlottedLegalAccept && lc_o_compute_C ==", "lc_e_Capture && lc_o_slotted_ActiveC ==",
      "lc_o_store_State == 3'd3 || lc_o_store_State == 3'd4", "lc_arb_state == 2'd2 && !lc_arb_owner",
      "lc_g_opposite_intermediate && lc_opposite_capture && lc_e_FinalCapture", "lc_g_read_active && !lc_core_response_ready",
      "lc_g_word_0_0 <= lc_produced_word", "lc_g_read_word <= lc_expected_read_word",
      "lc_g_dma_word <= lc_g_read_word",
    ] {
    assert_true(source.contains(line))
  }
  assert_true(!source.contains("lc_g_word_0_0 <= 32'd0"))
  assert_true(!source.contains("lc_g_read_word <= lc_e_ResponseData"))
  assert_true(!source.contains("lc_g_dma_word <= lc_arb_data"))
  assert_true(!source.contains("lc_g_word_0_0 ="))
}

///|
test "Store overlap history is one read and one opposite generation before real grant" {
  let source = store_preservation_transfer_source(false)
  let new_read =
    #|      end else if (lc_e_ReadAccept) begin
    #|        // A new word cannot inherit an earlier read's hold/capture history.
    #|        lc_g_read_seen <= lc_g_store_seen;
    #|        lc_g_pregrant_seen <= 1'b0;
    #|        lc_g_opposite_intermediate <= 1'b0;
    #|        lc_g_opposite_final <= 1'b0;
    #|        lc_g_grant_seen <= 1'b0;
    #|        lc_g_write_seen <= 1'b0;
    #|        lc_g_ack_seen <= 1'b0;
    #|        lc_g_opposite_generation_live <= lc_e_SlottedLegalAccept
    #|          && lc_o_compute_C != lc_o_store_Slot;
    #|        // The Store-epoch completed witness intentionally survives here.
    #|
  assert_true(source.contains(new_read))
  let new_generation =
    #|        if (lc_e_SlottedLegalAccept) begin
    #|          // Restart unfinished overlap at ONE actual accepted generation.
    #|          lc_g_opposite_generation_live <= lc_g_read_active && !lc_core_response_ready
    #|            && !lc_g_grant_seen && lc_o_compute_C != lc_g_read_slot;
    #|          if (!lc_g_grant_seen) begin
    #|            lc_g_opposite_intermediate <= 1'b0;
    #|            lc_g_opposite_final <= 1'b0;
    #|          end
    #|        end else begin
    #|
  assert_true(source.contains(new_generation))
  for
    line in [
      "lc_read_episode_identity && !lc_core_response_ready", "lc_pregrant_hold && lc_g_opposite_generation_live",
      "!lc_e_SlottedLegalAccept && lc_e_Capture && lc_o_slotted_ActiveC != lc_g_read_slot",
      "lc_o_store_Id == lc_g_read_id && lc_o_store_Slot == lc_g_read_slot", "lc_indexed_read_address == lc_g_read_address",
      "lc_o_slotted_ResponseSlot == lc_g_read_slot", "lc_g_read_seen && lc_g_pregrant_seen && lc_g_opposite_generation_live",
      "lc_g_opposite_intermediate && lc_g_opposite_final && !lc_e_SlottedLegalAccept",
      "lc_g_opposite_generation_live && lc_g_opposite_final", "lc_read_episode_identity && lc_store_grant) lc_g_grant_seen <= 1'b1;",
    ] {
    assert_true(source.contains(line))
  }
  let completion =
    #|        if (lc_g_grant_seen && lc_g_write_seen && lc_e_StoreResponseGood) begin
    #|          lc_g_ack_seen <= 1'b1;
    #|          lc_g_completed_overlap <= 1'b1;
    #|        end
    #|
  assert_true(source.contains(completion))
  // Exactly reset and new Store clear this sticky witness, never a later read.
  assert_eq(source.split("lc_g_completed_overlap <= 1'b0;").count(), 3)
  assert_eq(source.split("lc_g_completed_overlap <= 1'b1;").count(), 2)
  let rectangle_completion =
    #|  wire lc_coherent_store_overlap = lc_seen_edge && !lc_reset && lc_g_store_seen
    #|    && lc_g_completed_overlap
    #|    && lc_o_store_State == 3'd4 && lc_o_store_Fault == 0
    #|    && lc_o_store_Rows == 13'd2 && lc_o_store_Columns == 13'd2 && lc_o_store_Progress == 32'd16;
    #|
  assert_true(source.contains(rectangle_completion))
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let projection = store_storage_projection(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single("StoreStorageProjection", projection.hardware),
  )
  let retention = store_preservation_retention_source(projection, emitted)
  assert_true(
    retention.contains(
      "!lc_g_opposite_generation_live && !lc_g_completed_overlap;",
    ),
  )
  let negative = store_preservation_transfer_source(true)
  assert_eq(
    negative.replace(
      old="(lc_e_ResponseData ^ (lc_genuine_held_overlap ? 32'd1 : 32'd0))",
      new="lc_e_ResponseData",
    ),
    source,
  )
}

///|
test "Store proof source rejects complete projection mapping and emission drift" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let projection = store_storage_projection(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single("StoreStorageProjection", projection.hardware),
  )
  let mapping = projection.original_to_local.iter().to_array()
  mapping[projection.plan.probe.clock.ordinal()] = None
  let altered = {
    ..projection,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
  try store_preservation_proof_source(fixture, altered, emitted) catch {
    InvalidFormalBundleIdentity(_) => ()
    error => fail("unexpected source rejection \{Repr(error)}")
  } noraise {
    _ => fail("accepted changed complete original-to-local mapping")
  }
  let renamed = @ir.Module::checked_with_memories(
    "OtherStoreProjection",
    projection.hardware.nodes(),
    projection.hardware.memories(),
    projection.hardware.outputs(),
  )
  let other_emission = @rtl.emit_design(
    @ir.Design::single("OtherStoreProjection", renamed),
  )
  try
    store_preservation_proof_source(fixture, projection, other_emission)
  catch {
    InvalidFormalBundleIdentity(_) => ()
    error => fail("unexpected emission rejection \{Repr(error)}")
  } noraise {
    _ => fail("accepted unrelated canonical emission")
  }
}

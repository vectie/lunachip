///|
fn async_fifo_monitor_artifact(
  bundle : AsyncFifoFormalBundle,
  path : String,
) -> String raise {
  for artifact in bundle.artifacts() {
    if artifact.path() == path {
      return artifact.content()
    }
  }
  fail("missing monitor artifact \{path}")
}

///|
test "asynchronous FIFO monitor emits one watched-token scoreboard only" {
  let destination_monitor =
    #|    if (lc_destination_event) begin
    #|      if (lc_model_occupancy == 0) lc_ordering_error <= 1'b1;
    #|      if (lc_watch_active) begin
    #|        if (lc_watch_remaining == 0) lc_ordering_error <= 1'b1;
    #|        else if (lc_watch_remaining == 1) begin if (lc_read_address != lc_watch_address) lc_ordering_error <= 1'b1; if (lc_monitored_destination_word != lc_watch_word) lc_data_error <= 1'b1; lc_watch_active <= 0; lc_cover_watch <= 1; end
    #|        else begin if (lc_read_address == lc_watch_address) lc_ordering_error <= 1'b1; lc_watch_remaining <= lc_watch_remaining - 1; end
    #|      end
    #|    end
    #|
  let source_monitor =
    #|    if (lc_source_event) begin
    #|      if (lc_scheduled_watch_select && !lc_watch_active) begin lc_watch_active <= 1; lc_watch_remaining <= lc_model_occupancy + (lc_destination_event ? 0 : 1); lc_watch_address <= lc_write_address; lc_watch_word <= lc_scheduled_source_word; lc_watch_age <= 0; end
    #|    end
    #|
  for
    fixture in [
      ValidAsyncFifo,
      BrokenAsyncFifoGray,
      BrokenAsyncFifoFull,
      BrokenAsyncFifoAddress,
      BrokenAsyncFifoStorageOrder,
      BrokenAsyncFifoReadPipeline,
      BrokenAsyncFifoWritePipeline,
      BrokenAsyncFifoWriteAddressBounds,
      BrokenAsyncFifoReadAddressBounds,
    ] {
    let harness = async_fifo_monitor_artifact(
      generate_async_fifo_formal_bundle(fixture),
      "formal-harness.sv",
    )
    assert_false(harness.contains("lc_model_storage"))
    assert_false(harness.contains("lc_model_write"))
    assert_false(harness.contains("lc_model_read"))
    assert_eq(harness.split("logic [2:0] lc_model_occupancy = 0;").length(), 2)
    assert_eq(harness.split(destination_monitor).length(), 2)
    assert_eq(harness.split(source_monitor).length(), 2)
    assert_eq(
      harness
      .split(
        "case ({lc_source_event,lc_destination_event}) 2'b10: lc_model_occupancy <= lc_model_occupancy + 1; 2'b01: lc_model_occupancy <= lc_model_occupancy - 1; default: lc_model_occupancy <= lc_model_occupancy; endcase",
      )
      .length(),
      2,
    )
    assert_eq(
      harness.split("lc_watch_address <= lc_write_address;").length(),
      2,
    )
    assert_false(harness.contains("lc_watch_address <= lc_model_write"))
    assert_eq(
      harness
      .split(
        "if (lc_monitored_destination_word != lc_watch_word) lc_data_error <= 1'b1;",
      )
      .length(),
      2,
    )
  }
}

///|
struct AsyncFifoWatchModel {
  occupancy : Int
  active : Bool
  remaining : Int
  address : Int
  word : Int
  ordering_error : Bool
  data_error : Bool
  covered : Bool
} derive(Debug, Eq)

///|
fn async_fifo_watch_step(
  state : AsyncFifoWatchModel,
  source_event : Bool,
  destination_event : Bool,
  select : Bool,
  write_address : Int,
  source_word : Int,
  read_address : Int,
  destination_word : Int,
) -> AsyncFifoWatchModel {
  let mut active = state.active
  let mut remaining = state.remaining
  let mut address = state.address
  let mut word = state.word
  let mut ordering_error = state.ordering_error
  let mut data_error = state.data_error
  let mut covered = state.covered
  if destination_event {
    if state.occupancy == 0 {
      ordering_error = true
    }
    if state.active {
      if state.remaining == 0 {
        ordering_error = true
      } else if state.remaining == 1 {
        if read_address != state.address {
          ordering_error = true
        }
        if destination_word != state.word {
          data_error = true
        }
        active = false
        covered = true
      } else {
        if read_address == state.address {
          ordering_error = true
        }
        remaining = state.remaining - 1
      }
    }
  }
  if source_event && select && !state.active {
    active = true
    let enqueue_distance = if destination_event { 0 } else { 1 }
    remaining = state.occupancy + enqueue_distance
    address = write_address
    word = source_word
  }
  let occupancy = match (source_event, destination_event) {
    (true, false) => state.occupancy + 1
    (false, true) => state.occupancy - 1
    _ => state.occupancy
  }
  {
    occupancy,
    active,
    remaining,
    address,
    word,
    ordering_error,
    data_error,
    covered,
  }
}

///|
test "later watched token counts down before matching address and data" {
  let initial : AsyncFifoWatchModel = {
    occupancy: 2,
    active: false,
    remaining: 0,
    address: 0,
    word: 0,
    ordering_error: false,
    data_error: false,
    covered: false,
  }
  let selected = async_fifo_watch_step(
    initial, true, false, true, 2, 0xa5, 0, 0,
  )
  assert_eq(selected, {
    occupancy: 3,
    active: true,
    remaining: 3,
    address: 2,
    word: 0xa5,
    ordering_error: false,
    data_error: false,
    covered: false,
  })
  let first_earlier = async_fifo_watch_step(
    selected, false, true, false, 0, 0, 0, 0xff,
  )
  assert_eq(first_earlier.remaining, 2)
  assert_false(first_earlier.ordering_error)
  assert_false(first_earlier.data_error)
  let early_watched_address = async_fifo_watch_step(
    selected, false, true, false, 0, 0, 2, 0xff,
  )
  assert_true(early_watched_address.ordering_error)
  assert_false(early_watched_address.data_error)
  let second_earlier = async_fifo_watch_step(
    first_earlier, false, true, false, 0, 0, 1, 0x00,
  )
  assert_eq(second_earlier.remaining, 1)
  assert_false(second_earlier.ordering_error)
  assert_false(second_earlier.data_error)
  let matched = async_fifo_watch_step(
    second_earlier, false, true, false, 0, 0, 2, 0xa5,
  )
  assert_false(matched.active)
  assert_true(matched.covered)
  assert_false(matched.ordering_error)
  assert_false(matched.data_error)
  let wrong_address = async_fifo_watch_step(
    second_earlier, false, true, false, 0, 0, 1, 0xa5,
  )
  assert_true(wrong_address.ordering_error)
  assert_false(wrong_address.data_error)
  let wrong_word = async_fifo_watch_step(
    second_earlier, false, true, false, 0, 0, 2, 0x5a,
  )
  assert_false(wrong_word.ordering_error)
  assert_true(wrong_word.data_error)
  let simultaneous = async_fifo_watch_step(
    initial, true, true, true, 2, 0xa5, 0, 0,
  )
  assert_eq(simultaneous.occupancy, 2)
  assert_eq(simultaneous.remaining, 2)
}

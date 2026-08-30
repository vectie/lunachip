///|
struct AsyncFifoInitializationSample {
  protocol_active : Bool
  scheduled_source_valid : Bool
  requested_source_valid : Bool
} derive(Debug, Eq)

///|
fn AsyncFifoInitializationSample::strictly_allowed(
  self : AsyncFifoInitializationSample,
) -> Bool {
  self.protocol_active ||
  (!self.scheduled_source_valid && !self.requested_source_valid)
}

///|
fn AsyncFifoInitializationSample::captured_source_valid(
  self : AsyncFifoInitializationSample,
) -> Bool {
  self.requested_source_valid
}

///|
test "inactive initialization lookahead cannot schedule source valid" {
  for protocol_active in [false, true] {
    for scheduled_source_valid in [false, true] {
      for requested_source_valid in [false, true] {
        let sample : AsyncFifoInitializationSample = {
          protocol_active,
          scheduled_source_valid,
          requested_source_valid,
        }
        if !protocol_active && sample.strictly_allowed() {
          assert_false(sample.scheduled_source_valid)
          assert_false(sample.requested_source_valid)
          assert_false(sample.captured_source_valid())
        }
        if !protocol_active && requested_source_valid {
          assert_false(sample.strictly_allowed())
        }
      }
    }
  }
  let activation_boundary : AsyncFifoInitializationSample = {
    protocol_active: false,
    scheduled_source_valid: false,
    requested_source_valid: true,
  }
  assert_false(activation_boundary.strictly_allowed())
  assert_true(activation_boundary.captured_source_valid())
  let active_capture : AsyncFifoInitializationSample = {
    protocol_active: true,
    scheduled_source_valid: false,
    requested_source_valid: true,
  }
  assert_true(active_capture.strictly_allowed())
  assert_true(active_capture.captured_source_valid())
}

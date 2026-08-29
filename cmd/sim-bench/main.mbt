///|
extern "c" fn allocation_counter_start() -> Unit = "lunachip_allocation_counter_start"

///|
extern "c" fn allocation_counter_available() -> Bool = "lunachip_allocation_counter_available"

///|
extern "c" fn allocation_counter_stop() -> Unit = "lunachip_allocation_counter_stop"

///|
extern "c" fn allocation_calls() -> UInt64 = "lunachip_allocation_calls"

///|
extern "c" fn allocation_bytes() -> UInt64 = "lunachip_allocation_bytes"

///|
extern "c" fn malloc_calls() -> UInt64 = "lunachip_malloc_calls"

///|
extern "c" fn calloc_calls() -> UInt64 = "lunachip_calloc_calls"

///|
extern "c" fn realloc_calls() -> UInt64 = "lunachip_realloc_calls"

///|
extern "c" fn monotonic_nanoseconds() -> UInt64 = "lunachip_monotonic_nanoseconds"

///|
fn validate_allocation_counter() -> Unit raise {
  allocation_counter_start()
  let probe = Array::make(1024, 7)
  allocation_counter_stop()
  if allocation_calls() == 0UL {
    fail("allocation probe did not observe a known MoonBit heap allocation")
  }
  if probe[0] != 7 || probe[1023] != 7 {
    fail("allocation probe array was corrupted")
  }
}

///|
fn main raise {
  let stages = 48
  let warmup_iterations = 2000
  let measured_iterations = 20000
  let allocations_measured = allocation_counter_available()
  if allocations_measured {
    validate_allocation_counter()
  }
  let workload = @combinational.representative_workload(stages)
  let simulator = @sim.Simulator::prepare(workload.hardware_module())
  simulator.set_input("lhs", workload.lhs())
  simulator.set_input("rhs", workload.rhs())
  for _ in 0..<warmup_iterations {
    simulator.settle()
  }
  let warmup_result = simulator.output("result").to_uint64()
  if warmup_result != workload.expected() {
    fail("prepared workload disagreed with its independent oracle after warmup")
  }
  let started_at = monotonic_nanoseconds()
  if allocations_measured {
    allocation_counter_start()
  }
  for _ in 0..<measured_iterations {
    simulator.settle()
  }
  if allocations_measured {
    allocation_counter_stop()
  }
  let elapsed_nanoseconds = monotonic_nanoseconds() - started_at
  let result = simulator.output("result").to_uint64()
  if result != workload.expected() {
    fail(
      "prepared workload disagreed with its independent oracle after measurement",
    )
  }
  println("benchmark=lunawave_prepared_combinational_v1")
  println("stages=\{workload.stages()}")
  println("nodes=\{workload.nodes()}")
  println("warmup_iterations=\{warmup_iterations}")
  println("measured_iterations=\{measured_iterations}")
  println("elapsed_nanoseconds=\{elapsed_nanoseconds}")
  println("allocations_measured=\{allocations_measured}")
  println("allocation_calls=\{allocation_calls()}")
  println("allocation_bytes_requested=\{allocation_bytes()}")
  println("malloc_calls=\{malloc_calls()}")
  println("calloc_calls=\{calloc_calls()}")
  println("realloc_calls=\{realloc_calls()}")
  println("result=\{result}")
}

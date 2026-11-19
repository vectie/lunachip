///|
test "coalesced FP32 STORE uses checked two-beat bursts and commits argmax after B" {
  exercise_store_bursts(
    bench(
      streaming=true,
      profile=true,
      vectors=true,
      wide512=true,
      rows64=true,
      banked64=true,
      prefetch256=true,
      scalar_lines=true,
      store_bursts=true,
    ),
  )
}

# PRX100 complete-layer DDR overlap

This opt-in MoonBit generator, `overlapped_layer_machine`, retains the complete
layer descriptor ABI and four ordered BF16/FP32 lanes. The existing scalar,
four-lane serialized-staging generator, and integer accelerator remain available.

Two banks each contain four 32-word synchronous weight memories. A separate
loader requests and validates four 128-byte lines into its bank. Its states are
empty, requesting, receiving, and full; a stripe becomes readable only after
all 128 beats have arrived with the expected response status and LAST position.
Only one DDR line is outstanding. Request payload stays stable under backpressure.

At compute start, the loader begins the next 64-element stripe in the inactive
bank. The active bank supplies four weights and scratch supplies one broadcast
activation per edge. Three-stage FP32 multipliers feed separate ordered FP32
accumulators. All products drain before bank ownership changes. At a row-group
boundary, four scratch writes complete before the next group starts; staging
overlaps chunks within a group, not groups or descriptors.

The final chunk does not issue a speculative request. Every descriptor and warm
launch initializes bank ownership; reset invalidates all loader/pipeline state.
Response faults, malformed LAST, DDR-health loss and watchdog expiry remain
sticky terminal faults. Delayed compute tokens cannot leave a terminal state.
Request publication depends on registered loader ownership and reset. Returned
controller health gates arithmetic and triggers registered abort; it must not
gate request VALID combinationally, because the controller's health result
itself includes a checker of that request. The flattened core/controller system
must pass zero-SCC synthesis checks and strict physical DRC without a loop waiver.
The existing scalar fallback covers output/input aliasing and row counts not
divisible by four. Arithmetic and nonlinear approximations are unchanged.

`export-overlap`, `replay-overlap`, and `core-formal-overlap` select this profile.
Performance and physical execution claims require a separate measured evidence
report, including identical input/program identities and all stage/KV readbacks.

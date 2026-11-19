# ADR: PBlaze3 resident loader and controller composition

The 40 MHz PBlaze3 controller generator in `targets/pblaze3_layer/controller.mbt`
exceeds 800 lines. It binds one shared DDR owner, the AXI-Lite CSR map,
program staging, error handling, chain scheduling and counter snapshots. Retain
the established construction order during this board comparison: signal order
is part of the emitted design identity, and historical opt-in profiles must be
reproducible. This exception is limited to the composition function.

Keep the lane serializer and its counters in `program_burst.mbt`, the staging
state machine in `resident.mbt` and segment sequencing in `chain.mbt`. No
second instruction store is required for the burst mode. A future double-buffer
experiment needs a separate core memory design and an explicit arbitration
policy; it must not overwrite the bank supplying the active instruction.

The 2026-11-19 100 MHz MIG profiling change follows the same exception.
The observer and its counters live in `mig_monitor.mbt`; the controller only
publishes the existing ownership predicate through one source-domain register.
Append that register after the existing graph construction. The physical repair
checks that all 1,976 previous nodes remain identical and only the observation
output changes driver. This keeps the measured datapath's identity reviewable
without extending the composition function with a second profiling subsystem.

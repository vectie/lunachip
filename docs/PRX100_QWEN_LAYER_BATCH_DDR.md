# PRX100 complete-layer batched DDR transport

The opt-in `export-batch` profile combines the four strided weight-row reads
of one compute stripe into one source request. It selects
`@qwen_layer.batched_layer_machine()`, `@prx100_layer.batched_controller()` and
`@prx100_layer_ddr.batched_bridge()`. The preceding `export-wide` profile and
the integer accelerator retain their exact exported identities.

```sh
moon run --target native cmd/prx100_layer -- export-batch /absolute/new-inputs
```

An aligned read/line/burst request with `request_wide=1` uses bit 31 of its
otherwise unused read-data header to select four-row mode. Bits 27:0 carry the
byte stride; bits 30:28 must be zero. The stride is positive and a multiple of
128 bytes. The bridge validates the complete four-row extent in 30 bits before
issuing any native command, rejecting any extent outside the 256 MiB address
space. Unmarked reads and host word/write portals retain their formats.

One owner returns 32 ordered 128-bit packets: eight packets per row, in lane
order, with LAST only on packet 31. The core advances its destination lane
every eight packets and activates the stripe only after all four rows arrive.
The controller validates the whole owner's packet count. `ddr_beats` still
counts logical 32-bit words and store acknowledgements.

The bridge reserves eight native return slots per row, as before. It starts
the next row only after the preceding row's last packet has transferred into
the response FIFOs. It then reuses those slots with the next strided address,
without another source request or clock-domain request crossing. No buffer
slot can be recycled while a queued emitter still references it. Response FIFO
reservations, coordinated resets, fault poisoning and fault-suffix drainage
retain the native-width transport rules in
[the preceding contract](PRX100_QWEN_LAYER_WIDE_DDR.md).

The four arithmetic lanes, synchronous ReadOld/HoldLast weight memories,
ping-pong ownership, BF16 unpacking, separate FP32 round-to-nearest-even
multiply/add and per-row accumulation order retain their behavior. Matrix
shapes unsuitable for the four-lane path use the existing scalar fallback.

Qualification requires native checks, independent exact-production RTL
replays, named bounded formal tasks with complete sensitivity traces, pinned
digital synthesis, strict routed timing/DRC and a fresh CPU-verified full-layer
baseline/candidate campaign at the same clocks. Physical qualification and the fresh CPU-verified complete-layer campaign pass;
see [the measured evidence](evidence/prx100-layer-batch-20261019.md).

# PRX100 BF16/FP32 layer completion polling

This change is confined to the MoonBit host automation. The qualified
sixteen-lane streaming-DDR bitstream, both arithmetic cores, clocks, weights,
descriptors, transfer queues and CPU reference remain unchanged. Intermediates
and KV stay on the board. Only final hidden states return within resident
measurements.

`scripts/prx100-layer-poll.mbtx` accepts a digest-pinned legacy `io.tcl` and
emits the vendor backend with a selectable 1–100 ms completion wait. The
measured profile uses 2 ms instead of 100 ms. It retains the atomic status/error
read, immediate fault rejection, held-DONE check, counter validation and final
CPU comparison. Completion is checked before sleeping. The timeout uses a
600-second elapsed-time deadline instead of 6,000 iterations, so the shorter
wait does not shorten the supported workload duration. A vendor access can
still occupy its own transaction time.

The resident runner accepts an optional final `POLL_MS` argument. Omitting it
retains the original polling implementation for a matched baseline. Its
receipt records the cadence and exact emitted IO identity. The independent
resident audit reconstructs both approved IO variants and the complete vendor
campaign. An optional reviewed frozen driver reference permits auditing the
exact executed source; this task also proves its published counterpart differs
only by formatting.

The qualified policies are the omitted-argument legacy 100 ms baseline and the
explicit `2` profile. Other emitter intervals require separate qualification.

`scripts/prx100-layer-poll-test.mbtx` executes the actual emitted launch/poll
procedure against a deterministic vendor mock. Nine cases cover immediate
completion, ordinary completion, more than 6,000 polls, slow accesses, three
fault/status combinations, invalid completion counters and the 600-second
deadline. No real-time ten-minute wait is needed for the timeout regression.

The physical comparison uses five complete four-token layer samples, one
three-token prefill and five repeated cached position-3 decode samples per
profile. Resident end-to-end time includes launch, polling, status/error and
counters, final-output readback and CPU checking. Initial weight upload,
program installation, input integrity checks and full intermediate/KV
diagnostics are separately timed outside these samples. This is one complete
Qwen3-0.6B transformer layer, with context four and KV capacity eight.

The paired audit requires identical hardware qualification, vendor campaign,
workload and readback payloads, lower full-layer and cached-decode host latency,
and hardware kernel medians within 1%. Explicit polling sleeps overlap FPGA
execution; their sum is not an elapsed-time saving. The measured results and immutable evidence inventory follow.

## Physical measurement, 2026-10-19

| Median latency | 100 ms polling | 2 ms polling |
|---|---:|---:|
| Four-token resident layer | 890.1 ms | 796.6 ms |
| Cached position-3 resident decode | 276.8 ms | 219.9 ms |
| Four-token FPGA kernel | 648206.73 us | 648207.93 us |
| Cached decode FPGA kernel | 164041.41 us | 164040.96 us |

Full-layer resident latency falls **10.5%** and cached decode **20.6%**. Kernel time stays effectively unchanged, as expected for a host-only change. Five observations per workload/profile are retained; these are resident measurements, not cold weight upload or full-model generation.

All **845,696 FP32 words** across both physical campaigns pass CPU tolerance and are bit-exact to the ordered operation model. All346 cross-profile non-status/counter payload files are byte-identical. Maximum CPU absolute error is 0.000030517578125, and maximum timed final-output error is 0.00000286102294921875. Fresh CPU release execution reproduces all108 fixture binaries.

All1,264 strict native tests and nine polling regression cases pass. All1,419 module inputs, including199 protected integer inputs, are unchanged. The actual compiled Linux source inventory also remains unchanged before/after the native gates. The existing qualified image remains programmed in volatile FPGA memory; weights and KV are resident, DONE/idle/healthy with error0. Flash and host OS are unchanged.

Reproduce with the optional final `2` argument to `scripts/prx100-layer-resident-board.mbtx`, retaining the frozen runner and exact IO generator in the board evidence. Run the resident audit with the matching driver reference, then `scripts/prx100-layer-poll-audit.mbtx` for the paired comparison. The previous streaming-DDR image and its complete qualified evidence are inherited by exact bit/source/clock identities; no hardware rebuild or new RTL proof is claimed.

Evidence: [benchmark](../artifacts/prx100-layer-poll-20261019/benchmark.json), [raw campaigns and independent audits](../artifacts/prx100-layer-poll-20261019/work).

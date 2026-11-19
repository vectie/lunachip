# PRX100 sixteen-row matrix transfer experiment

The qualified short-nonlinear image spends approximately 313 ms of its
four-token segmented kernel profile in DDR-backed matrix sections. Sixteen
ordered BF16/FP32 row accumulators match the link's steady-state bandwidth,
but filling one ping-pong stripe still requires two separate eight-row DDR
owners. This experiment combines those into one sixteen-row owner.

The opt-in matched core/controller/bridge profile reserves all 128 native
return lines (512 words) before issuing the unstallable reads. It retains
ordered four-word responses, the original packet shape and host register ABI.
LAST moves to packet 127 for marked requests. All ordinary scalar and line
operations retain their existing shapes. The aligned full-header address
predicate uses an explicit 25-bit `address21 + 15*stride21` extent, with the
original alignment, reserved, shape and zero-stride checks retained.

Integer inputs, FP32 arithmetic primitives, sixteen arithmetic lanes, short
nonlinear schedule and original clocks must remain unchanged. The internal
diagnostic `observe_beat` grows from six to seven bits so packet 127 remains
observable. In the generated system and physical wrappers, only that diagnostic
wire width may change; every other byte and the source constraints must match.
Host register/descriptor encodings and physical board pins remain unchanged. Existing
generators must retain byte-identical outputs. Only matched components may
select the new fixed target transport semantics.

Before programming, require strict native checks, ordering/backpressure,
reset, health and fault regressions, actual RTL differential tests, pinned
digital synthesis, bounded core/controller/bridge safety checks with negative
calibration, full-header arithmetic equivalence and strict routed timing,
clock, DRC and active bus-skew qualification. A resource or timing failure is
retained as a failed attempt and never treated as permission to program.

The physical comparison must use a fresh qualified short-nonlinear baseline
and the candidate, identical programs and inputs, five resident full-layer
and five cached-decode samples per image, and actual CPU comparisons. Launch,
polling, counters, final output reads, file writes and CPU checks remain in
the end-to-end timer. Upload, program switching, integrity and full diagnostics
remain separate. Preserve every observation and failed attempt. This remains
one fixed Qwen3-0.6B layer at context four, not full-model inference.

The matched profile passes physical and numerical qualification.

| Median resident end-to-end | Fresh eight-row baseline | Sixteen-row owner | Reduction |
|---|---:|---:|---:|
| Complete four-token layer | 559.188 ms | 530.673 ms | 5.10% |
| Cached position-3 decode | 157.923 ms | 158.436 ms | -0.32% |

The opt-in matched MoonBit core/controller/bridge replaces two eight-row owners with one sixteen-row DDR owner per matrix stripe, retaining sixteen ordered BF16/FP32 lanes, identical arithmetic and clocks. Fresh resident full-layer latency improves from **559.188 to 530.673 ms** (5.10%), while cached position-3 decode rises from **157.923 to 158.436 ms** (0.32% slower). Its FPGA kernel nevertheless improves 6.17%; recorded host/control/readback overhead offsets that saving. Timers include launch, completion, actual final-output reads, file writes and CPU checks; upload, program switching, integrity sweeps and full diagnostics remain separate. All 845,696 paired FP32 words pass CPU tolerance and match the ordered model bit for bit. All 199 integer inputs and FP arithmetic primitives remain unchanged. Only the internal observe_beat width changes from six to seven bits in each wrapper; all other wrapper bytes, source XDC, host ABI and pins remain exact. All 1,284 strict native tests, fresh RTL replays, zero-SCC composition, core/controller 48-frame safety, all 83 bridge assertions over 128 global frames, 64-bit header equivalence and complete negative calibrations pass. Strict route, clock, DRC and all 12 bus-skew gates pass; setup/hold slack is +0.130/+0.001 ns. The 1,432-input source cohorts preserve 479 pre-existing Mac/Linux variants; all 27 changed inputs and 15 selected canonical/emitted files match across hosts. [Measured evidence](../artifacts/prx100-layer-sixteen-row-20261021/report.md) retains all observations and attempts. This is one fixed complete layer 0 at context four and cached decode; full-model inference and Phase 7/8 closure remain open.


## Reproduction

Use the pinned Linux native toolchain recorded in the evidence. The opt-in export and replay commands are:

```sh
moon run --target native cmd/prx100_layer -- export-sixteen-row /new/inputs
moon run --target native cmd/prx100_layer -- replay-sixteen-row /new/core-replay
moon run --target native cmd/prx100_layer -- bridge-replay-sixteen-row /new/bridge-replay
```

The sealed evidence's recorded drivers preserve exact source/tool pins and fresh native, digital, formal, CAD and physical invocations. `prx100-layer-matrix-proof-a3-20261021.mbtx` records all17jobs and83property coverage;`prx100-layer-matrix-controller-bound-20261021.mbtx` records the32to48controller bound extension before controller launch. The physical hold-repair driver changes routes on exactly three nets without changing RTL or timing constraints. `prx100-layer-matrix-qualify-a2-20261021.mbtx` checks the complete selected image before programming. The resident and108section profile drivers preserve identical programs,inputs and2ms/queue16hostpolicy. Run the independent `scripts/prx100-layer-resident-audit.mbtx` for each complete board campaign, then `scripts/prx100-layer-sixteen-row-audit.mbtx` for the paired comparison. All output paths must be fresh;sealed archives are immutable.

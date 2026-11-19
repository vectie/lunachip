# PRX100 queued-read finish profiling and scan decoding

The `prx100-fpz` host path compares the preceding FPY fixed-width slicing
decoder (`prior`) with a validated fixed-width Tcl `scan` decoder (`scan`).
Both use the unchanged FPDDR1.3Q bitstream, 30 MHz JTAG, depth16 queues,
buffered operand traces, batched completed-result DATA properties and the
same coalesced 106-projection workload. Integer and FP hardware remain unchanged.

The preceding `queues.tsv` finish interval included response status, DATA
property fetching, decoding and trace/list handling. It could not distinguish
those costs. `read-finish.tsv` now partitions every command-group finish
interval into `status_us`, `data_us`, `decode_us` and residual `other_us`.
Their sum must equal both `total_us` and the matching queue finish interval.
Residual time includes trace construction/writes, list handling and timer
overhead. The new profile record is written after that interval; its cost
remains inside the outer batch/application timers. Both profiles have the
same instrumentation, and all raw observations are retained.

The prior decoder tries underscore splitting, normalizes DATA and validates
its width/hexadecimal characters, then slices one eight-character word per
Tcl loop iteration. The new decoder first validates compact DATA directly.
It normalizes underscores/ASCII whitespace only when necessary, validates
the requested width and hexadecimal character set, then uses a cached
`%8s` format per burst length. Tcl `scan` produces all fixed-width strings
in one operation. The returned count must equal the requested count; the
list is reversed into increasing-address order and letter case is normalized.
Using string conversion preserves leading zeros and avoids numeric conversion.
Both paths reject burst lengths outside 1–256. The format cache is bounded
by that explicit burst limit.

The portable integer core, BF16/FP32 arithmetic, controller, bridge, memory
layout, clocks and all physical transactions remain unchanged. Every campaign
still checks 848 actual DDR outputs and all 374 diagnostic counter words
across 11 physical batches. Complete poison/model-before/model-after operand
readbacks, boundary guards, invalid-access checks, cache invalidation,
launch/poll/error handling and DONE-before-result ordering remain. Group
responses retain their preceding final-response visibility.

`scripts/prx100-fpz-data.mbtx` emits the decoder/profile Tcl consumed by the
board driver. Each run retains that generator, its exact emitted Tcl and
their receipt hashes alongside the exact driver and raw readings. The
independent `prx100-fpz-finish.mbtx` validator checks all 21 group partitions,
complete group coverage, policy counts for all 89 decoded DATA values,
source hashes and bindings to the independent CPU and group audits.

Run in the pinned guest with a fresh root:

```
moon run /work/prx100-fpz-board.mbtx -- run \
  /work/builds/prx100-fpq-vivado-20261018-hold-a2 \
  /work/builds/prx100-fpp-jobs-20261017.json \
  /work/builds/prx100-fpq-qualification-20261018-a1.json \
  /work/builds/prx100-fpz-board-NEW 30000000 coalesced buffered scan
```

The data generator must also be present at `/work/prx100-fpz-data.mbtx`.
Use `prior` for the comparison. Run `prx100-fpz` audit, groups, metrics,
policy, launches, warm, bulk and finish validators, then close the owned
hardware server with `prx100-fpz-close.mbtx`.

The [measurement report](evidence/prx100-fpz-20261018.md) distinguishes
diagnostic pilots, fresh interleaved primary measurements, isolated decoder
benchmarks and inherited hardware qualification. Historical aggregate logs
cannot retroactively prove the precise cause of the earlier finish-time
variation; fresh phase profiles establish where current time is spent.

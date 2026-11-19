# PRX100 JTAG polling and diagnostic evidence reuse

`scripts/prx100-fps-board.mbtx` reduces host round trips on the existing
FPDDR1.3Q bitstream. Integer and floating-point hardware, canonical IR,
emitted RTL, vendor IP, clocks and DDR layout are unchanged. The new driver
compares three profiles with the same fixture and checks:

| Profile | Prelaunch cache evidence | Polling |
| --- | --- | --- |
| `compact` | Existing singleton cache read before each batch | Existing status/error burst loop |
| `certified` | Reuse the latest verified completed counter snapshot when valid | Same burst loop |
| `paced` | Same counter-evidence reuse | Bounded delay after START, then the same burst loop |

All profiles reuse unchanged descriptors, use 30 MHz JTAG with depth-16 DDR
queues, and read every output and all 34 counter words after observed DONE.
The same BF16/FP32 Qwen3-0.6B layer-0 q_proj channels 0–7, K=1024 and three
embedding-derived vectors remain the workload. Prefixes, repeated runs,
warm/cold cache, 1/18/48-job batches, complement poison, full operand
readbacks, guard words and error checks remain part of qualification.

## Reusing checked cache evidence

The full completed-job snapshot at byte addresses 48–180 includes cache-valid
at byte address 108. After validating the complete snapshot, every output and
error=0, the host records its raw transaction sequence as a cache certificate.
It can replace the next singleton cache read while the target is exclusively
owned and no invalidating operation occurs. Descriptor writes do not invalidate
the cached weights. DDR writes, writes spanning START/invalidate or base
registers, and a new START revoke the certificate. A new completed, fully checked
snapshot is required before issuing another certificate.

The first cold batch and the batch following explicit invalidation still read
cache-valid directly. The campaign therefore changes sixteen singleton cache
reads to two, with fourteen decisions backed by the latest completed counter
read. It does not omit the cache word, counters, results or error checks.
`cache-evidence.tsv` records the exact source sequence and observed value for
each prelaunch decision. The independent policy auditor reconstructs all
invalidations and rejects an old or invalidated certificate.

## Scheduling the first poll

After acknowledged START, the paced profile estimates a useful delay from
known arithmetic work and the previous measured complete status-poll round trip:

```
work_us = jobs * (4*K + 4) / 50
delay_ms = clamp(truncate((work_us - previous_poll_us/2) / 1000), 0, 10)
```

The first batch, without a prior round trip, uses zero delay. Short batches
normally use zero; the full 48-job batch normally requests about two milliseconds.
`polling.tsv` records the prior/final poll durations, START duration, requested
and actual delay, and number of polls. The wall timer starts before configuration
and includes the entire delay. Pacing is a scheduling heuristic, not a completion
deadline or correctness assumption: observed DONE=5 and error=0 remain mandatory,
with the original bounded poll loop and full output/counter validation.

The independent policy auditor checks the round-trip chain, delay formula,
bounds, included timing and number of raw status polls. The CPU, group and
phase-timing auditors are separate. Their receipts must agree byte for byte
between Linux and macOS. Queued DDR responses retain their existing limitation:
`GROUP_OKAY` records the observed final group response, not every request's
individual AXI response. Full content checks remain required.

## Reproduction and evidence

Run the board driver in the isolated Linux environment with:

```
moon run /work/prx100-fps-board.mbtx -- run \
  /work/builds/prx100-fpq-vivado-20261018-hold-a2 \
  /work/builds/prx100-fpp-jobs-20261017.json \
  /work/builds/prx100-fpq-qualification-20261018-a1.json \
  /work/builds/prx100-fps-board-NEW 30000000 paced
```

Use a fresh root and the pinned Vivado/MoonBit environment. The driver validates
source and bitstream hashes, part/IDCODE, CPU_TAG cable, runtime queue depths,
JTAG frequency and configuration DONE/CRC. The separate `fps-audit`, `fps-groups`,
`fps-metrics`, `fps-policy` and `fps-close` `.mbtx` scripts perform independent
checks and close only the hardware server owned by that run. Programming is
volatile; flash is unchanged.

Measured results and limitations are in
`docs/evidence/prx100-fps-20261018.md`. This remains a selected projection
experiment rather than full-model inference.

The subsequent [result-readback profile](PRX100_JTAG_RESULT_READBACK.md) retains
this cache/polling path and combines full DDR result and counter reads in one
post-completion command. Its selected sequential-list dispatch retains every
output and counter word while removing a command per batch.

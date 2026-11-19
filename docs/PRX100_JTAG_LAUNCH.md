# PRX100 sequential launch and first-poll dispatch

This host-only experiment uses the qualified FPDDR1.3Q bitstream from
`prx100-fpq-vivado-20261018-hold-a2` at 30 MHz JTAG, with 16-entry DDR queues,
50 MHz arithmetic and 100 MHz DDR UI. It changes no MoonBit hardware generator,
canonical IR, emitted RTL, integer core, register map or flash contents.

`scripts/prx100-fpu-board.mbtx` supports three profiles:

| Profile | Launch command | First status/error read |
| --- | --- | --- |
| `list` | Separate changed descriptor and START commands | Separate, with preceding bounded pacing |
| `launch` | Optional changed descriptor then START in one sequential list | Separate, with preceding bounded pacing |
| `joined` | Optional changed descriptor then START; append status/error for batches below 48 jobs | Included for short batches; separate and paced for 48 jobs |

All profiles use the preceding full result/counter sequential-list readback,
descriptor reuse, transaction-object reuse and cache-certificate policy. This
is one synchronous `run_hw_axi $txns` command with transactions submitted in
order. It does not use mixed-direction `-queue`, whose independent read/write
FIFO ordering would require a separate contract. The qualified Vivado 2025.2
CLI help retained by the preceding result-readback experiment specifies that
nonqueued transactions run as submitted. No `-quiet` suppresses command errors.

The launch helper accepts only a driver-generated valid descriptor, START=1
and an optional two-word status/error read at address 8. It never reads across
write-only or invalid MMIO gaps. Descriptor publication precedes START, and
START precedes the included poll. The final write response and, when present,
final read response must both be OKAY. Those are direction-level responses;
individual descriptor response visibility is not claimed. Every write object's
DATA, read DATA shape, actual output and completion counter is checked.

If the included poll is busy, the ordinary bounded polling loop continues. A
nonzero error, fault or timeout fails the run. Every result and all 34 counters
remain behind an observed DONE/error-zero snapshot. A preceding DONE cannot
satisfy a later launch. The 48-job path retains the existing at-most-10-ms
post-START delay, included in the timer. Short joined batches do not sleep.
Their first poll RTT field is the measured complete launch-list interval,
which is explicitly different from an isolated poll RTT.

`launches.tsv` records exact command membership, whether a poll was included,
preparation/run/finish/total wall times and both direction responses.
`transactions.tsv` uses `LAUNCH_OKAY` for member transactions, with zero
per-transaction timing placeholders. `stages.tsv` likewise has placeholders;
the real command duration is retained separately. Existing `GROUP_OKAY` rows
and `queues.tsv` continue to describe homogeneous DDR/completion groups.

Independent CPU, homogeneous-group, complete-timing, cache/pacing and launch
audits are all mandatory. The launch audit checks exact coverage, descriptor →
START → optional status ordering, allowed shapes, responses, busy retries and
timing inclusion. Mutated traces exercise rejection; they are not hardware
fault-injection tests. Cache certificates still revoke on DDR/base/START or
explicit invalidation writes, with two direct reads and fourteen valid reuses.

Compare complete resident and application wall time across fresh interleaved
runs of the same bitstream. Descriptor work moves from `config_us` into
`launch_poll_us`, so isolated phase timings are not directly equivalent. A fair
control comparison sums both phases. Application time includes the actual
22,528-byte upload, both full operand readbacks, all 106 projections and final
guards, while excluding Vivado startup and programming. Preserve every sample,
including outliers. The selected eight-channel Qwen block is not full-model
inference.

Measurements and qualifications: [board report](evidence/prx100-fpu-20261018.md).

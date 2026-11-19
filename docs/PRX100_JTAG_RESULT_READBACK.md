# PRX100 combined result and counter readback

`scripts/prx100-fpr-board.mbtx` compares result-readback dispatch strategies on
the unchanged qualified FPDDR1.3Q bitstream. All modes retain completed-counter
cache evidence, unchanged-descriptor reuse, bounded post-START pacing, serial
status/error polling, and complete output/counter validation.

| Mode | Completed-job readback |
| --- | --- |
| `paced` | Preceding driver: DDR result read, then a separate 34-word counter read |
| `fused` | One hardware-queued command containing all DDR result bursts, then counters |
| `list` | One command containing the same transactions, executed sequentially without the completion queue |

The selected profile is `list`: queued/list readback medians are effectively
tied in the measured 48-job case, while list dispatch has lower measured full
resident completion. Both implementations and their complete observations
remain available; no meaningful superiority between their readback medians
is established by this sample.

Every mode reads all actual DDR outputs, including the final job. No result
is reconstructed from earlier repeated vectors or substituted from the MMIO
mirror. The required 34-word snapshot is also retained, including its eight
mirrored final results. Each 106-projection campaign reads 848 DDR result words
and 544 counter words. Total DDR reads/writes remain 17,796/11,292 words,
including full input poisoning/readback and guards.

## Ordering and access limits

The bounded `completed_reads` helper can run only after the job loop observes
DONE=5 and error=0. It builds the full result range at `0x10300000`, splits at
256 words, and appends exactly a 34-word MMIO read at byte address 48. One or
two DDR bursts plus the counter burst form a two- or three-transaction command.
The job bound is 1–48, so the result region remains within one 4 KiB page.
All entries are reads of stable completed-job state; no write/read dependency
or START command is included. The generic DDR bulk interface still rejects MMIO.

The independent group audit requires the immediately preceding raw transaction
to be a successful two-word status/error read containing `5,0`. It checks exact
result addresses, lengths and coverage for that batch, counters last, all 34
counter words, per-burst bounds, full group coverage, word totals and timing.
The CPU audit independently verifies every returned DDR result and mirrored
counter result, plus all stage/cache/drain/error invariants. Cache evidence
references the actual last counter transaction sequence in the combined group.

The hardware queue remains depth16; existing large input groups are unchanged.
The baseline has 11 command groups, including the two-burst 48-job result read.
The combined modes have 26 groups: ten existing input groups and sixteen
completed-read groups. Those sixteen groups cover all 33 result/counter
transactions (17 result bursts plus 16 counter bursts), using sixteen commands
instead of the preceding thirty-two. The individual payload transactions and
full data checks remain unchanged.

The pinned Vivado command help distinguishes `run_hw_axi -queue` from plain
multi-transaction execution. `list` is sequential within one command, not a
hardware-queued completion path. Legacy `queues.tsv` and `queued_*` timing
fields count command groups, including those sequential-list groups. Each
receipt records `completed_read_dispatch` to distinguish them.

`GROUP_OKAY` records the observed final response of the command/group; it does
not prove every constituent request's individual AXI response. For completed
reads, the last request is the counter burst. Full DDR/CPU/counter checks are
separate evidence and do not establish per-request error reporting. Ordinary
command errors remain enabled; `-quiet`, which ignores command errors, is unused.

## Timing and reproduction

Resident timing starts before descriptor/cache handling and ends after all
output/counter/error checks, including pacing delays. Combined result/counter
time is `results_us + counters_us`, including result comparison. In fused/list
modes the results phase includes the counter transfer and the counters phase
is almost empty. Compare their sum or total wall time, not individual phase
columns. CPU counter validation remains in the final checks in every mode.

Application timing additionally includes the real 22,528-byte model upload,
both full actual input readbacks, all 106 projections and final guards.
Qualification timing additionally includes complement poisoning and initial
checks. Programming and Vivado startup are excluded from workload timings.

Reproduction in the pinned isolated guest uses a fresh root:

```
moon run /work/prx100-fpr-board.mbtx -- run \
  /work/builds/prx100-fpq-vivado-20261018-hold-a2 \
  /work/builds/prx100-fpp-jobs-20261017.json \
  /work/builds/prx100-fpq-qualification-20261018-a1.json \
  /work/builds/prx100-fpr-board-NEW 30000000 list
```

Run the independent `fpr-audit`, `fpr-groups`, `fpr-metrics` and `fpr-policy`
scripts on the resulting files, then `fpr-close` for the owned server. The
driver verifies bit/source qualification, FPGA part/IDCODE, CPU_TAG cable
`ME10E06D1010A`, 30 MHz JTAG, queue depths16 and configuration DONE/CRC. It
programs volatile configuration; flash is unchanged. Integer and FP cores,
50/100 MHz clocks, controller, bridge, vendor IP and canonical hardware are
unchanged. Measurements and limits are in
`docs/evidence/prx100-fpr-20261018.md`.

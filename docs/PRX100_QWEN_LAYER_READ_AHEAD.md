# PRX100 bounded read-ahead for the complete BF16/FP32 layer

The qualified 32-row image's fresh 108-section board profile spends
14,687,948 of 21,401,947 cycles in DDR-backed matrices (68.6%), 3,011,644
cycles in SiLU blocks (14.1%), and the remainder in other work. Section
counters include inserted HALT/fetch overhead; unsplit resident campaigns
establish end-to-end latency separately. Full program/counter/tensor checks
must validate the profile before publication.

The slow interface supplies four FP32-sized words, or eight BF16 weights,
per core edge. Thirty-two ordered accumulators at interval two can consume
sixteen weights per edge. More arithmetic rows cannot overcome this feed
limit. The existing four-row bridge adds another restriction: it issues eight
native reads for one row, waits for that row's last packet to enter the CDC
response path, and only then starts the next row.

The opt-in read-ahead bridge reserves storage for all 32 native lines of one
four-row request. It may issue later rows before previous rows finish sending.
Every unstallable return has its own register slot. Issued and returned counts
are bounded by 32 for marked four-row requests, and eight for ordinary bursts.
Responses retain the original row/word order, four-word packet shape, final
LAST position, source ownership, coordinated reset and terminal fault drainage.
The native row offset advances only after an accepted eighth read command;
stalled commands hold their address. No host or descriptor ABI changes.

The existing MIG project retains `Ordering=Normal`. The bridge uses the MIG
user interface's read-return ordering guarantee: the UI restores read data to
request order even when the memory controller schedules SDRAM commands out of
order. See AMD's [UG586 read path](https://docs.amd.com/r/en-US/ug586_7Series_MIS/Read-Path)
and [UI block](https://docs.amd.com/r/en-US/ug586_7Series_MIS/User-Interface-Block).
This vendor boundary is exercised by the board checks; it is not an analog or
vendor-IP formal claim.

The larger buffer uses balanced selection rather than a longer priority-mux
chain. This preserves exact word selection, including the explicit out-of-range
fallback, while keeping combinational depth bounded. Construction, simulation,
emission and diagnostics remain first-party MoonBit. Vendor RTL is emitted.

The initial candidate retains the exact qualified 32-row arithmetic core,
controller and clock constraints. Integer inputs must remain unchanged. Every
legacy bridge/export must remain byte-identical. If physical resource or timing
checks reject this candidate, preserve the failed attempt and choose a measured
configuration explicitly; no timing exceptions or clock relaxation are implied.

The first 32-row attempt was rejected by placement. Synthesis used 64,133 LUTs
against 63,400 available; the placer reported that packing and control sets
could not fit the remaining slices. No bitstream from that attempt is qualified.
The next candidate combines the exact previously qualified 16-row core with
the same new read-ahead bridge. Sixteen interval-two lanes match the interface's
eight-weights-per-edge ceiling. This changes the selected row configuration
relative to the resident 32-row baseline, while reusing the arithmetic generator
and its known emitted core without edits. The completed physical
comparison below measures that combined configuration.

The target recipe selects all four canonical/emitted core files from the final
pinned `export-streaming` result, and the read-ahead bridge files from the same
compiler/source cohort's `export-read-ahead` result. Controller, wrappers and
constraints must be byte-identical in both complete exports. The recipe copies
files without editing RTL and creates a sorted checksum inventory. Require
fresh synthesis of this exact combined digital composition and physical target;
the old core/controller gates are inherited only by verified source/seal identity.

The reproducible composition recipe is
[`scripts/prx100-layer-read-ahead-inputs.mbtx`](../scripts/prx100-layer-read-ahead-inputs.mbtx).
With the pinned native compiler and the final source cohort:

```sh
moon run --target native cmd/prx100_layer -- export-streaming /tmp/prx100-legacy16
moon run --target native cmd/prx100_layer -- export-read-ahead /tmp/prx100-read-ahead32
moon run scripts/prx100-layer-read-ahead-inputs.mbtx -- /tmp/prx100-legacy16 /tmp/prx100-read-ahead32 /tmp/prx100-read-ahead16
```

The first-party recipe verifies both inventories and shared target files,
selects the known 16-row core and new bridge without modifying RTL, and writes
an external composition receipt. Its output is target input, not permission to
skip the qualification gates below. The `export-read-ahead` command retains
the initial 32-row configuration; that configuration did not fit this device.

Qualification requires native ordered-data/backpressure/reset/fault tests,
direct evidence that 32 commands can be outstanding under a held response,
same-stimulus cycle comparison with the serial-row bridge, actual-RTL
LunaWave/Verilator differential at 3:1 clocks, pinned Yosys synthesis and
bounded bridge properties with a retained failing calibration mutation.
Existing core/controller gates may be inherited only by exact source identity.
Require routed setup/hold/pulse checks, zero failing endpoints, strict DRC,
clock/debug identity and bit digest before programming.

If the monolithic bridge solver exhausts its resource limit, assertion
partitioning may establish the same finite-prefix claim. Every original
assertion expression must occur verbatim in exactly one successful task;
all other source bytes, DUT, input ports, clock schedule, reset and history
registers must remain identical. Other assertions become `true`, never
assumptions. A closed coverage audit must establish the complete conjunction.
Every task checks the original 128-frame window, or proves its subset for an
unbounded window. Failed, timed-out and superseded attempts remain evidence;
none constitutes a passing gate.

The physical comparison retains five complete four-token layer samples,
one three-token prefill and five cached position-3 decodes, with weights,
intermediates and KV resident. Actual launch, polling, counters, final reads,
file writes and CPU checks remain inside the end-to-end timers. Setup, upload,
program switching, integrity and full diagnostics remain separate. Check all
tensors against CPU tolerance and the unchanged ordered operation model, and
retain every sample, including regressions. This is one fixed layer/context
four, not full-model generation.

## Measured qualification — 2026-10-20

The [measured read-ahead continuation](../artifacts/prx100-layer-feed-20261020/report.md) explains the 32-row limit with a fresh 108-section board profile: DDR-backed matrix stages account for 68.6% of board cycles;the interface carries eight BF16 weights/core edge while 32 interval-two lanes require sixteen. Four-row prefetch reduces matrix stages 440.638 → 377.085 ms (14.42%);SiLU stays 90.349 ms. The 32-row read-ahead target failed placement,so the qualified image reuses the exact previous 16-row core and unchanged arithmetic source,controller,host policy and clocks. Resident four-token latency improves **704.242 → 644.422 ms (8.49%)**;cached position-3 decode **195.743 → 187.600 ms (4.16%)**. Kernel medians are 578.398 / 146.589 ms,9.90% / 9.78% lower. All 845,696 paired FP32 words pass CPU tolerance and ordered-model bit equality;all 199 integer inputs remain unchanged. Native 1,270 tests,actual bridge RTL differential/synthesis,all 83 original safety properties over128frames with exact coverage,and strict route/clock gates pass. The design uses40,689 LUT /134.5 BRAM /51 DSP at100/3MHz. The fresh portable CPU reference takes90ms for four tokens,so it remains faster even than the FPGA kernel. This is one fixed complete layer/context four;full-model inference and broader phase closure remain open.

The exact source/bit/clock qualification and all raw samples are retained in
[the sealed evidence](../artifacts/prx100-layer-feed-20261020/report.md).
Bitstream SHA256: `e399004ecdac5d4c32920a84539ddd5e012de383d94c109c5c019acc1b52068d`.

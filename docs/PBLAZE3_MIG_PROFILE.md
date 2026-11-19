# PBlaze3 MIG read profile

Current integration, completed native validation and subsequent timing work:
[300 MHz integration record](PBLAZE3_300MHZ_INTEGRATION.md).

Owner27's completed whole-system route now passes the300MHz MAC domain:
setup+0.096/hold+0.051ns. Inspection76 verifies fully routed checkpoint
`5a01975e3aae3d67bcbb1bab2e5d230c7708dacaf9a5ae0adc181ac7f621ead4`.
Core150/UI200/PCIe250 setup is−1.258/−0.023/−0.200ns; whole-system acceptance
still fails. The150MHz postroute refinement was stopped after retaining this
checkpoint. `owner120-eco77` now changes actual scheduler MMCM divide8→10,
keeping MAC300/MIG200, with renewed full timing/CDC/DRC gates. No new board run.
The following paragraphs retain earlier implementation evidence.

The completed full-product25 initial route is now measured, not a standalone
array estimate: scheduler150/MAC300/MIG200/PCIe250 MHz have setup slack
−1.771/−0.141/−0.235/−0.263 ns respectively; all four hold slacks are positive.
It is fully routed but not timing-qualified and has not been programmed.
The core path ends at scratch write-address selection, now changed in owner27.
The MAC path is product exception classification into its metadata delay SRL
(activation fraction→NaN flag), four LUT levels with87.2% of delay in routing.
The completed checkpoint and reports are retained under
`full-product150-inspect71-initial-route`; further refinement of that superseded
source was stopped. Eager26's post-place reports are also retained; its router
was stopped before a completed route after owner27 superseded its scratch mux.

Keep the300MHz MAC target. A120MHz scheduler option may be prepared with actual
MMCM settings and matching source metadata for a measured frequency tradeoff;
it is not an acceptance by relaxing timing constraints. Owner27's150MHz run
remains the active implementation until its timing evidence is available.
If needed, the120MHz option can reuse a completed owner27 route by changing
the actual MMCM scheduler divider (1200MHz VCO:8→10), while retaining300MHz
MAC and200MHz MIG. This requires exact source-parent binding, clock readback,
complete routing, renewed setup/hold/CDC checks and120/300MHz simulation;
it must not simply relax the150MHz constraint or accept a negative slack.

The owner27 candidate adds optional `state_scratch_mux`. Eager26 placement70
now ends its worst core path at scratch write-address selection: descriptor
`n` → request burst shape → controller protocol/writable → host scratch-write
gate → RAM address, −2.562ns placed slack. The existing writer-state ownership
can select address/data while the original write permits remain unchanged.
Host owns idle states0/14, shared unary28, vector29–31 (its existing live
predicate), and streamed unary24. The actual87-node write-control cone proves
that the owner is identical on every enabled write for arbitrary register and
input values; a deliberately wrong owner is rejected with a counterexample
(`owner27-proof`). The whole emitted IR differs only at eight mux selectors;
the consumer audit limits changes to the two mirrored scratch write ports.
This introduces no write latency and retains read-old collision behavior.
All25 complete-system Verilator checks and their edge counts match eager26.
The disabled-option export remains byte-identical. Physical synthesis and
optimization72 are complete; layout74 is running at150/300/200MHz. Original
AMD primitive simulation73 passed all25 checks; timing is not qualified. Eager26's
full native run was stopped incomplete and its physical reports were retained.
Its original AMD simulation69 is complete. The new full native run is described
below; no full-suite PASS is claimed until completion.

Owner27's completed placement74 has setup estimates core−2.060/MAC−0.688/
UI−0.955/PCIe−1.070ns. The longest core path now starts at loop counter `i`,
passes through DDR burst selection and protocol-derived `memory_healthy`, and
ends at the result FIFO's2051-bit read-output enable (20 levels,8.507ns).
Scratch address selection is no longer this worst path. The MAC's worst path
is registered payload BRAM→weight staging with zero logic levels. These are
placement estimates only. Subsequent post-place physical optimization improved
core/MAC/UI/PCIe setup to−1.472/0.000/−0.314/−0.421ns. Full routing now runs;
the MAC's nonnegative placed slack does not establish routed timing closure.

Owner27 now also has a native public-API regression in
`scratch_owner_test.mbt`: host writes, vector operations, shared/streamed unary,
busy-time external write interference, NaN faults, reset and late-write
readback all match the original machine cycle by cycle (PASS1). RTL is frozen
for the150MHz and optional120MHz scheduler trials; full native validation has
started from `owner27-native-source` (inventory
`38014e31b740438e8a527b2792d076f3c0308615d644006b0f041f35ba6da68b`).
This run is pending, not a full-suite PASS. Eager26's original AMD replay69
has now passed all25 checks and is checksum-captured.

An additional optional read-enable change is now implemented from measured
timing evidence. In ingress24's complete initial route, and again in
full-product25's placement, the dominant core path starts at descriptor `n`
and traverses protocol/health/credit into the weight-bank BRAM read enables.
With `eager_weight_reads`, the 64 bank read ports run whenever the scheduler
is in matrix state20 and reset is deasserted. Existing issue/credit/health/reset gates still control
MAC validity, address advancement, writes and packet submission. Read address,
read-old collision policy, lane rotation and their one-edge alignment remain
unchanged. Extra reads during stalls are unobservable when
`mac_issue=0`; valid payloads must remain cycle-identical. This option requires
the ordered banked array, defaults off and adds no pipeline latency. Its 64-bank
native regression passes: every bank/address is initialized, then 4,096 edges
exercise credit stalls, health/fault gates, bank/slot changes, read-old
collisions and resets. The first attempt omitted reset gating and correctly
failed on an unknown initial address; `digital-eager26` and the failed log
are retained. The corrected export is `digital-eager26-v2`.

All 25 full-system Verilator checks and pinned Yosys synthesis pass.
`eager26-proof/claim.json` audits the entire core IR after node renumbering:
only five new control nodes and the 64 weight read enables differ; writes,
addresses, other nodes, registered MAC issue and latencies are unchanged.
A read-port refinement proof with arbitrary common ReadOld words passes
temporal induction, and the deliberately broken credit gate fails with a
counterexample. This is a local refinement proof, not a full-system formal
proof. A separate whole-IR consumer audit confirms that these read values
reach only `mac_weight0..63`, never a state register or a memory address,
enable or write-data port; its negative control is rejected.
Default-disabled exports remain byte-identical to full-product25.
`profile-frequency150-eager26` is synthesizing in `eager150-opt68`; physical
acceptance and original AMD simulation are pending. The revised source is
frozen under `eager26-source/SHA256SUMS` (SHA
`856a4c5f944c1518d4795863e35fe00cc0f94af47a10f8fea0197d89e4cba9f0`),
and its full native phase suite is running. Optimization68 has completed
(checkpoint SHA `8ac3f64847ac34d8dbd2cf7a6ba97d7d73d61e09720e35410ea2dd545e53fc43`)
and route70 has started. Its physical read-enable guard confirms256 RAMB36E1
blocks with exactly6 startpoints: state-register51's five bits and core reset.
Descriptor, DDR protocol, health and credit no longer drive these enables.
This is a structural result; routed timing is still pending. The in-progress
full-product25 native suite was stopped before any
completion claim; the full phase suite will run after the revised source is
frozen. Original simulation and physical implementation of the frozen
full-product25 bundle continue independently.

Previous prepared candidate: `profile-frequency150-full-product25`, inventory SHA
`1f699a2ef9ee44abf1d739d628d049ab3c6d5d4a2c240f18d19c315e6882bb4a`.
Targets remain scheduler150/MAC300/MIG200 MHz. This optional exact integer
significand implementation preserves the 13-edge product latency. Three
targeted native tests, all 25 full-system Verilator checks, and pinned Yosys
array synthesis pass. Default-disabled core/controller/bridge exports are
byte-identical to ingress24. Source snapshot SHA is
`a8b5fdfaa4cb3c9c09fe0b2470b13cec3fba1cdf8a0b314552e94773d2813dcb`;
its full native regression was stopped incomplete. Original AMD simulation
`full-product150-sim64` now passes all25 complete-system checks; physical
implementation continues on the immutable source bundle. Its post-placement
optimization estimates are scheduler−2.042/MAC−0.233/MIG−0.460/PCIe−0.477ns;
these are not routed acceptance results.

Matching standalone Vivado synthesis (`full-product25-reference65` versus
`full-product25-array62`) reports 70,977 → 49,729 LUTs (−29.94%) and
139,842 → 87,746 FFs (−37.25%). DSP48E1 count changes from 0 to 64, each with
AREG=2, BREG=2, MREG=1, PREG=1, USE_MULT=MULTIPLY and USE_SIMD=ONE48.
Candidate synthesis setup slack is +0.738 ns at 300 MHz; this is an unplaced
estimate, not physical acceptance. Whole-system synthesis is `full-product150-opt63`;
original simulation is `full-product150-sim64`. The next physical driver,
`implement-frequency150-v9-dsp.tcl`, verifies 64 matrix DSPs, registered
multiplier/output stages and the 300 MHz clock both before placement and at
acceptance. It preserves all earlier reset, clock, routing and setup/hold gates.

Direct temporal and combinational SAT attempts timed out; they are retained
as unsuccessful attempts. The replacement proof first checks that both
generated resetless pipelines are acyclic, single-driver and uniformly
13 edges from either data input to the output. It then proves the flattened
arithmetic for all256 weight values and all24-bit activations. The proof is
complete:223 whole-weight partitions pass; the timed-out weight223 is not
counted, and the remaining33 weights are covered by528 partitions fixing all
16 low activation nibbles while leaving the upper20 bits arbitrary. All
2^32 operand combinations are covered; receipt:
`full-product25-formal-complete.json`. Latency, feedback and
enabled-register mutations are rejected by the pipeline audit; an output-bit
mutation is caught by the SAT negative control. Invalid warm-up data is not
part of the equivalence claim. No new image has been programmed or measured.

Previous candidate: `profile-frequency150-ingress24`, inventory SHA
`401d6b1a1a6f56556096d0dff484b5a4adc797a2f619aaecbdececd287ab4c61`.
Its 25 full-system Verilator checks, four targeted native tests and pinned
Yosys structural synthesis pass. The frozen source snapshot inventory is
`18d750b35d9529b29a3547f60af0ef3897b0a5572686bc37b20a232a13440d13`.
Original AMD simulation (`ingress150-sim58`) also passed all 25 checks. Its
input inventory SHA is `1a32e89c06d46de81820b8f229ff781811ea6f0f5502906b2eee53a9da26a0dd`
and log SHA is `59be5419f616a83f038e6a640e97bebf00671cca05ecf45fdff5a4bde3145c32`.
The frozen full native regression passed all 1,417 tests; its log SHA is
`cb8691eb9b4eb0d7795f630ab648177a95afb59bc60f28fd59c1646adc654d44`.
It adds one command-input edge and a fifth FP32 multiply edge;
vector/shared-unary latency stays five, scalar phase becomes six and ordered
reduction retirement becomes nine. Physical acceptance and new board results
remain pending. Synthesis and optimization passed in `ingress150-opt57`;
checkpoint SHA is
`6972e4d562a0ba35b67bc978e42cc95c305d4d132475888e0452067ffb7badb9`.
`ingress150-route59` is implementing that checkpoint.
Driver v7 additionally requires all 1,072 command-input FFs
on the 150 MHz clock. The board still runs the qualified 100/282.353 MHz image.

The first fully routed checkpoint in route59 has setup −1.580 ns and hold
+0.015 ns. A separate read-only inspection (`ingress150-inspect61`) binds
checkpoint SHA `145d1e95d7b579238c9965e1a6a5c5230ed947bdef63c43967ec88b0cf73ead0`
and reports core/MAC/UI/PCIe setup of −1.580/−0.386/−0.766/−0.332 ns.
Post-route optimization continues; this checkpoint is not accepted for a bitstream.
The worst core path starts at the descriptor's `n` register (`lc_n76`), passes
row-count logic, request validation, health/flush and MAC credit, and ends at
weight RAM read enable. Delay is 8.344 ns, including 6.944 ns routing (83.222%).
The routed design uses 148,501 LUTs, 226,631 FFs, 391 RAMB36 + 3 RAMB18 and
62 DSPs. The 64-lane array itself uses no DSPs.

The subsequent isolated experiment optionally replaces the ordered lane's exact 24×8
significand compressor with a full-width integer multiply intended for DSP48
inference. Eleven operand delay edges, one registered product and one output
edge preserve the existing 13-edge latency. Keep all 32 product bits and
every later normalization, RNE and ordered FP32 addition unchanged. The
default remains the old implementation. Native arithmetic and complete-lane
equivalence, formal proof, synthesis resource mapping and routed timing must
qualify this option before board acceptance. Resource results and outstanding
gates are recorded above; no routed timing or inference gain is claimed yet.

Ingress24's first completed placement reports core/MAC/UI/PCIe setup estimates
of −3.104/−1.290/−1.857/−0.872 ns. These are not routed results; physical
optimization is still running. The worst core path now starts at the bridge
state register and passes response-data selection and the controller's
32-to-1 program-word selector into core program RAM. Its 9.638 ns data delay
contains 8.956 ns estimated routing (92.924%). It is a program-loader path,
not the newly staged matrix command input. Reports are retained under
`frequency150-physical/ingress150-route59-place` in the active evidence bundle.
If this remains dominant after physical optimization, a program-loader stage
should align the selected word, write address and write enable, and ensure
the final program word commits before core launch. Legacy MMIO write/read
behavior, faults and chained launches must remain checked. No such additional
stage is implemented in the frozen ingress24 candidate.

Completed physical optimization improved those estimates to
−2.195/−0.678/−1.762/−0.513 ns. The worst core path moved to bridge control:
`lc_n699_reg[5]` to `lc_n288_reg[15]/CE`, 8.969 ns data delay, 7.963 ns estimated
routing and 13 logic levels. Retained placed checkpoint SHA:
`bcf337d3ec7467aaab96828947af633c09f234ecd2f02c459634add0b7675fcb`.
Source mapping identifies that control path as the streaming response's
12-bit `delivered == final_packet` comparison, then controller protocol/health
logic and a burst-writer payload register enable. The existing predicted-last
option stages only the legacy response predicate. A possible next change is
to predict the streaming terminal predicate too: reset to one (both counters
reset to zero), on start test the new final index against zero, and on consume
test the modular next delivered index against the retained final index. This
would add no response latency, but must prove every existing bridge output
and state transition unchanged under stalls, arbitrary faults and reset.
This remains a proposal; frozen ingress24 does not include it.
Regular routing continues. A second implementation, `ingress150-incremental60`,
uses exactly the same ingress24 optimized source and product22's retained
placement as an incremental reference, with `TimingClosure` targeting zero
setup slack. Vivado rejected this attempt before reference matching with
error `12-29181`: the selected BASIC license does not cover incremental
implementation. The process exited 1; no reference reuse or new physical
result was produced. Regular `ingress150-route59` continues with all source,
clock, reset, complete routing and nonnegative setup/hold gates unchanged.
AMD permits placed
references but warns their timing/runtime benefits are less consistent than
fully routed references ([UG904, 2026.1](https://docs.amd.com/r/2026.1-English/ug904-vivado-implementation/Incremental-Implementation-Terminology?contentId=PDWnEWqNorbc~CWGF40fKA)).

The pre-placement resource report also shows the 64-lane array itself uses
65,154 LUTs and 139,716 FFs with **zero DSP blocks**; the full system uses 62
DSPs. `significand_product` implements exact unsigned 24×8 multiplication as
a thirteen-edge compressor/prefix network. A possible 300 MHz alternative
is a registered full integer multiply inferred into DSP48, padded to the same
thirteen-edge latency. Keeping product normalization, rounding, exception
handling, row feedback spacing and retirement tags unchanged would isolate
this as an implementation mapping change. DSP inference, exact product
equivalence, full lane/system behavior, routed resources and timing must all
be measured before selecting it. This is an unimplemented candidate; no
resource saving or clock improvement has been measured for it.

Earlier candidate: `profile-frequency150-product22`, inventory SHA
`74c712d057af41034f184f7e8e6b674a46c8bf598ed79f9d47735290b9eb56b7`.
Synthesis and optimization passed in `product150-opt52`; checkpoint SHA
`0c08fc2407f6c8a3a97d0d3d5b098a28e4cb70725be8cd965bc43258c010803e`.
`product150-route54` completed placement and physical optimization, then was
stopped after retaining its checkpoint and reports. Its guards confirmed
150 MHz scheduler, 300 MHz MAC, all 256 activation broadcast registers and
the fifteen registered payload BRAMs. It did not qualify routed timing.
Its original AMD simulation passed 23 checks. The older native regression
finished with 1,417 passes and zero failures (log SHA
`cb8691eb9b4eb0d7795f630ab648177a95afb59bc60f28fd59c1646adc654d44`).
Because source/cache changes overlapped that run, it is auxiliary evidence,
not the qualification for the frozen ingress24 source.
No new bitstream has been programmed and no new tokens/s has been measured.
The entries below describe the retained development and validation history.

The newer address23 bundle has inventory SHA
`f40868fec6a4a105564456c464d09402be436bf8443235c8d808c11ef9fe4b19`.
It passes all 25 expanded Verilator replay checks, including identical cycle
records against product22 under the same bench. Its original AMD replay passed
all 25 checks (`address150-sim56`); input inventory SHA is
`db7d142b02c04fa554d81acb959884d213aea09de22a1b7f96a739326024d863` and log SHA is
`613bdec30ef66547b9157edbb66438a4c75e705bb5e7a7e2f69230b0be501d78`.
`address150-opt55` completed using opt52's IP checkpoints. The full
native run started for address23 was stopped because the shared build cache
changed before a queued test executable launched. Its partial log is retained
and is not source23 qualification. The frozen ingress24 run replaces it.
The wrapper guard permits only renumbered core input-node IDs with identical
semantic port suffixes and connections; every other wrapper byte is checked.
Product22's completed placement/physopt checkpoint was retained and routing
stopped: core/MAC/UI/PCIe estimates are −2.849/−0.074/−0.565/−0.256 ns.
The 23-check original AMD replay passed. Neither result qualifies a bitstream.

The same physical report exposes two further scheduler paths near −2.85 ns:
weight BRAM through selection to the command payload BRAM, and scratch BRAM
to a multiplier DSP input. The next optional stages will capture command
payload and metadata together before publishing its FIFO entry, and register
FP32 multiplier inputs. The latter adds one edge, consuming the remaining
vector/unary padding edge; scalar and reduction retirement must move with it.
Reset/flush, pending command overflow, all operand sidebands and the ordered
FP32 accumulation sequence must remain checked. Full replay is required.

Product22 placement reports scheduler/MAC/UI setup estimates of
−3.660/−0.235/−0.595 ns before `phys_opt_design`. The scheduler path has moved
to integer row-address generation: flags/group selection, next-row addition,
two DSPs computing row×K, and the DDR base addition, at 10.251 ns data delay.
The proposed `incremental_row_address` option tracks the current row-group
base, initialized from the accepted descriptor's DDR address and advanced by
a registered group byte stride. Group sizes are powers of two, so that stride
uses shifts instead of multiplication. Current-stripe and next-group reads
must retain exactly the original addresses, request timing, reset/fault
behavior and modulo-32-bit arithmetic. The option requires staged descriptor
decode and the ordered array; its two stride stages settle during descriptor
fetch. Full system replay is required before building this candidate.

### Placement follow-up: terminal response control

`deep150-route49` completed placement at 150/300 MHz. Before physical
optimization, scheduler WNS is −3.868 ns: a legacy bridge response-last
calculation crosses the controller's protocol-fault logic and MAC flush/credit
logic before reaching bank RAM read enables (10.639 ns, 18 logic levels,
8.920 ns estimated routing). MAC WNS is −0.746 ns on activation broadcast,
with no combinational logic between the payload BRAM and lane input register.
These are placement estimates, not final routed timing or board measurements.

The next optional bridge change predicts the terminal-response flag at request
acceptance and each preceding response handshake. It must preserve every
output on every edge, including stalls, reset, malformed requests and faults;
it adds no response latency. The predictor resets to one, matching the old
zero-limit comparison, and retains 10-bit modular arithmetic when predicting
the next count. Two complete-bridge native comparisons pass (all outputs before
and after every edge), including backpressure, scalar/line/wide modes, 1 KiB
bursts, 512-row lookahead, malformed requests, AXI faults and reset. An initial
file-name-as-filter invocation selected zero tests and is not evidence.

The combined candidate also adds one array-input edge, eight preserved FP32
activation replicas each driving eight lanes, and matching weight/valid/first
registers. The retirement tag shifts 47 rather than 46 edges. Column order,
FP32 rounding and MAC feedback distance stay unchanged; this is a latency
change, not a reduction of initiation rate. Default exports remain unchanged.
The board is unchanged. Independent full-system replay and physical acceptance
of this combined candidate remain required.

The same placement report also exposes a multiplier packing path from
`core_i/lc_n15722_reg[2]` to `lc_n15804[5]_i_1_psdsp`: −3.797 ns,
10.138 ns data delay and 26 logic levels. It shifts right for gradual
underflow, shifts left again to find discarded bits, then rounds. A separate
optional compact jam shifter will accumulate sticky bits at each constant
barrel-shift step and saturate oversized shifts. This must preserve all
27-bit significands and 11-bit shift counts, with no added pipeline edge.
It was not part of the earlier `broadcast150-opt50` synthesis.

`compact21` passes the same 23 full-system Verilator checks, the two complete
core/nonlinear native comparisons, and two new unit tests. Pinned Yosys 0.68
proves the generated original and compact three-edge multipliers equivalent
at induction length one, starting in matched zero register state, with all
operands and resets arbitrary (`compact-multiply-proof1/proof.log`). The
terminal-response bridge proof likewise closes at induction length one,
checking all outputs and every original register from matched reset state
(`response-last-proof6/proof.log`). Earlier proof attempts and driver mistakes
remain retained; they are not successful proof evidence.

The unmodified-library XSim run `deep150-sim48` completed all 23 source18
checks. Its input inventory SHA is
`b5c543cf27120bbbc3f57473e89b404769645da5ce1d5eabe997fa797bf03626` and simulation
log SHA is `b09da9874c8bf67fac12a3924a4972cb27ae548c02cb4d5d35f7a31c6374c60d`.
This does not qualify the later broadcast20/compact21 sources.

Read-only reopening of the retained source18 post-physical-optimization
checkpoint confirms scheduler/MAC/UI/PCIe setup estimates of
−3.270/−0.631/−1.088/−0.465 ns. Scheduler worst now runs from scratch BRAM
to multiplier `lc_n8666_reg/PCIN[0]`: 8.777 ns data delay, including
5.513 ns logic and a DSP cascade. This is a separate raw-product path,
unaffected by the compact rounding shifter. Splitting the full 24×24 product
across two registered partial products is the next candidate; it would add
an arithmetic edge and require explicit scalar, reduction and nonlinear
latency updates. This motivated the subsequent candidate below.

The subsequent opt-in product stage is now implemented for scheduler FP32
multipliers: two registered 24×12 products form one exact 48-bit sum on the
next edge. All exponent/exception/sign sidebands gain the same edge, with
rounding still performed only once. Multiplier latency becomes four edges.
Five-edge vector and shared-unary paths consume one former padding register,
so their total latency and issue spacing stay fixed. Stream-unary dependency
depths gain one per multiply; scalar execution commits at phase five rather
than four; ordered-reduction retirement moves from seven to eight edges,
with unchanged four-edge accumulation spacing. SUM's bypass is delayed with
the product. The 300 MHz BF16 MAC lane itself is unchanged.
`product22` passes all four targeted native tests and all 23 pinned Verilator
system checks. Original-library XSim is running as `product150-sim53`;
full native regression and physical acceptance remain pending.

The user has released the fixed-100-MHz comparison requirement. The active
implementation target is now a 150 MHz scheduler and 300 MHz MAC, with the 200 MHz MIG and
1 KiB bursts retained and BF16/ordered FP32 results unchanged. A proposed
1200 MHz MMCM VCO permits 150 MHz core, 300 MHz MAC, 100 MHz debug and
200 MHz auxiliary clocks together. These are build targets, not accepted
hardware frequencies. Scalar alignment and normalization will be pipelined;
all physical clocks and full logits must be verified. The 6.166 tokens/s
record remains historical; new results must disclose their actual clock.
MIG reports must convert scheduler and UI counters using their separate
frequencies, including the non-integer 200/150 clock ratio. The MAC payload
BRAM output gains one registered edge, with all command metadata and validity
delayed by the same edge. Existing export modes retain their original RTL.
The 1024-bit scheduler-side AXI interface has a theoretical 19.2 GB/s ceiling
at 150 MHz, versus 12.8 GB/s at 100 MHz. The 512-bit 200 MHz MIG ceiling stays
12.8 GB/s. This adds receive-side headroom; it is not measured memory throughput.
Consequently, raw scheduler receive gaps cannot be compared as memory stalls
across these frequencies. At 150 MHz a continuously saturated MIG supplies
only two 128-byte packets per three scheduler cycles. The 1,191,968,768 weight
bytes per output require at least 93.12256 ms at the MIG peak; their 9,312,256
scheduler packet cycles occupy 62.081707 ms. The remaining **31.040853 ms** is
ideal rate-matching idle time, even before additional memory stalls. At the old
100 MHz interface the corresponding theoretical floor is zero. Both reporters
now expose this theoretical floor separately; real MIG UI gaps, delivered
payload bandwidth and end-to-end tokens/s remain the performance evidence.

The first 150/300 MHz source bundle was `profile-frequency150-17`, inventory SHA-256
`4a5eb1b1274c56aeae58a0dc06a9f92563ead785e9ba5b55f07f3d77451f1821`.
Preparation and 150 MHz clock-interface propagation pass. Physical synthesis
passed in `frequency150-opt42`. The scalar tests
pass for original, normalized and alignment-plus-normalization variants,
including raw CPU FP32 results and identical retirement cycles. The unchanged
default core export retains SHA-256
`74401abd6b6e3879a4f6c5463a0450e5615596c5ab39b0a29436309e8e51ea76`.

Bundle17's completed placement checkpoint has scheduler setup −3.461 ns:
`lc_n9497_reg[14]` to `lc_n9607_reg[9]` traverses FP32 normalization/rounding,
27 logic levels and 9.712 ns data delay (2.776 ns logic, 6.936 ns estimated
route). MAC/UI/PCIe placement slacks are −0.665/−0.733/−0.380 ns; these are
pre-route estimates, not achieved frequencies. The incomplete routing attempt
was stopped after retaining the valid checkpoint (SHA-256
`773c656de2b3a48d3f50670bd88624923fb101a72601daf59ffcf73a6e19189e`).
Exact reports are in `frequency150-physical/frequency150-inspect46`.
The worst MAC path has no combinational logic: a registered payload BRAM
broadcasts an activation bit to 64 lane input registers (0.622 ns clock-to-Q,
3.080 ns estimated wire delay). This is a separate placement/fanout issue;
the new scheduler arithmetic stages alone do not prove it resolved.

For full 512-row groups, `ordered_rows.mbt` distributes eight contexts over
the 18-MAC-edge feedback loop. At 300 MHz this gives a theoretical maximum
of 133.333 million 128-byte packets/s, or 17.067 GB/s of BF16 weight payload.
Both that limit and the 150 MHz scheduler's 19.2 GB/s interface exceed the
200 MHz MIG's 12.8 GB/s ceiling. This supports trying 300 MHz MAC with a
faster scheduler; it does not establish achieved throughput, and smaller
row groups, FIFO phase misses and other overhead reduce that bound.

The earlier deep-pipeline bundle was `profile-frequency150-deep18`, inventory SHA-256
`f3789c0107d6285d8b20157b213af37ca51292b4720ea1c07bc2072416d76278`.
Its opt-in `deep_fp32_add` separates alignment and normalization in the other
FP32 consumers too. Streamed nonlinear operators derive metadata delays from
their arithmetic depth; vector metadata and other results gain two matching
edges; four-context nonlinear execution reuses each context every six edges;
scalar accumulation waits two extra edges, and ordered streamed reductions
issue every four rather than two edges. Operand order and rounding points
stay unchanged. The default export still has the exact hash above.

Both native deep-pipeline tests pass, covering dependent instructions, aliased
scratch access, nonlinear faults, reset/drain/relaunch, and explicit context
latencies. Pinned Verilator passes 23 system-replay checks, including 192
reciprocal/rsqrt/exp outputs compared with separately rounded CPU FP32 results.
The first native run found a test's incorrect expected microprogram length
(75 actual edges, 77 mistakenly expected); its corrected regression passes.
The first Verilator launch had the wrong reference-file working directory;
replaying the same compiled binary from `/work/reference` passes. Both failed
attempts remain retained. `deep150-opt47` passed synthesis/optimization with
verified 150/300 MHz MMCM outputs (optimized checkpoint SHA-256
`2704ddefcc0549e31e6071cb96395909626af8a5d3d20744e296971380323cec`).
`deep150-route49` performs placement/routing and
`deep150-sim48` checks it with the original AMD XPM models; physical timing
and new real-board performance remain unverified.
The accelerator-only synthesis reports compare 108,036 → 108,160 LUTs and
164,989 → 167,576 registers for bundle17 → deep18, with both retaining
367.5 BRAM tiles and 67 DSPs. Thus the additional FP32 stages cost 124 LUTs
and 2,587 registers at this same intermediate phase. These are not final
whole-design utilization numbers; the original reports are retained under
`frequency150-physical/{frequency150-opt42,deep150-opt47}`.

Verilator 5.050 completes all 20 system-replay checks using the same physical
RTL and captured Q-projection reference bytes. Its vendor-library compatibility
copy lowers one unsupported whole-array GSR force/release to per-element
generate blocks. A separate 256-sample test, with 2/4-stage Gray synchronizers
and repeated GSR pulses, matches the unmodified AMD XPM model in XSim exactly.
The original vendor files and synthesis inputs are unchanged. Full XSim replay
with the original library also passed for bundle17 (`frequency150-sim43`). These
are functional checks with a stalled AXI testbench, not memory-throughput or
tokens/s measurements. All compiler warnings and the failed unmodified-library
Verilator attempt are retained under the campaign's `validation` directory.

The diagnostic and warm-performance reporters now derive scheduler time from
the benchmark's verified frequency, and require the cycle report to agree.
MIG time remains tied to 200 MHz. Synthetic tests cover 150/200 MHz conversion,
fractional UI-cycle differences, counter wrap and mismatched-clock rejection.
The warm reporter also passes against the retained baseline's full logits.
Pinned Yosys 0.68 also passes process lowering, optimization, memory collection
and `check -assert` on the new canonical scheduler core (zero reported
problems). This is RTL synthesis validation; physical timing uses Vivado.

This opt-in diagnostic measures the same weight-ownership interval as the
existing scheduler profile, at the 200 MHz memory interface. It observes
MIG, the downsizer's 512-bit output, and the downsizer's 1024-bit input.
The monitor drives no signal on these read channels. Input taps register
each handshake signal for one cycle before counting. The ownership level
is registered at the scheduler frequency before crossing through an explicit three-stage
synchronizer. The original scheduler counters use the undelayed predicate.

MIG counts accelerator ID 1. The width-converter interfaces have no ID and
select every request. Outstanding reads update on accepted AR and accepted
RLAST, including outside the weight-ownership interval. Simultaneous events
leave occupancy unchanged. A sticky flag detects underflow or 9-bit overflow.
The observed peak and occupancy histogram expose restricted concurrency.

The AXI-Lite peripheral is at address `0x80190000`, BAR offset `0x90000`.
Writes return SLVERR. Undefined and misaligned reads return SLVERR.
Offset 0 reads magic `0x4d494731`, 4 reads UI frequency 200000000,
8 reads synchronized ownership, and 12 reads ABI version 1.
Offsets 16, 20 and 24 expose the captured address, data and strobe of the
last rejected write, for AXI-Lite diagnostics.
Counters are modulo 2^32. Read snapshots at idle token boundaries and take
unsigned differences. This avoids atomicity assumptions during execution.
No memory traffic should run between a token completion and its snapshot.

Three groups start at offsets `0x100`, `0x200`, `0x300` for MIG, narrow
and wide respectively. Each word below is four bytes.

| Index | Meaning |
| --- | --- |
| 0–4 | Total accepted AR, accepted RLAST, accepted R, blocked R, blocked AR |
| 5–7 | Current outstanding reads, maximum outstanding reads, sticky error |
| 8 | Scoped cycles |
| 9–12 | Scoped accepted AR, accepted RLAST, accepted R, blocked R |
| 13 | Scoped cycles with no RVALID and at least one outstanding read |
| 14 | Scoped cycles with no RVALID and zero outstanding reads |
| 15 | Scoped cycles with RVALID for another ID |
| 16 | Scoped blocked AR |
| 17 | Scoped zero outstanding reads with no ARVALID |
| 18–22 | Scoped occupancy of 1, 2–4, 5–8, 9–16, greater than 16 |

Indices 11–15 partition index 8 exactly. Scoped data counts may exclude a
few boundary beats because ownership and taps have different pipeline delays.
The source register adds one scheduler cycle before the three UI stages.
Use unscoped accepted-beat deltas for exact byte accounting, and report the
scope-boundary tolerance explicitly when comparing to the scheduler counters.
The existing 22.05055 ms gap is a scheduler-side measurement. A MIG pending
gap, MIG backpressure and converter blockage require separate attribution.
The wide interface runs at 200 MHz with 1024-bit beats, so a saturated
512-bit MIG supplies it on only half of the UI cycles. Its missing-valid
cycles include necessary packing bubbles. Compare payload bytes per unit
time across widths; do not call every wide-interface gap avoidable latency.

The implementation is in `targets/pblaze3_layer/mig_monitor.mbt`. Export it
with `moon run --target native --release cmd/pblaze3 -- export-mig-monitor DIR`.
Physical qualification and optimization measurements remain pending.

The current implementation passes `moon info`, `moon fmt`, native warning-free
checking, and all 1,411 native tests, including the two scalar-stage regressions.
The passive monitor's 10,000-cycle replay
matches pinned Verilator exactly and passes pinned Yosys synthesis. These
checks establish software/RTL behavior, not hardware timing or performance.
[Full native regression](../artifacts/pblaze3-mig-profile-20261119-b1/validation/native-full-scalar-stage.txt).

The first placed profile design exposed CDC-10 on the combinational ownership
predicate. That route was stopped before programming. The corrected canonical
IR appends exactly one synchronous-reset register and changes only the
observation output's driver; all 1,976 previous controller nodes are identical.
The physical repair is checked against that exact IR delta, retains the placed
datapath, and must pass a registered-source connectivity guard and CDC-3 before
routing. This is a physical implementation of the MoonBit change, not a CDC
exception. Failed and superseded inputs remain in the campaign archive.

Post-route optimization also moved an existing PCIe reset-output replica.
Vivado reports its provenance as `FANOUT_OPT PLACEMENT_OPT`, rather than the
previous `FANOUT_OPT` string. The profiling build recognizes precisely these
two values for original/replica provenance. Its checks still require the same
parent and original leaf, FDPE primitive, initialization and polarity properties,
and identical C, CE, D and PRE nets. Retiming and other provenance combinations
are rejected. The guard-only bundle transition verifies that all hardware and
constraint files are byte-identical; it adds no timing exception.

Physical qualification is still pending. Before the host-clock change, the
best completed instrumentation checkpoint had setup slack -0.080 ns and
hold slack +0.011 ns. A subsequent
forced-replication/full-routing attempt regressed to -0.458 ns setup and
+0.037 ns hold and was rejected. Local pure-LUT copies passed input/function
equivalence checks but did not produce a qualified route; clock-skew
optimization also left the best setup slack unchanged. These branches are
retained as unsuccessful attempts. Vacant logical LUTs can still be used by
physical routing, and adding a LUT to an occupied slice can require repinning
existing FF outputs, so preserving those routes is not automatically legal.

Re-placing the post-route netlist exceeded capacity (205,987 combined LUTs
against 203,800 available). The subsequent clean-placement attempt started from the retained original
`opt_design` checkpoint, whose SHA-256 is
`a22e617a123114124c64623923d2957a34e7902915300ed5fa8b8d6e281c6b41`.
It adds the same canonical observation register before fresh placement. That
netlist uses 153,396 LUTs (75.27%) before placement. No failed image has been
programmed onto the card.
[Qualification status](../artifacts/pblaze3-mig-profile-20261119-b1/working-status.json).

The clean placement's first route still missed setup by 0.418 ns. A completed
post-route pass improved this to -0.211 ns, with +0.015 ns hold. Its subsequent
pass was stopped after the branch had run 82 minutes and still lagged the
retained -0.080 ns checkpoint. The completed checkpoint and all inputs/logs
were preserved; this branch produced no accepted image.
[Cancellation receipt](../artifacts/pblaze3-mig-profile-20261119-b1/clean-profile24-cancelled.txt).
A separate `NoTimingRelaxation` branch from the retained -0.080 ns checkpoint
finished at -0.126 ns setup and was rejected. Its worst endpoint is in the
XDMA descriptor logic. The structural fallback moves host DMA clock conversion ahead of
width conversion. The existing path expands 128 to 512 bits in the 250 MHz
PCIe domain before crossing to 200 MHz. The fallback crosses at 128 bits and
performs expansion in the 200 MHz domain. PCIe remains Gen2 x8, and the
accelerator, weight bridge, monitor, memory map and MIG settings stay identical.
The generated block design must prove interface widths, IDs, clocks and reset
connections; physical qualification must prove that the host width-converter
registers run at 200 MHz. This is a timing-closure candidate, not a measured
bandwidth optimization. It requires a fresh qualified image and cold upload.
The 128-bit, 200 MHz boundary has a 3.2 GB/s host payload ceiling, below the
Gen2 x8 link's 4 GB/s raw payload-bit rate before packet overhead. This tradeoff
applies to host DMA, not the unchanged 512-bit, 200 MHz accelerator/MIG path.
Cold transfer performance must be reported separately from resident inference.
The generated fallback project has passed width/ID/clock/reset connection
checks, synthesis and logic optimization. The synthesized design has 3,077
host width-converter registers, all clocked by the 200 MHz MIG clock. Physical
qualification remains in progress; it has not been programmed onto the card.

The first route of the host-clock design has setup slack −0.205 ns and hold
slack +0.018 ns. Its worst setup path is the 100 MHz scalar FP32 addition,
from `core_i/lc_n4415_reg[26]` to `core_i/lc_n65_reg[26]`: 32 logic levels,
9.881 ns data delay (2.832 ns logic and 7.049 ns routing). These are physical
timing observations, not evidence of a MIG performance bottleneck.

The final guard of `host-clock27` exposed a configuration error: the fresh
source build requested **300 MHz MAC**, while the qualified baseline uses
**282352941 Hz** after an earlier MMCM refinement. The scheduler remained
100 MHz. The MAC paths in `host-clock27` actually have a 3.333 ns period;
they must not be presented as failures at the baseline MAC frequency. The
two post-route passes ended at −0.139 ns setup and +0.018 ns hold under that
wrong MAC target, and the image was rejected before acceptance or programming.

`profile-baseline-clock15` corrects the requested MAC frequency and adds an
exact actual-clock guard to the synthesis/optimization checks. The retained
routed checkpoint can be corrected by changing only `CLKOUT0_DIVIDE_F`, with
the VCO and all other output dividers checked unchanged and all actual clocks
rechecked. `baseline-clock33` completed that physical correction but still
missed PCIe setup by 0.022 ns. No data-path or arithmetic pipeline change is
selected. New source builds must apply `scripts/pblaze3-baseline-clock-build.mbtx`
after `scripts/pblaze3-host-clock-build.mbtx`; the resulting bundle is
`profile-baseline-clock15`, whose inventory SHA-256 is
`944a773743d3ef62bcc06ab27bbeb9157576ffc1c9da317490db2302e244d076`.
The actual MAC period must pass its early guard before physical optimization.
The optional pipeline
simulations below were stopped and retained as partial runs when this clock
error was discovered; their complete replay gates did not pass.

A deferred prototype enabled `staged_scalar_add` with the current prefetch
configuration and an additional alignment stage. It registers aligned operands before
addition/subtraction, and normalized magnitude, exponent and exception
information before rounding. The scalar execution slot already has the
required edges; ordered matrix accumulation
and the two-edge scalar product accumulation remain unchanged. The CLI mode
is `staged-reduction-stripe512-prefetch-scalar`; it does not enable direct
reduction writeback. A 10,000-edge raw-bit CPU test covers signed zeros,
subnormal values, cancellation, overflow, infinities, NaNs and reset flushes.
A paired full-machine test covers 36 instruction sequences, comparing
architectural status at every edge and all 48 scratch words after execution.
Both tests pass with both stages enabled, including identical visible
instruction cycles (`validation/scalar-aligned-stage.txt`). This is
preparation for timing repair, not a measured inference speedup. The current
route will be assessed before starting another physical implementation.

The same initial route also has a −0.143 ns path from the command-payload
BRAM to a MAC input register. A separate optional payload output stage is
being prepared: payload, valid, first/last and slot metadata advance together
by one MAC edge. Command spacing, matrix accumulation order and all clocks
stay unchanged. This requires dual-clock RTL simulation before physical use;
the scalar machine's cycle-equivalence test does not validate this bridge.
The combined prepared bundle is `profile-timing-stages13`, selected through
`staged-reduction-stripe512-prefetch-scalar-payload`. Default export with all
new options disabled reproduces the original `core.sv` hash exactly:
`74401abd6b6e3879a4f6c5463a0450e5615596c5ab39b0a29436309e8e51ea76`.
Its first system simulation used the raw digital wrapper with a physical
AXI-Lite testbench address and was rejected on the first write. The subsequent
simulation uses the physical bundle's matching `0x80100000` wrapper.
The experimental exporter modes, alignment implementation, and optional
payload bridge API were removed from the active code after the clock error
was identified. Their MoonBit sources are retained under
`deferred-timing-stage-source/` in this campaign, alongside their generated
bundles. The scalar-stage build helper was moved from
`scripts/pblaze3-scalar-stage-build.mbtx` to that retained source directory.
The two regression tests remain in the active tree and now exercise the
pre-existing normalized scalar stage. The normal export still uses the
unchanged arithmetic and payload bridge of the qualified baseline.

A read-only physical probe found fifteen payload `RAMB36E1` primitives in
72-bit SDP mode with both output-register attributes disabled. Their read
clock is the MAC clock; read enable is high, output-register enables and
resets are low. Four tag bits have been absorbed into shift-register chains;
only the first-column flag and valid bit remain as separate registers.
Any physical implementation of the extra payload edge must delay all six
metadata/valid signals, including those four chain inputs, and enable the
BRAM output register clock enable. Setting only `DOA_REG` would be incorrect.
[AMD RAMB36E1 documentation](https://docs.amd.com/r/2025.2-English/ug953-vivado-7series-libraries/RAMB36E1)
requires equal `DOA_REG` and `DOB_REG` settings in SDP mode and describes the
additional read edge. `profile-payload14` prepares this change alone; its
canonical scalar IR is byte-identical to the control. It is not yet a
qualified physical implementation.

## Reproduced baseline and address-map hypothesis

At the verified baseline MAC clock, `baseline-clock33` ended at −0.022 ns
setup and +0.018 ns hold. Its remaining setup violations are inside the
PCIe clock group. Neither `pcie-cleanup34` nor PCIe-only clock/replication
attempt `pcie-physical35` improved those figures. Rerouting 43 named critical
data nets in `pcie-data36` regressed to −0.343/+0.018 ns. All were rejected,
without programming, and their reports are retained. `baseline-reroute37`
retains placement from the better checkpoint and reroutes at the verified
282.353 MHz MAC frequency. The original full routing had used the erroneous
300 MHz target. These are implementation attempts, not new inference results.

The current candidate image was retested on `.191` using the new PCIe helper
with MIG reads disabled. Three four-output warm trials produced 6.151914
tokens/s, 15,903,107 START-to-DONE cycles/output, 24.585747 ms of exposed
weight wait and 22.050096 ms of weight-owned cycles without responses.
The latter consists of 0.784342 ms waiting for a first response and
21.265754 ms between subsequent responses. These are scheduler observations;
they do not by themselves identify MIG stalls or directly removable latency.
All twelve complete 151,936-entry FP32 logits matched the qualified reference
byte for byte. Matrix payload utilization was 75.3465% of the 12.8 GB/s MIG
peak; wall-time weight payload utilization was 57.2882%. This is the old
bitstream under the new software, not an optimization result.
[Run audit](../artifacts/pblaze3-mig-profile-20261119-b1/baseline-software-check/report-v2.json).
The exposed-wait metric excludes the 0.02278 ms bank-handoff time, matching
the 6.166 tokens/s baseline's definition. The earlier derived `report.json`
included that handoff in its wait field and is superseded by `report-v2.json`;
the recorded hardware counters and throughput are unchanged.

The generated MIG has 15 row bits, 10 column bits, 3 bank bits, a 64-bit rank,
four bank machines, and `MEM_ADDR_ORDER=BANK_ROW_COLUMN`. Its bank rows hold
8 KiB; bank selection changes every 256 MiB. The deployed program's ordered
1 KiB requests therefore concentrate on one bank. Auditing all four token
programs found that 72,746 of 72,752 consecutive 16-request windows per token
touch one bank. With `ROW_BANK_COLUMN`, the same windows span 4, 5 or 8 banks.
The number of address-order row changes is unchanged, but consecutive
same-bank row changes fall from 406,154 to 452. This is a static mapping
analysis, not a prediction of accepted-request concurrency or execution time.
[Exact program audit](../artifacts/pblaze3-mig-profile-20261119-b1/address-map-audit-v2.json).

The generated AXI crossbar has `C_S_AXI_READ_ACCEPTANCE=0x0000000800000008`
and `C_M_AXI_READ_ISSUING=8`: its accelerator port accepts eight reads and its
MIG port issues at most eight, despite the read bridge's sixteen-credit limit.
For eight-request windows, 145,500 of 145,504 windows per token touch one bank
under the current mapping; the alternative spans 2–7 banks. More bridge
credits alone do not change this physical bank selection. The occupancy
histograms distinguish a full eight-request MIG queue from request starvation.

The generated controller for the configured `MT41K256M8XX-125` uses
`tRCD=13.75 ns`, `tRP=13.75 ns`, `tRTP=7.5 ns`, `tRFC=160 ns`, and
`tREFI=7.8 us`. These are configuration parameters, not measured stalls.
Their overlap and the controller's scheduling must be observed before
assigning any part of the 22.05 ms gap to row changes or refresh.
[Generated timing parameters and source hash](../artifacts/pblaze3-mig-profile-20261119-b1/mig-generated-timing.txt).

AMD documents both mappings as controller-efficiency choices, and describes
bank machines as dynamically assigned to DRAM banks. The hypothesis is that
bank interleaving can overlap row operations if the measured MIG gap has
pending reads and no return-channel backpressure. It must be checked against
the passive counters before selecting the optimization. Changing the mapping
requires a fresh upload after programming; old resident physical contents
must not be reused under a different logical-to-DRAM mapping.
[AMD UG586 address mapping](https://docs.amd.com/r/en-US/ug586_7Series_MIS/User-Interface)
and [bank machines](https://docs.amd.com/r/en-US/ug586_7Series_MIS/Bank-Machines).

## Prepared implementation of the alternative mapping

The candidate XML changes only `UserMemoryAddressMap` to `ROW_BANK_COLUMN`.
To avoid repeating synthesis if the measurements select this candidate, the
campaign also prepares a checked physical implementation of that setting.
The generated MIG has `ADDR_WIDTH=29`, `RANKS=1`, and ECC disabled. Its native
UI command register can receive the permutation
`{addr[28], addr[12:10], addr[27:13], addr[9:0]}` under the original decoder.
The unused rank bit and all column bits are preserved.

Pinned Yosys proved the unchanged vendor UI command module with that input
permutation equivalent to its `ROW_BANK_COLUMN` configuration. The induction
proof covers all outputs, arbitrary input addresses, stalls, commands and
resets, starting with matched zero register state; it closes at depth five.
The first proof used a 28-bit address bus. The retained second proof uses the
actual generated 29-bit bus and supersedes it for physical qualification.
[Proof inputs and log](../artifacts/pblaze3-mig-profile-20261119-b1/map-proof2/proof.log).

The prepared ECO changes only 18 native address-register D connections. Its
guards require independent data sources from the AXI command arbiter, no UI
register feedback in their combinational input cones, identical clock/enable/
reset controls, and zero initialization. These checks are necessary because
permuting a feedback mux output without preserving its state would be wrong.
The current routed netlist has the required structure; no mapping ECO has
been applied to the board. Passing this equivalence proof is not evidence of
timing closure, memory integrity, or improved inference performance.

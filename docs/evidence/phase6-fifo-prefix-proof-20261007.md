# Original FIFO storage-to-head supporting proof

The original direct 1x1/K2/q3 FIFO prefix passes an actual base case and
temporal induction, a watched-transfer cover, and its isolated watched-response
negative control. This establishes binary FIFO-to-registered-response-to-head
safety under one startup-reset premise. It does **not** finish Phase 6.

## Source and retained evidence

The clean tested and executed source is
`0feff5ea31450ea31086ca0a8792ca3da244994f`. The exact original device IR remains
`35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc`;
the sequential prefix IR is
`a895c99435f03c04d93fbbfbf1578723f8d2f7ef24e872d03433b6b4f29144b9`.
No production graph or public device ABI changes for this proof.

Writable preparation and execution occurred in
`/private/tmp/lunachip-fifo-prefix-inputs-20261007.g3c2z6`. Its sealed mirror is
`.phase6-fifo-prefix-proof-evidence-20261007/`. The top `outputs.sha256` records
561 files, including unsuccessful drafts, native logs, complete engine work
directories, prepared models and exported traces. Its digest is
`3529be7ce4b4bc9f82337fcb90d42063dea67cc3520ac4b229db0618236ddcb2`.
Both inventories verify, and the original support and mirror compare exactly.

The eight fresh exported inputs are sequential IR, production RTL, Boolean
RTL, standalone positive and negative bridges, typed properties, emitted names
and `bridge-inputs.txt`. The latter digest is
`502979328f42b0554d3d2987e81dfc913afa7d0a4031c86383dc5596bea02e3b`.
The positive bridge digest is
`8e550e1ef68ee8d8b6ef523f9d59eb0ad2478a8c8be8d134e72bbb9bb4cd03f4`.
Actual engine source copies match their retained selected inputs.

## Actual storage and assumptions

Independent source and prepared-model inspection accepts:

- 28 original register DFFs totaling 309 bits;
- four actual depth-three, 64-bit memory arrays totaling 768 cell bits, with
  unconstrained `INIT 192'x` per array and original-clock writes;
- four separate original-clock 64-bit registered read-result DFFs, retaining
  the original ReadOld, OneCycle and HoldLast equations;
- 59 shared source cuts totaling 805 bits, plus one independent watch selector;
- the 1,333-bit actual-storage snapshot and 273-bit observer snapshot.

The prepared memory read ports are asynchronous because the original
synchronous read response remains in its separate DFF. That transformation
does not remove read latency or read state. The SMT model retains the four
arrays and clock-sampled state.

The sole assumption establishes the first sampled joint reset. Later reset
is symbolic. No zeroed SRAM/read state, producer stability, unique caller ID,
readiness, internal progress or valid-memory-address premise is introduced.
Foreign controller cuts permit arbitrary terminal, poison and dispatch timing.

All 16 positive assertions remain: seven typed FIFO/watch/reset conclusions,
eight original enabled memory-range assertions, and the global nonrising
storage-hold assertion. The observer tracks a genuine public admission by
ordinal rank and slot, checks the four actual queued cells, then the registered
response and captured head. Same-address full pop/refill releases the old
cell comparison only after the pop commits; the old registered response still
has to match the watched packet.

## Actual jobs and causal qualification

All jobs use the pinned Yosys 0.68 / SBY v0.68 / Bitwuzla 0.9.1 image, the
existing lock, strict warning policy and multiclock global-step mapping. Jobs
ran serially with depth 20 and 600-second timeouts.

| Job | Actual result | Qualified meaning |
| --- | --- | --- |
| Positive prove | Base case steps 0–19 PASS; temporal induction PASS; SBY PASS | Unbounded selected binary prefix safety; 30 wall seconds |
| Watched-transfer cover | PASS, reached step 9; all trace formats exported | Genuine admission, SRAM pop, registered response and head capture; 13 wall seconds |
| Selected response negative | Expected FAIL, sole watched-response assertion at step 7; complete counterexample | Monitor sensitivity to checked lane 2 bit 0; 10 wall seconds |

Both witnesses establish reset at low PRE step 0, actual admission/watch at
low PRE step 2, and all four actual pop handshakes at low PRE step 4. At low
PRE step 6, the registered raw 256-bit response equals the saved admission
and actual HeadCapture is asserted. The negative changes only the checked
response bit 128 on this genuine response, making only the selected response
assertion false. Reversing that expression recovers the identical selected
positive source, with the same startup premise.

The cover then reaches low PRE step 8 with matching actual head data, held
watch state and observed response/capture. Logged step 7 and step 9 results
are not substituted for these PRE-edge witnesses. These minimal packets are
solver-chosen zero, not assumed zero. They do not separately witness full
refill, duplicate IDs or later reset; the quantified positive source permits
those cases, and prior native correspondence exercises full refill and reset.

## Qualification and validation history

Seventeen exact complete comparison-helper pairs reuse the accepted whole
19-helper SAT equivalence and negated-miter control. The complete nonhelper
RTL is unchanged, including all seven actual sized arithmetic helpers, four
address-knownness functions, four memories and eight bounds. Memory helpers
are not covered by the pointwise comparison lemma; fresh prepared-storage
inspection and the actual storage proof supply the separate qualification.
No identical helper solver run was repeated.

Clean source validation passes `moon info`, `moon fmt`, strict native check
and 192 targeted formal/exporter tests. Export succeeds. This targeted gate
does not replace the previously recorded 940-test full native gate at
`933939d`, or imply a newer full-module test count.

Retained unsuccessful drafts include reserved-name/StringView/effect errors,
a test's nested-inventory counting error and unreachable mutation fixture,
the audit's copied nonexistent add_w32 guard, and three driver StringView
type errors. The corrected audit checks the seven actual arithmetic helpers.
No solver executed before the corrected driver. The three final engine runs
needed no source repair or rerun; independent model and causal-trace review
accepts their scope. `qualification.txt` records that review separately from
the driver's initially pending classification.

## Remaining gate

This is a supporting prefix, not an ordinary whole-device typed result
receipt. Full retirement packet provenance/composition, Store data and lease
preservation, DMA cursor/address bounds, fetched three-client transport and
separately qualified direct/fetched/8x8 completion obligations remain open.
No four-state equivalence, universal MatMul arithmetic theorem, FPGA fit,
routed timing or physical execution is claimed.

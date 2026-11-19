# PBlaze3 software preparation before board arrival

The October 28 follow-up prepares the existing 2 GiB reference-accelerator
target without requiring the card or its future PCIe host. The provisional
board geometry and accepted October 26 bitstreams remain the starting point
in [the arrival runbook](PBLAZE3_BRINGUP.md). Software checks do not establish
DDR calibration, PCIe stability or measured accelerator performance.

## Software validation summary

| Gate | Result | Evidence |
| --- | --- | --- |
| Native phase before ILA additions, macOS arm64 | Info, format and native check passed; default and release tests each 1,351/1,351 passed | [Sealed native record](../artifacts/pblaze3-native-software-20261028-a1/README.md) |
| Final ILA integration native phase, macOS arm64 | Info, format and native check passed; default tests 1,358/1,358 passed | [Final native record](../artifacts/pblaze3-ila-native-20261028-a3/README.md) |
| Host control and campaign orchestration | 29 + 14 cases passed on corrected runners | [Rehearsal](evidence/pblaze3-host-rehearsal-20261028-a3/README.md) |
| Timeout and accumulated output history | 5 cases passed | [Failure evidence](../artifacts/pblaze3-host-history-20261028-a1/manifest.json) |
| JTAG process orchestration | 17 recorded cases validated, including a real 300-second child timeout | [Attempt record](../artifacts/pblaze3-jtag-process-20261028-a1/attempts.json) |
| Relocated Linux offline delivery | 14 cases and the scalar command-history audit passed | [Corrected delivery](../artifacts/pblaze3-software-delivery-20261028-a2/CORRECTED_RUNTIME.md) |
| Complete-layer host end-to-end | PASS: 32,400 program words, 2,025 descriptors, 27 inputs and 80 computed output regions | [Sealed functional campaign](../artifacts/pblaze3-full-layer-host-functional-20261028-a3/README.md) |
| Complete-layer scalar instruction model | 2,025 descriptors and all 123,200 FP32 output words pass CPU tolerance | [Model evidence](../artifacts/pblaze3-full-layer-model-20261028-a1/receipt.json) |
| Transport-connected functional backend | 7/7 Linux cases passed; all 80 outputs match a separate run of the same scalar emulator | [Backend evidence](../artifacts/pblaze3-functional-preparation-20261028-a1/README.md) |
| ILA diagnostic images | Four profiles (status, MIG, XDMA and accelerator core) pass tool, independent review and bit/LTX pairing gates | [Diagnostic guide](PBLAZE3_ILA.md) |
| Physical board qualification | JTAG/status-ILA configuration and sampled DDR calibration pass on 2026-10-29; PCIe and full memory tests pending | [Physical status record](../artifacts/pblaze3-board-verification-20261029-a1/README.md) |

## Offline Linux handoff

Use the corrected `a2` delivery below. It supersedes `a1`, whose runners
truncated cumulative command/output logs. Existing sealed `a1` artifacts are
preserved unchanged.

The delivery directory is
`/Users/kq/Workspace/lunachip-delivery/pblaze3-linux-20261028-a2`.
It contains 167 inventoried files (about 81 MiB), including the pinned Linux
`moonrun`, native host CLI, official XDMA userspace tools, precompiled Wasm
runners, both accepted October 26 production bitstreams, two arrival fixtures and the complete-layer
fixture. It requires Linux x86_64 with glibc 2.35 or newer. It needs no checkout,
MoonBit compiler or dependency download at runtime.
The four October 28 diagnostic images are separate artifacts linked in the
[ILA guide](PBLAZE3_ILA.md); this unchanged delivery archive does not contain them.

The transfer archive is
`/Users/kq/Workspace/lunachip-delivery/pblaze3-linux-20261028-a2.tar.gz`
(43,806,645 bytes). Its SHA256 is
`4717fcaec4d4d65c23c00081e84f6f9fd278f6fbb8e399df107e3ec844ac34ee`.
The [external delivery receipt](../artifacts/pblaze3-software-delivery-20261028-a2/receipt.json)
binds the archive, bundle manifest and bootstrap binaries. The
[sealed preparation record](../artifacts/pblaze3-software-delivery-20261028-a2/README.md)
includes the stage, pack and Linux test commands for reproducing this handoff.

The bundle manifest SHA256 is
`5950da84c0d12269b167317b64eeb69ab052fcd7b01e67134656179f3ef65aee`.
Authenticate the initial runtime before executing it: the Linux `bin/moonrun`
SHA256 is `ba44070aa78d89c2c6da6524d2aa782e46b18cb4a42dd31cd13bf588107089cf`,
and `runtime/deploy.wasm` is
`64dfdb2a3313119f54483af6439549e23a92e9449687adfc2b04fd7153f68ac2`.
These hashes identify this prepared delivery; they are not digital signatures.

For example, after copying the directory to `/opt/pblaze3` on Linux:

```sh
/opt/pblaze3/bin/moonrun /opt/pblaze3/runtime/deploy.wasm doctor \
  /opt/pblaze3 \
  5950da84c0d12269b167317b64eeb69ab052fcd7b01e67134656179f3ef65aee \
  /tmp/pblaze3-software-report-new
```

The report must be new and outside the bundle. `doctor` verifies file
identities, architecture/runtime, the ABI manifest, native sparse-memory
self-test and all three fixture plans. It opens no device and invokes no XDMA
tool. The bundle's `README.txt` contains the explicit host/campaign commands
for later board use; its copied reference guides retain original checkout
links and are not a replacement for those relocated commands.

The [Linux delivery test receipt](../artifacts/pblaze3-software-delivery-20261028-a2/evidence/receipt.json)
passes 14 cases from a directory outside the relocated bundle, with empty
program search and home directories. The checks cover spaces in bundle/report
paths, pinned-tree validation and failure controls, all three fixture plans,
and a complete scalar mock campaign through the precompiled campaign and host
runners. The mock writes configured results only after accepted START. A
separate dispatch check reaches the actual official `reg_rw` and expects its
failure on a nonexistent work-local file. Neither check accesses a physical
device. The root review independently verified all 167 local delivery files.
An additional [history audit](../artifacts/pblaze3-software-delivery-20261028-a2/history-audit.json)
checks all 147 retained scalar program commands, 83 read records in matching
order and 64 program words with exact readback against the original fixture.

## Campaign correctness

An accepted START sequence proves that a new launch occurred; it does not
prove that the program wrote every output. A previous successful job can leave
matching values in DDR. The campaign therefore initializes every declared
trace range with FP32 quiet NaNs and verifies the initialization before START.
The existing finite-value comparison rejects any untouched output word, even
when its previous value matched the CPU reference. Trace ranges must be word
aligned and disjoint from immutable input assets.

The original mock transport writes configured results only when a launch is
accepted. Its success fixtures exercise orchestration, not accelerator
arithmetic. Separate scalar instruction-model and LunaWave/Verilator checks
cover different levels of arithmetic and RTL behavior. Missing and partial
writes, dropped initialization, stale DONE,
changing status snapshots and post-launch faults are software failure cases.

The [sealed focused rehearsal](evidence/pblaze3-host-rehearsal-20261028-a3/README.md)
passes 29 host/control cases and 14 campaign cases.
It checks that missing/partial stores fail with `NonfiniteFloat` after an
accepted launch, and that a dropped NaN fill fails readback before START.
This rerun uses the corrected append-history runners and the unchanged native
executables, preserving every existing assertion without rebuilding the active
native cache.
The existing complete-layer fixture also passes offline planning with all
27 assets, 80 traces and 2,025 descriptors.

## Failure evidence

Transport child output must reach the evidence directory as it is produced.
A timeout or nonzero exit retains partial stdout/stderr and the command that
failed. A failed launch must not produce `completed-status.json`; a failed
campaign must not produce a successful campaign result. JTAG orchestration
also requires its completion marker and discovery identities before accepting
a successful child exit.

The [timeout evidence](../artifacts/pblaze3-host-timeout-20261028-a1/manifest.json)
records actual child processes that emit unterminated stdout/stderr fragments
before timing out or exiting nonzero. Both cases retain the fragments and
failure diagnostics, issue only the failed command and create no launch or
completion marker. Repeat this focused check from the repository root with:

```sh
moon run scripts/pblaze3-host-timeout-test.mbtx -- /tmp/pblaze3-timeout-new
```

The test builds its standalone native child in the reusable script cache.
It requires the already built native host CLI, or an explicit
`PBLAZE3_HOST_EXE` pointing to it.

Single-command checks did not detect a separate history-loss defect:
`async@0.22.4` defaults `write_file` to `CreateOrTruncate`, including when
`append=true`. All six intended append calls in the host and campaign runners
now explicitly select `OpenOrCreate`. The
[sealed history regression](../artifacts/pblaze3-host-history-20261028-a1/manifest.json)
passes five scenarios: the two original failures, two successful commands
followed by timeout or nonzero exit, and two successful campaign child calls
followed by failure. It verifies cumulative command plans and both output
streams, and rejects false completion. The same command above runs all five
cases with the corrected harness. Earlier archives retain their original
truncated histories and cannot establish cumulative-log completeness.

The [JTAG process evidence](../artifacts/pblaze3-jtag-process-20261028-a1/attempts.json)
validates 17 actual runner cases with a fake native launcher: four successful
invocations, nine child failures and four prelaunch tamper rejections. It
preserves a reproducer where a completion marker with an extra suffix wrongly
created a success receipt. The fix accepts exactly one standalone marker line,
including CRLF output. One actual 300-second timeout retained stderr and the
exception without an exit or completion receipt. The initial harness expected
stdout that the child had buffered; its failed assertion and the corrected
review of all 17 recorded cases are both retained. See the
[JTAG guide](PBLAZE3_JTAG.md) for the repeatable commands.

## Native compiler compatibility

Two private test helpers used error-raising expressions as default arguments.
The same pinned MoonBit installation failed to compile their generated native
C in the earlier whole-suite release attempt. The helpers now evaluate those
defaults in explicit `None` branches inside the function body. Supplied
arguments bypass the defaults; default evaluation order, checked errors and
all call sites are preserved. This is a source workaround, not an identified
compiler root cause. The original failed evidence remains immutable.
The two affected packages pass all 77 tests in both default and release native
profiles. Public interface inventories are unchanged.

The [complete repository phase](../artifacts/pblaze3-native-software-20261028-a1/README.md)
also passes on macOS arm64 with the pinned MoonBit toolchain:
`moon info`, `moon fmt`, `moon check --target native
--deny-warn`, and both `moon test --target native --deny-warn` and its
`--release` variant. Each full suite passes 1,351/1,351 tests. The recorded
command intervals are 56 minutes 15 seconds for default and 16 minutes
12 seconds for release; these are validation durations, not accelerator
performance measurements. Post-run snapshots match all 1,432 selected source
and manifest files and 100 public interfaces. Linux runtime validation is recorded separately in
the delivery evidence above. The full phase uses `--deny-warn`; selected
standalone script and workaround checks additionally enable warning `+73`.

After the final ILA integration changes, the
[final a8 native phase](../artifacts/pblaze3-ila-native-20261028-a3/README.md)
again passes `moon info`, `moon fmt`, `moon check --target native --deny-warn`
and `moon test --target native --deny-warn`. The default suite passes
1,358/1,358 tests in 56 minutes 48 seconds. All 1,438 selected source/manifest
inputs and 100 public interfaces remain unchanged throughout that phase.
This final phase does not rerun the release suite. Its separate final inventory
records 331 repository automation scripts; it does not claim every script was
tested by the native suite. Production board exports and the accelerator's
four digital payload files remain byte-identical to the accepted baseline.

## Complete-layer host end-to-end validation

The [completed a3 campaign](../artifacts/pblaze3-full-layer-host-functional-20261028-a3/README.md)
passes through the unchanged, relocated Linux precompiled host and campaign
runners. It uploads and verifies all 27 original assets, initializes and checks
all 80 output ranges with NaNs, writes and reads back every one of the 32,400
program words, and accepts launch sequence 1 with 2,025 completed instructions.
The functional backend computes results from those actual received program and
asset bytes. The host compares all 80 resulting regions and then verifies all
27 inputs again.

The independent [command audit](../artifacts/pblaze3-full-layer-host-functional-20261028-a3/command-audit.json)
checks all 64,819 program-loader command records and 32,419 loader read records
in order against the original program. Other campaign commands are retained
separately. The
[arithmetic audit](../artifacts/pblaze3-full-layer-host-functional-20261028-a3/arithmetic-audit.json)
verifies all 123,200 finite FP32 words against hash-pinned reference bytes, with
unchanged tolerance `1e-4 + 1e-4 * abs(reference)`. Maximum absolute error is
`3.0517578125e-5`; 45,789 words are bit-exact. Captured host bytes match the
worker's retained computed outputs by SHA256. Before/after checks also confirm
the delivery, device, worker and model identities are unchanged.

The complete preflight/campaign took 2,665 seconds in this VM, including
64,800 individual program MMIO operations. The original guest START-to-DONE
markers span 12.984929326 seconds for reconstruction, scalar computation,
rechecks and output publication. These are software execution durations,
not FPGA performance. This gate does not simulate whole-layer RTL, physical
AXI/DDR/PCIe timing or the Linux kernel driver. The exact reproducible commands
and timeout bounds are retained in the campaign README.

### Earlier attempts and supporting gates

The [retained partial attempt](../artifacts/pblaze3-full-layer-host-software-20261028-a1/README.md)
used the original 2,025-descriptor fixture through the Linux mock. All 27 input
uploads/readbacks and 80 output initializations/readbacks passed. It exposed
the append-history defect during program loading and was stopped cleanly
after 6,355 of 32,400 program words matched the original. No START occurred;
this is not a full-layer execution pass.

Program loading took 483 seconds for those words. A linear extrapolation gives
about 41 minutes for the full program on this VM/mock, before remaining result
and input-integrity checks. This is host orchestration cost, not FPGA compute
performance. The completed a3 campaign above supersedes this partial scale
attempt; the earlier evidence remains unchanged.

The fresh [scalar instruction-model run](../artifacts/pblaze3-full-layer-model-20261028-a1/receipt.json)
executes the original 2,025 descriptors with all 27 input assets and checks
all 80 traces (123,200 FP32 words). Every output is finite and satisfies
`abs(error) <= 1e-4 + 1e-4 * abs(reference)`; maximum absolute error is
`3.0517578125e-5`. All computed bytes also match the previously retained
ordered scalar model. This checks instruction arithmetic on the exact fixture;
it is not a whole-layer RTL simulation or a host transport test. The functional
backend's separate checks are recorded below; the completed a3 campaign adds
the full command and numerical audit across the host transport.

The [corrected a2 host run](../artifacts/pblaze3-full-layer-host-software-20261028-a2/README.md)
retains complete cumulative history through 19,303 program writes and 19,302
completed program readbacks. All match the original fixture. A register read
at `0x32d98` exceeded the unchanged 2,000 ms subprocess deadline while parallel
functional-test file copying caused VM I/O contention. It stopped before START
after 2,124 seconds. This is a failed scale attempt, not arithmetic evidence.
Its full 38,625 command records and 19,321 read records are retained and audited.

The [new functional backend](PBLAZE3_FUNCTIONAL_MODEL.md) reconstructs the
actual uploaded program and asset chunks, computes all outputs with the pinned
scalar emulator, and publishes DONE only after output publication and input
rechecks. Atomic START/DONE markers avoid premature visibility. Seven focused
Linux cases pass, including corrupt program/asset, missing NaN initialization,
model failure, timeout and stale terminal state. The positive case's 80 outputs
match the separate standalone scalar-model run byte for byte. Both use the same
emulator implementation. Its 12.645-second START-to-DONE
interval includes file-backed reconstruction and publication; it is not an
FPGA performance measurement. The completed a3 full host campaign uses
the unchanged portable runtime and fixed per-tool deadlines, after competing
seed/copy processes have exited. Its completion polling bound is explicitly
600,000 ms to accommodate model work; the whole campaign is bounded at 90 minutes.

## Hardware gates still outstanding

After arrival, follow the staged JTAG discovery, DDR-only image, PCIe/driver,
DDR alias test and accelerator workload sequence in the runbook. The Linux
kernel driver must match the actual host kernel. Board identity, DDR chip
markings and connector wiring still require physical confirmation. The
prepared workloads cover the existing Qwen reference layer; full Qwen3-0.6B
inference and token throughput are outside this software preparation.

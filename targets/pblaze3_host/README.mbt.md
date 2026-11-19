# PBlaze3 host preparation

This package is the host-side contract and bring-up tooling for the provisional
`pblaze3-2gib` target. It does not claim physical DDR calibration, PCIe link
stability, or a working full-model Qwen runtime. Native package tests and the
mock tool campaign require no FPGA and never open hardware device nodes.

The [software preparation follow-up](../../docs/PBLAZE3_SOFTWARE_PREPARATION.md)
records the current offline handoff and failure-path checks.

The target is `xc7k325tffg900-2`, with an explicit 2,147,483,648-byte DDR aperture
at DMA address zero. The supplied vendor project's 4GiB setting is rejected.
The AXI-Lite translation is `0x40000000`, but `reg_rw /dev/xdma0_user` uses
**BAR-relative offsets**. Passing the translation as a userspace offset is wrong.

```mbt check
///|
test "PBlaze3 upper memory is addressable" {
  let manifest = @pblaze3_host.default_manifest()
  manifest.check_range(0x7ffffff0, 16)
  let command = @pblaze3_host.register_command(
    manifest,
    "/dev/xdma0_user",
    0x80,
    None,
  )
  assert_eq(command.arguments[1], "0x80")
}
```

## Build and offline checks

Run from the repository root:

```sh
moon test targets/pblaze3_host --target native --deny-warn
moon build cmd/pblaze3_host --target native --deny-warn
moon run scripts/pblaze3-host.mbtx -- plan
moon run scripts/pblaze3-host.mbtx -- selftest
moon run scripts/pblaze3-host-test.mbtx -- /tmp/pblaze3-host-test-unique-run
```

The script defaults to `_build/native/debug/build/cmd/pblaze3_host/pblaze3_host.exe`.
Set `PBLAZE3_HOST_EXE` to an absolute path when using another build directory.
Script dependencies pin `moonbitlang/async@0.22.4`; the repository pins the
native CLI dependencies. The current async dependency emits a duplicate-import
warning in script mode; the package's strict native checks are warning-free.

`cmd/pblaze3_host/mock_tools` is an offline test executable. It refuses `/dev/`
device paths. The integration script links its executable under the three
upstream tool names, and tests the complete production orchestration against
file-backed memory and register fixtures. It is not a replacement driver.

## Linux XDMA prerequisites

Use AMD/Xilinx's existing kernel driver and userspace tools, not a custom
kernel module. The command interface was checked against the official
[driver repository](https://github.com/Xilinx/dma_ip_drivers/tree/a918c5196a09f95756af244a607d543d9dce5bfb/XDMA/linux-kernel).
The inspected revision is `a918c5196a09f95756af244a607d543d9dce5bfb`.
The [upstream README](https://github.com/Xilinx/dma_ip_drivers/blob/a918c5196a09f95756af244a607d543d9dce5bfb/XDMA/linux-kernel/readme.txt)
describes building and installing the driver on the intended Linux kernel.

Build `dma_to_device`, `dma_from_device`, and `reg_rw` from that checkout's
`XDMA/linux-kernel/tools` directory. Record the checkout revision, tool hashes,
Linux kernel version, loaded module version, and `lspci -vv` output in board
evidence. The runner does not install a driver, program the FPGA, or check a
binary's provenance. A supplied tool directory is an explicit execution input.
It records each used tool's resolved path and SHA256 in the run directory.
The pinned `reg_rw` prints `Read 32-bit value` (singular); the parser accepts
that exact prefix and the older mock's plural form. Run
`moon run scripts/pblaze3-reg-output-test.mbtx -- NEW_OUTPUT` to check this
contract, unsigned values through `0xffffffff`, and malformed output rejection.
It does not change device permissions or invoke `sudo`.

The following examples assume the tools live at `/opt/dma_ip_drivers/XDMA/linux-kernel/tools`
and this board enumerates as `/dev/xdma0`. Choose the actual board explicitly:
device numbering can change after reprogramming or reboot.

## Arrival sequence

For the separate **DDR-only smoke image**, use `ddr-smoke-probe` and
`ddr-smoke-memtest` first. This image exposes DMA memory and GPIO; it has no
LunaChip accelerator ID or capability registers. Its added read-only GPIO
channel 2 at BAR offset `0x08` exposes calibration, PCIe link and UI reset release
in bits 0, 1 and 2. `ddr-smoke-memtest` checks all three before any DMA write and
records `image_profile: ddr-smoke`, ABI check false and health check true:

```sh
moon run scripts/pblaze3-host.mbtx -- ddr-smoke-probe /dev/xdma0
moon run scripts/pblaze3-host.mbtx -- ddr-smoke-status /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-ddr-status-new
moon run scripts/pblaze3-host.mbtx -- ddr-smoke-memtest /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-ddr-only-new smoke 42
```

Repeat with `full` and a new directory for the complete 2GiB test. This status
register belongs to the newly generated DDR smoke image, so verify bitstream
identity before interpreting it. It does not identify the image by itself.
The untouched vendor-baseline image has no such health register; explicit
`ddr-raw-probe` and `ddr-raw-memtest` support DMA-only diagnostics and record
both ABI and health checks false. Standard `memtest` keeps its strict accelerator
ABI check and rejects either DDR-only image.
After the DDR gate, load the accelerator image and follow the sequence below.

1. Verify the FPGA image and physical board revision, DDR geometry, power,
   cooling, PCIe enumeration/link width/speed, and driver binding. A 2GiB host
   aperture alone does not validate the MIG geometry or DDR wiring.
2. Probe character-device nodes, then read and validate the image ABI:

   ```sh
   moon run scripts/pblaze3-host.mbtx -- probe /dev/xdma0
   moon run scripts/pblaze3-host.mbtx -- status /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-status-new
   ```

3. With no other process using the board, run the **destructive** memory tests
   before loading weights. Every command requires a new evidence directory:

   ```sh
   moon run scripts/pblaze3-host.mbtx -- memtest /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-smoke-new smoke 42
   moon run scripts/pblaze3-host.mbtx -- memtest /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-full-new full 42
   ```

   Smoke covers ten 4KiB regions around 256MiB, 512MiB, 1GiB and 2GiB boundaries.
   Full writes every byte of 2GiB in 1MiB chunks. Both write **all** regions
   before reading **all** regions, so mirrored banks cannot pass by returning
   the most recently written value. Patterns depend on every address bit and
   a deterministic seed. Repeat with another seed and across cold starts before
   declaring the DDR stable. The first differing byte and address are reported.

4. Upload weights or a small fixture and verify every returned byte:

   ```sh
   moon run scripts/pblaze3-host.mbtx -- upload /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 0x10000000 weights.bin artifacts/pblaze3-upload-new
   moon run scripts/pblaze3-host.mbtx -- check /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 0x10000000 weights.bin artifacts/pblaze3-check-new
   ```

   `upload` reads the source in at most 1MiB chunks, writes each chunk, and
   compares device readback with the source. `check` only reads the device.
   The whole file range is checked before any device write. Source files must
   remain unchanged during the operation. These commands are diagnostic loaders,
   not throughput benchmarks or a model-serving runtime.

5. Load the generated 16-word little-endian program and optional FP32 scratch
   image; then start the specified instruction count and wait up to 30 seconds:

   ```sh
   moon run scripts/pblaze3-host.mbtx -- load-program /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 program.bin artifacts/pblaze3-program-new
   moon run scripts/pblaze3-host.mbtx -- load-scratch /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 scratch.bin artifacts/pblaze3-scratch-new
   moon run scripts/pblaze3-host.mbtx -- start /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 1 artifacts/pblaze3-start-new
   ```

   Program images contain 1..2048 instructions and are multiples of 64 bytes;
   scratch images are word-aligned and at most 128KiB. The instruction count is
   explicit. Every program/scratch word is read back and checked. Upload uses word MMIO; it is not a fast
   loading path. Read results from DDR with `read` (at most 1MiB per invocation)
   or read scratch words through `reg-read`. Compare with the reference fixture.

`PBLAZE3_RUN_TIMEOUT_MS` configures the completion deadline, default 30000,
accepted range 1000..600000 milliseconds. Set it to 120000 for the first complete
layer campaign if additional bring-up margin is desired. It is validated before
any MMIO operation and recorded in the execution directory. Thirty seconds is
a bring-up budget, not a measured PBlaze3 execution time; board timing remains
unverified. The individual 2-second MMIO and 10-second DMA deadlines are unchanged.

## Complete fixture campaigns

`scripts/pblaze3-campaign.mbtx` consumes the existing PRX100 `fixture.json`
schema directly, including asset hashes, descriptor count, CPU trace references
and the original `1e-4 + 1e-4 * abs(reference)` tolerance. It rejects nonfinite
values and retains exact-word counts and maximum errors. It checks every
declared trace, not just the final tensor.

Pin the manifest SHA256 explicitly. `plan` validates all inputs without opening
hardware. `run` uploads and verifies all assets, fills every trace with FP32
quiet NaNs and verifies that fill, loads and reads back the program and optional
scratch image, starts the exact descriptor count, waits for
completion, reads every trace, performs the CPU comparisons, then verifies all
original assets again. Inputs are rehashed at completion. Trace ranges must be
word aligned and disjoint from immutable input assets. The NaN fill makes a
missing or partial STORE fail even when a previous job left correct results
in DDR; an incremented launch sequence alone cannot prove output was written.

```sh
moon run scripts/pblaze3-campaign.mbtx -- plan FIXTURE_DIRECTORY MANIFEST_SHA256 NEW_OUTPUT
moon run scripts/pblaze3-campaign.mbtx -- run /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 FIXTURE_DIRECTORY MANIFEST_SHA256 NEW_OUTPUT
```

The integrated small workloads exported by `cmd/pblaze3_axi layer-replay`
include `workloads.json`. Convert these to binary fixtures before board arrival:

```sh
moon run cmd/pblaze3_host --target native -- prepare-smoke REPLAY_DIRECTORY/workloads.json NEW_FIXTURE_ROOT
```

`NEW_FIXTURE_ROOT/jobs.json` lists each fixture directory and its manifest hash.
The two jobs exercise scalar load/add/store near the 2GiB boundary and a packed
BF16 matrix at the upper DDR boundary. The latter has an explicit initial
scratch image. Run them before the complete Qwen layer fixture. These are
reference-accelerator tests, not full-model inference.

The durable arrival fixtures are under
`artifacts/pblaze3-host-preparation-20261026/arrival-fixtures`. After the DDR-only
gate and loading the accelerator image, run these two exact commands on Linux
from the repository root, using fresh output directories:

```sh
moon run scripts/pblaze3-campaign.mbtx -- run /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-host-preparation-20261026/arrival-fixtures/scalar-high-memory 884005e06d223a2d170f3cae4fbf6bc82110750166d19d9ee7e1470fd901d002 artifacts/pblaze3-scalar-board-new
moon run scripts/pblaze3-campaign.mbtx -- run /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-host-preparation-20261026/arrival-fixtures/packed-matrix-upper-bound 112fabfc38bddc2367859a3dcbb8ce02e6e748c48da9eab0c1ebb722dd781ae4 artifacts/pblaze3-matrix-board-new
```

The pins identify the actual instruction/data files through their manifests;
changing fixture bytes requires regenerating and reviewing the manifest pin.

The integration test covers transport/control and campaign scenarios, including
wrong manifest pins, missing or partial output writes, corrupt output, and
tampered input rejection. The mock writes configured results only on an accepted
launch. It does
not simulate accelerator arithmetic; the separate integrated LunaWave/Verilator
tests provide that evidence.

## ABI and error behavior

| Offset | Meaning |
| --- | --- |
| `0x00`, `0x04` | Device ID `0x50423330` / ABI `0x00010001` |
| `0x08`, `0x0c` | healthy/busy/done/fault bits 0..3 / error |
| `0x10`, `0x14` | Write 1 to start / instruction count |
| `0x18`..`0x34` | PC, state, opcode, cycles low/high, instructions, products, DDR beats |
| `0x38` | Accepted-START sequence, wrapping UInt32; increments only when START is accepted |
| `0x80`, `0x84` | DDR capacity low/high: `0x80000000`, `0` |
| `0x88`, `0x8c` | Address bits `31` / provisional-board flag bit 0 |
| `0x20000`..`0x3ffff` | Program RAM |
| `0x40000`..`0x5ffff` | Scratch RAM |

`status` rejects an incorrect ID, ABI, memory capacity, address width or unknown
capability flags. Writes and bulk reads require healthy, idle, fault-free status.
This check is not a cross-process lock: use one host controller at a time.
Status fields are read individually and counters are not an atomic snapshot.
Sequence reads bracket each status snapshot; a changing sequence causes a fresh
snapshot. The host requires ABI 1.1 because posted MMIO writes alone do not
acknowledge that hardware accepted START. It captures the prior launch sequence,
writes and reads back the instruction count, issues START, then requires exactly
the next sequence modulo 2^32 and the expected count before accepting DONE.
Stale DONE remains pending, unexpected sequences fail, and a dropped START
times out. A fast job may finish before BUSY is observed and still pass.

Upstream tool calls keep arguments separate, with 2-second MMIO and 10-second
DMA process timeouts. Nonzero exit codes, missing read output and short read
files fail the run. The portable callback transport separately handles positive
short progress and rejects zero progress, invalid counts and reported errors.
DMA writes are verified by readback in upload and memory-test workflows.

Evidence includes the host manifest, structured commands, tool stdout/stderr,
status words, and test configuration. Tool output is streamed to the logs so
partial diagnostics survive nonzero exits and process timeouts. Successful complete campaigns add `PASS`;
failed campaigns retain diagnostics without a pass marker. A timed-out tool
does not prove the device transaction was canceled. Stop subsequent operations
and inspect/recover the device before retrying. The runner never auto-resets it.

`expected.bin` and `actual.bin` are bounded working files reused within the new
campaign directory, and retain the current chunk on a mismatch. Program source,
weight source and deterministic test seed/address map remain the recovery inputs.
Seal a successful campaign only after collecting image/tool identities and the
physical-board evidence. Existing evidence directories are never reused.

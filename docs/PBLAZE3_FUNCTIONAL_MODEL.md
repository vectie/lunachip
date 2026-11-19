# PBlaze3 functional arithmetic rehearsal

This software-only backend runs the original full-layer program through the
unchanged host campaign, a file-backed transport model, and the existing scalar
instruction emulator. The simulated device computes output bytes from the
program and weights received through that transport.

It is a **one-shot functional model**, not a cycle-accurate or general device
model. It does not execute LunaWave or RTL, model MIG/XDMA timing, or establish
that a physical FPGA works. The fixture covers one Qwen layer across four token
positions: 2,025 descriptors, 32,400 program words, 27 assets, and 80 output
regions containing 123,200 FP32 words.

The fixture manifest is pinned to
24ef729d9eada00f624dc75c36a874c2e4dbe35d2396d49e3c82d34129e81a98.
The program is pinned to
5fa60543411f4dd002c34e458f235977708a4bf7b8e15d3d1969c47c32860ce4.
All original asset hashes and comparison tolerances remain unchanged.

## Execution

The native executable built from
[pblaze3-functional-device.mbtx](../scripts/pblaze3-functional-device.mbtx)
provides the three userspace tool interfaces: reg_rw, dma_to_device, and
dma_from_device. Point three fresh symlinks at that executable and set
PBLAZE3_FUNCTIONAL_PREFIX to a fresh absolute /tmp/.../x prefix.
It rejects actual device paths.

Start the native worker before the unchanged campaign:

    WORKER worker PREFIX FIXTURE MODEL FRESH_EVIDENCE START_TIMEOUT_MS

For a complete host upload, use a 5,400,000 ms START timeout. The worker creates
FRESH_EVIDENCE/ready only after validating the pinned fixture. A launcher must
wait for this marker, then run the normal campaign with the new tool directory
and prefix. It must retain both child streams from process start, bound both
children, wait for both successful exits, and pin the device, worker, and model
executables before and after the run.

The transport stores each DMA transfer in PREFIX.memory-HEX_ADDRESS and each
MMIO word in PREFIX_user.reg-DECIMAL_OFFSET. The worker assembles assets from
the actual 1 MiB transport chunks and reconstructs all 32,400 program words
from those register files. It does not substitute canonical program or asset
payloads. Canonical CPU arrays are loaded solely as comparison inputs inside
the existing emulator and host checker.

An accepted START requires count 2,025, advances the launch sequence to one,
and atomically publishes PREFIX.model-request by writing a fresh temporary
file and renaming it in the same directory. Status remains BUSY while the worker runs.
Host writes are rejected after START; repeated START does not advance the
sequence. The worker checks the exact program hash, count, final HALT, asset
hashes, and quiet-NaN output poison. The existing model initializes its scratch
with quiet NaNs and rejects nonfinite or uninitialized reads.

After arithmetic completes, the worker rechecks the program, count, sequence,
all input chunks, and output poison. Only then does it publish the 80 computed
output files and atomically publish PREFIX.model-done with the same temporary
write and rename protocol. Failures caught after startup validation are recorded
as PREFIX.model-fault without publishing DONE. Startup rejects stale request,
terminal, or sequence markers without overwriting them. Reset, repeated jobs,
and cycle-performance counters are
outside this backend's scope.

An I/O error during publication can leave partially updated fake-DDR files;
these are not completed results. DONE is published only after all writes and
readbacks succeed. Reconstructible staging and fake-DDR copies use NoSync to
avoid unnecessary storage barriers. Unique receipts and terminal commits keep
their normal durable writes, and retained output hashes identify the computed
bytes.

The accepted-launch.json receipt records sequence, program_count,
program_words, program_sha256, and last_halt_pc. The final receipt.json records
PASS, model and fixture identities, launch_sequence 1, instructions 2025, and
every computed output's address, word count, and hash.

## Reproducibility and tests

Run repository commands from the LunaChip checkout.
[pblaze3-functional-prepare.mbtx](../scripts/pblaze3-functional-prepare.mbtx)
transfers only the new standalone sources and model-source snapshots to a fresh
Linux working directory, builds helpers in an external reusable script cache,
verifies the already installed scalar emulator, and runs focused tests. It
does not rebuild the repository native module or overwrite another
rehearsal's tools.

The existing Linux model is:

    /work/builds/prx100-layer-stage-20261018-a1/project/_build/native/release/build/cmd/prx100_layer/prx100_layer.exe
    SHA256 2b85af5e22e44b5abaef1169b811a612176d22d5926b6d5596ed6ac5d3c4f89d

Its emulate.mbt and cpu_math.mbt match current source bytes. The worker's
optional export-model CHECKOUT FRESH_OUTPUT command records a standalone
reproduction using the complete unchanged emulator body and unchanged
float_bytes/hash helper blocks.

Focused tests cover a complete computed result, corrupted uploaded program,
corrupted uploaded asset, missing output poison, a failing arithmetic process,
START timeout, and stale terminal state. They also check BUSY, rejected writes
and STARTs, no output publication before START, unchanged outputs for the
tested failures before publication,
and no false DONE. Their initial transport state is seeded directly. The
[completed full host integration gate](../artifacts/pblaze3-full-layer-host-functional-20261028-a3/README.md)
instead performs every upload/readback through the unchanged precompiled Linux
campaign, then checks 80 computed regions and all 27 inputs. Its README records
the exact worker/campaign commands and timeout bounds; its independent audits
cover all 32,400 program words and 123,200 FP32 outputs.

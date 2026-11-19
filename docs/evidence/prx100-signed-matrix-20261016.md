# First PRX100 signed matrix workloads, 2026-10-16

Three signed matrix products pass on the physical PRX100 through UART, using
the existing1x1/K2 smoke image and unchanged portable accelerator. All157
request/reply exchanges pass CRC, envelope, sequence, status and declared
payload checks. This is the first retained accelerator workload execution on
this board, beyond the earlier UART/BRAM transport test.

| A, shape1x2 | B, shape2x1 | Independent integer reference | Physical INT32 result |
| --- | --- | --- | --- |
| [-7,5] | [9,-4] | -7×9 +5×-4 = -83 | -83 (`0xffffffad`) |
| [-128,127] | [-128,-127] | 16384 -16129 =255 | 255 (`0x000000ff`) |
| [12,-12] | [11,11] | 132 -132 =0 | 0 (`0x00000000`) |

Each reference is computed with ordinary host integer multiplication and
addition, independently of the hardware generator/simulator, and checked
against the literal result above before issuing hardware commands. Inputs
are signed INT8; output is signed INT32. Both reduction terms are exercised.

## Actual board path and configuration

CPU_TAG remains attached as Digilent `ME10E06D1010A`, FPGA `xc7a100t`, IDCODE
`0x13631093`. The physical UART is CP2102 `10c4:ea60`, serial `0001`, at
115200baud,8N1, no flow control. The same isolated Ubuntu22.04 guest and its
identified by-id serial path are used. No new host/guest package, USB mapping
or VM configuration change was required for this campaign.

The previously programmed smoke image remains running. No reprogramming or
flash write was performed. Its bitstream and the exact request/reply codec
binary are hash-checked before and after the run. Bitstream SHA256:
`203908ac91ad52c1b4cf77cc31667c5f392acb9aef8c5f89acca8858d275386a`.
The [build ledger](prx100-vivado-build-20261015.md) retains the corresponding
source snapshot, canonical IR and routed50MHz timing. The
[physical UART/BRAM ledger](prx100-uart-bram-20261016.md) retains the preceding
programming and cable/driver setup.

## Complete accelerator transaction

For each case, the host resets the session, initializes every descriptor,
both operand words, the result sentinel and adjacent guard words, then
uploads one four-entry ABI0.2 ring. Ring base/origin are0; descriptors occupy
bytes0..127, A starts at256, B at260, and C at512. All slot selectors are0.

| Command | Shape / K | Base / stride | Completion bytes |
| --- | --- | --- | --- |
| LoadA | 1x2 | 256 /2 | 2 |
| LoadB | 2x1 | 260 /1 | 2 |
| MatMul | 1x1 / K2 | 0 /0 | 0 |
| StoreC | 1x1 | 512 /4 | 4 |

Each32-byte descriptor includes zero reserved bytes and version0.2. All eight
words per descriptor are uploaded before Configure and Publish(producer4).
The host cannot read C while completions are held: the deliberate early read
returns busy(status4), without consuming a completion. The host then drains
all four ordered, fault-free completions before reading C. IDs are101..104,
201..204 and301..304, separately identifying the three batches. All fault
addresses and unused completion words are zero.

For every case:

- C replaces sentinel `0x13579bdf` with the exact reference value.
- Guard words at508=`0xa5a5a5a5` and516=`0xdeadbeef` remain unchanged.
- Status is `[33,4,4,4,0]`: configured and quiescent, producer/consumer/retired4,
  zero queue occupancy and no held completion/fault.
- Compute counters are `[3,0,2,0,65538]`:3 elapsed cycles,2 active cycles,
  2 accepted reduction steps and1 result capture. These counters describe
  the latest MatMul, not end-to-end UART/DMA latency or physical throughput.
- All five diagnostics words are zero; a final Completion returns empty
  (status5), confirming no extra retirement.

All commands succeed on their first attempt; no automatic mutation retry is
performed. The board is left quiescent after the final case. Completion of the
run was confirmed at2026-10-16 01:34:02UTC /09:34:02 China time.

## Reproduction, native checks and scope

[`scripts/prx100-signed-matrix.mbtx`](../../scripts/prx100-signed-matrix.mbtx)
contains the host reference, ABI0.2 serialization, upload, UART exchange and
capture checks. Inside the existing guest with the baseline Moon toolchain:

```text
moon run /work/prx100-signed-matrix-20261016.mbtx -- run /work/builds/prx100-signed-matrix-NEW_RUN
```

Use a new output root. This command resets logical accelerator state and
writes the declared BRAM addresses. The actual campaign root is
`/work/builds/prx100-signed-matrix-20261016-a1`.

The new `validation/prx100_board/matrix_wbtest.mbt` runs the same three K2
cases through the MoonBit shell and unchanged canonical core. All10 board
validation tests pass. Interface generation, formatting and warning-strict
native checking pass. The full strict native suite passes1,089/1,089, with
zero failures; its complete log is retained. The206 captured production
source/interface identities remain unchanged.
Only host automation, validation and documentation were added or updated.

This demonstrates1x2×2x1 signed products on the1x1/K2 smoke configuration.
It does not establish Array8 execution, a general workload coverage claim,
fault/soak qualification, end-to-end performance or the full Phase6/7 gate.

Raw requests/replies and serial traffic for all157 exchanges, exact driver,
operand/reference fixtures, descriptor bytes,12 completions, counters,
diagnostics, guard checks, native logs and source identities are sealed in
`artifacts/prx100-signed-matrix-20261016`, with a verified SHA256 inventory.
The full native log uses deterministic gzip with expanded byte comparison.
Compiler caches stay outside the archive; working originals and all previous
sealed archives are preserved. No task file or recovery volume was removed.

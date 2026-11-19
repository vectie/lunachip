# Physical PRX100 Array8/K16 matrix workload, 2026-10-16

The PRX100-D runs the qualified8x8/K16 bitstream and passes a signed
8x16 by16x8 INT8 matrix multiplication through UART. All64 INT32 results
match an independent host integer calculation. All241 request/reply exchanges
pass CRC, framing, sequence, status and expected payload checks. Four ordered
completions report zero faults; both adjacent result guard words are unchanged.
The portable core was not edited for this campaign.

## Programming and source identity

The existing [routed Vivado build](prx100-vivado-build-20261015.md) is programmed
through CPU_TAG, Digilent serial `ME10E06D1010A`, at1MHz JTAG. The script requires
exactly one target and device, FPGA family `xc7a100t` and IDCODE `0x13631093`.
After programming, both configuration DONE signals are1 and CRC_ERROR is0.
Only volatile configuration is written. The board retains this image until
reconfigured or powered off.

Bitstream: `/work/builds/prx100-array8-vivado-20261015-a1/output/prx100.bit`.
SHA256: `3e575862fa4520ddbd23fab02e516d46560584715db1b6667152b4bbbc66f55b`.
Vivado2025.2 executable/version pins and bitstream hashes are checked before
programming; the bitstream hash is checked again after programming and after
the workload. The codec binary is also checked before/after the workload:
`7ff8436577763d258681e21960e098aa0f71ce98580ade2a23a7ae9008844f5c`.

The build uses the retained MoonBit/LunaWire canonical accelerator and board
shell, emitted SystemVerilog and the target-specific normalization recorded
in the build ledger. Its guest source snapshot is
`8a4faa2c00d41ce2389b058586bd65a55beaa5e8`. No regeneration or synthesis change
was needed. The retained Array8 core canonical digest remains
`37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8`.

## Workload and complete checks

CP2102 serial `0001` provides115200baud,8N1 UART in the isolated Ubuntu22.04
guest. Identify reports shape8x8, capacityK16 and4096 host bytes. No host OS,
package, service, VM configuration or USB mapping change was needed.

The exact128-byte row-major operands are retained in `fixture.json`. Values
are deterministic mixed signed INT8, with explicit−128 and127 entries. The
reference uses ordinary signed multiplication/addition in a three-loop host
calculation, independently of the hardware generator and simulator. Every
output uses all16 reduction terms. The first result row is
`[2025,-16908,16126,20232,-11246,15132,3110,-12240]`; all eight rows and their
matching reference values are retained in `receipt.json`.

After logical Reset, the host initializes all32 descriptor words, both128-byte
operands, all64 result sentinel words and both guards before Configure/Publish.
ABI0.2 descriptors occupy bytes0..127, ring origin/base0, all slot selectors0.

| ID / command | Shape / reduction | Base / byte stride | Completion bytes |
| --- | --- | --- | --- |
| 801 LoadA | 8x16 | 256 /16 | 128 |
| 802 LoadB | 16x8 | 512 /8 | 128 |
| 803 MatMul | 8x8 /K16 | 0 /0 | 0 |
| 804 StoreC | 8x8 | 1024 /32 | 256 |

The deliberate early Read32 returns busy(status4) while completions remain
held. The host drains all four ordered completions and then verifies all64 C
words, replacing sentinel `0x13579bdf`. Guards at1020=`0xa5a5a5a5` and
1280=`0xdeadbeef` are unchanged. No transaction required a retry.

Final Status is `[33,4,4,4,0]`: configured and quiescent with all four descriptors
consumed/retired, no queued work and no held completion/fault. Counters are
`[31,0,30,0,4194334]`:31 elapsed compute cycles,30 active/accepted systolic
steps and64 captures. All five Diagnostics words are0. A final Completion
returns empty(status5). These compute counters do not measure UART/DMA latency
or qualify end-to-end throughput.

## Reproduction and retained evidence

Inside the existing guest, using its baseline Moon toolchain:

```text
moon run /work/prx100-array8-program.mbtx -- program /work/builds/prx100-board-array8-NEW_RUN
moon run /work/prx100-array8-matrix.mbtx -- run /work/builds/prx100-array8-matrix-NEW_RUN
```

The workload currently pins the actual programming receipt
`/work/builds/prx100-board-array8-20261016-a1`; change that receipt path in the
driver for a new programming campaign. Both commands require fresh output
roots. Repository sources are `scripts/prx100-array8-program.mbtx` and
`scripts/prx100-array8-matrix.mbtx`. Actual workload root:
`/work/builds/prx100-array8-matrix-20261016-a1`.

All10 PRX100 native board tests pass. Warning-strict native checking passes
for `targets/prx100`, `cmd/prx100` and `validation/prx100_board`; formatting
passes for the repository and both new scripts. The207 captured production
source/interface identities are unchanged during this campaign.

Repository-wide interface generation, strict checking and testing were
attempted but stopped on preexisting work in progress in
`validation/formal/fetched_sram_bindings.mbt`: unbound
`fetched_sram_generation_support` / `fetched_sram_read_support` and an unused
observer. These files were left untouched. This campaign does not claim a new
full-suite pass; the earlier1,089/1,089 checkpoint is in the
[signed smoke ledger](prx100-signed-matrix-20261016.md).

`artifacts/prx100-array8-matrix-20261016` retains the exact as-run drivers,
programming Tcl/logs/device status, operands/reference, descriptor bytes, all
241 raw requests/replies and serial logs, completions, counters, diagnostics,
source/tool identities and validation logs, with a verified SHA256 inventory.
The existing build archive retains the bitstream and RTL. Compiler/Vivado
caches remain outside the archive. All originals and older sealed archives
are preserved; no task file or recovery volume was removed.

This establishes one full signed Array8/K16 workload on the physical board.
Broader workload, fault/soak, throughput, external-adapter and full Phase6/7
qualification remain open.

# First FPGA target recommendation

Use the Digilent Arty A7-100T for the first physical FluxTile demonstration,
subject to board budget, software access and target-specific implementation.
The goal is a reproducible signed 8x8 workload on a real board, not production
LLM serving. This recommendation does not change the unfinished Phase 6 gate
or authorize a purchase, vendor installation or physical deployment.

## Board choice

Vendor-listed prices below were checked on 2026-10-07. They are not delivered
regional quotes or confirmation of immediate stock.

| Board | Compute and memory | Listed price | Project role |
| --- | --- | --- | --- |
| Arty A7-100T | Artix-7 XC7A100T, 240 DSP slices, 4,860 Kbits block RAM, 256 MB DDR3L; USB-JTAG and USB-UART | US$322 | First target; bring up without a processor boot stack |
| Nexys A7-100T | Same FPGA resource class, 240 DSP slices, 4,860 Kbits block RAM, 128 MiB DDR2; USB-JTAG/UART and more teaching peripherals | US$349 | Substitute if easier to procure; no additional compute capacity |

Specifications and prices: [Arty vendor page](https://digilent.com/shop/arty-a7-100t-artix-7-fpga-development-board/)
and [Nexys vendor page](https://digilent.com/shop/nexys-a7-amd-artix-7-fpga-trainer-board-recommended-for-ece-curriculum/).

The Kria KV260 is an alternative if a processor-hosted accelerator platform and
growth capacity matter more than minimal bring-up. Its K26 provides 1,248 DSP
slices, 144 block RAMs and 64 UltraRAM blocks; the kit has 4 GB DDR4. Using the
processor and DDR adds firmware, host-bridge and memory integration work. This
is an engineering tradeoff, not evidence that Arty is faster or cheaper in every
region. [K26 resources](https://docs.amd.com/r/en-US/ds987-k26-som/Programmable-Logic),
[KV260 specifications](https://docs.amd.com/r/en-US/ds986-kv260-starter-kit/Product-Details).

## Capacity and implementation limits

The retained [8x8/K16 synthesis profile](evidence/phase6-synthesis8-20261005.md)
has 32 operand memories of 16x8 bits, two result memories of 64x32 bits and
four descriptor memories of 3x64 bits. Their total logical capacity is
`32*16*8 + 2*64*32 + 4*3*64 = 8,960 bits`. This is not the physical block RAM
allocation: ports, tiny-bank fragmentation, replication and target mapping
can increase resource use or put storage in LUTs/registers.

The array has 64 multiplication sites. Mapping roughly one DSP per site is a
capacity estimate, not a measured synthesis result. Generic Yosys cells are
not FPGA LUT counts. Existing generic synthesis establishes neither board fit
nor routed timing. Start with a small configuration and grow to the frozen
8x8 profile after inspecting target utilization and critical paths.

## Build host and tools

Keep MoonBit development on the Mac, but use a supported x86-64 Windows or
Linux host for vendor implementation. macOS is absent from AMD's supported
Vivado platform list. [Platform requirements](https://docs.amd.com/r/2025.1-English/ug973-vivado-release-notes-install-license/Supported-Operating-Systems).

AMD's current Vivado BASIC tier supports Linux and Windows, 7 Series devices
and Kria SOMs. It costs zero with annual free license renewal. Freeze the exact
release, device support and license prerequisites in the eventual build recipe;
do not rely on old WebPACK branding or assume all debug/IP features are free.
[Current licensing](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado/vivado-licensing-options.html).

## First board acceptance path

Keep board clocks, reset synchronization, pins and transport in a target shell
outside the portable accelerator. Start with UART-controlled on-chip test
memory backing the public tagged request/response bus. External DDR and
Ethernet are later extensions, not prerequisites for a first signed matrix
self-test. The host diagnostic remains MoonBit; use vendor primitives only
at explicit target boundaries.

Require target synthesis, placement/routing, a recorded clock constraint and
passing timing before assigning an operating frequency. On-board tests compare
exact signed results and exercise request/response backpressure, completion
hold, reset, transfer faults and repeated workloads. Retain board/part identity,
tool versions, bitstream digest and observed results. Only actual board runs
establish FPGA execution; simulator cycle counts remain separate.

# PBlaze3 integrated digital replay

`replay_bundle()` runs the production controller, sixteen-row feedback Qwen
core with `GiB2`, and AXI bridge together under LunaWave. Combinational
connections settle before the edge. All three simulators then commit using
the frozen pre-edge input snapshot, followed by interconnect settlement.
Simulation time is an integer edge count.

The independent RTL fixture uses the same `pblaze3_layer_system` wrapper as
the board exporter, including the absolute `0x40000000` control address base.
A small external adapter splits each 128-bit AXI data bus into four 32-bit
words for the generic replay harness. It adds no state or protocol behavior.
The bundle retains each canonical module separately and hashes those modules,
their emitted sources, the system wrapper and adapter in `composition.json`.
It does not substitute a synthetic combined IR for the actual modules.

The deterministic mock DDR responds to observed AXI handshakes, with separate
AW/W/AR stalls and delayed responses. The campaign uploads actual instructions
and scratch data through AXI-Lite, reads RAM back, and checks:

- Separate AW/W acceptance and held AXI-Lite replies.
- Rejection of a program write during computation.
- ABI 1.1 accepted-launch counter at `0x38`: exactly one increment per
  successful START despite held write replies, no increment for busy,
  malformed or faulted START, stable count while DONE remains set, and zero
  after coordinated reset before a fresh launch.
- Four high-address FP32 loads, immediate addition by 2.0, and masked stores
  spanning two 16-byte AXI beats; neighboring bytes retain their values.
- A packed N16/K64 BF16 matrix at `0x7ffff800`, ending exactly at 2 GiB,
  producing sixteen FP32 results of 64.0 through the eight-word response path.
- Program/status/counter/scratch readback and actual mock DDR result words.
- AXI read failure during the first half of a wide response, sticky core fault,
  complete controller ownership drainage and rejection of a fresh START.
- Coordinated reset with an accepted AXI read outstanding, followed by a fresh
  successful matrix job using retained program and scratch contents.

`smoke_workloads()` supplies the two successful jobs as JSON with numeric
UInt32 words and addresses. The host preparation tool turns these into binary
files and hash manifests for board arrival. These fixtures describe digital
behavior; they do not establish physical DDR reliability, PCIe operation,
routed timing or performance.

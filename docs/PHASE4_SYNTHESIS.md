# Phase 4 pinned-Yosys memory synthesis matrix

## Claim

The Phase 4 matrix demonstrates that the emitted SystemVerilog for every
inference-eligible LunaChip memory form reaches Yosys 0.68 as the exact expected
pre-map `$mem_v2` shape. It does not demonstrate FPGA block-RAM selection,
technology mapping, area, timing, physical design, or silicon behavior.

The gate uses only the digest-pinned `linux/amd64` image and the locked runner.
It generates bundles from typed LunaChip IR, validates content-digested jobs,
runs warning-strict Yosys with the network disabled, archives complete generic
netlists, and parses `pre-map.rtlil` plus the corresponding Yosys `stat` record.
The identical checkpoint is also archived as `pre-map.json` for typed graph
checkers. A pass requires the checked representations to agree.

## Locked matrix

| Fixture | Required/observed pre-map shape | Classification |
| --- | --- | --- |
| ReadOld, ReadNew, NoChange, Undefined | one `SIZE=64 WIDTH=32 RD_PORTS=2 WR_PORTS=1` cell each | inference required |
| Masked single write | one `SIZE=64 WIDTH=32 RD_PORTS=2 WR_PORTS=1` cell | inference required |
| FIFO | one `SIZE=16 WIDTH=32 RD_PORTS=2 WR_PORTS=1` cell | inference required |
| Banked memory | exactly four independent `SIZE=64 WIDTH=32 RD_PORTS=2 WR_PORTS=1` cells | inference required |
| LowerPortIdWins dynamic multiwrite | observed one `SIZE=64 WIDTH=32 RD_PORTS=3 WR_PORTS=2` cell | observe-only; no RAM claim |
| Reject dynamic multiwrite | observed logic lowering with no retained memory cell | observe-only; no RAM claim |

The two multiwrite rows deliberately do not claim RAM inference. Their exact
observed cell/shape result is recorded so later emitter or Yosys changes remain
reviewable, but either retained-memory or logic-lowered classification is valid
for the multiwrite claim boundary.

## Machine-readable report

`scripts/phase4-yosys-inference-check.sh` emits one `inference.json` per fixture
under `toolchain/yosys/inference-report.schema.json`. The report contains the
expected shape list, observed `$mem_v2` count and shape list, legacy-memory
count, maximum `stat` count, classification, and explicit booleans for
inferred-memory and physical-RAM claims. Eligible fixtures require exact list
equality, including port counts; a blanket “at least one memory” result cannot
pass.

`scripts/phase4-yosys-inference-selftest.sh` covers a passing exact-shape case,
a missing/mismatched required shape, and an observe-only logic-lowered
multiwrite case.

## Evidence and provenance

Run:

```sh
DOCKER_CONTEXT=colima-lunachip-phase3 \
LUNACHIP_YOSYS_MOUNT_MODE=volume \
scripts/phase4-yosys-synthesis-gate.sh [EMPTY_RUN_ROOT]
```

The evidence hashes the lock and exact image inspection; typed IR, emitted RTL,
name manifest, and job for every fixture; runner, checker, and gate; generated
Yosys program and command; transport receipt and tool versions; runner and
Yosys logs; pre-map RTLIL and JSON; final JSON and Verilog netlists; status;
and the inference report. It also binds git HEAD/status and a canonical bundle-tree digest, then
recomputes all source/tool/bundle identities immediately before atomically
publishing the sole `STATE pass` line. Any mid-gate edit fails closed.

Volume permission initialization uses the pinned image's Python once to call
`os.chmod` on the fresh output volume. The synthesis runtime remains the host
UID/GID under all isolation flags. This narrow initializer is necessary because
the image's Rust coreutils `chmod` panics under amd64 emulation on the arm64
host; the transport receipt records the initializer and runtime boundary.

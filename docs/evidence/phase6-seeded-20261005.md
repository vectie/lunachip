# Seeded signed 8x8 replay on 2026-10-05

The fixed `fetched-concurrent-8x8-k16-seed-5eedc0de20261005` fixture passed
strict pinned Verilator lint, build, execution and typed audit. All 30 public
outputs agree across 7,488 cycles: 224,640 observations. Actual and expected
TSV are byte-identical. This is one reproducible randomized workload, not the
complete Phase 6 gate, statistical coverage or physical performance evidence.

The implementation checkpoint is `dbb8ede880431cf4ce813ac105a717411d5b2d80`.
The checked profile is fetched
concurrent, logical Device ABI 1.0, descriptor encoding 0.2; configuration is
8x8, reduction capacity 16, host4096, ring4 and q3. The production RTL remains
byte-identical to the earlier deterministic 8x8 replay. The canonical design
identity differs to bind this seed's inputs and results independently.
[The workload contract](../PHASE6_DIFFERENTIAL_SEEDED.md) records the fixed
SplitMix64 streams, signed edge injections, layout and timing conventions.

## Observed functional checks

Ten successful commands retire in order with IDs 101–110. Both slot-distinct
64-word signed results match the independent INT8 oracle; all 4096 host bytes
agree, including padding and final descriptor replacements. Two ring refills
use pre-edge credit, and final producer and consumer counts both equal ten.
The oldest LoadA1 completion stays valid with all payload fields unchanged
for 64 edges while nine younger descriptor-or-B1 requests and nine matching
ACKs occur. This combined predicate is not Run/capture overlap evidence.

The actual stream contains 960 accepted transactions and acknowledgements:
320 descriptor reads, 512 operand reads and 128 word writes. Totals are 832
read bytes and 512 write bytes. Request readiness is zero on 1,870 driven
cycles and one on 5,618; there are 287 genuine valid-request stalled cycles.
Programmed response-delay classes one through seven occur
`133, 133, 149, 150, 140, 121, 134` times. These counters are installed after
request acceptance; they are not elapsed request-to-ACK latencies or fairness
bounds. Each MatMul reports accepted=active=30, elapsed=31, capture=64 and
stall=0.

## Retention and regression checks

The unchanged network-disabled volume runner used Verilator 5.050,
`linux/arm64`, image
`docker.io/verilator/verilator@sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`.
Tool locks, strict lint policy, VM configuration and runner are unchanged.

Eleven input artifacts, actual TSV, three operation receipts and outer logs
are retained outside Git at
`/Users/kq/Workspace/lunachip/.phase6-seeded-evidence-20261005`.
The original compiled run remains at
`/private/tmp/lunachip-phase6-seeded-20261005.CwhlkA`.
The retained actual TSV is byte-identical to its retained expected TSV.

All 14 targeted replay/exporter tests pass, including two-run artifact
reproducibility, a deliberate public-output mutation and foreign-identity
rejection. All eleven artifacts of each of the four older replay fixtures
remain byte-identical after the shared host-policy addition.

| Artifact | SHA-256 |
|---|---|
| `bundle/design.lcir` | `736cf8b2fca97a26e3133a5c1decc1eed4588f084c28ae25555f1742d3565599` |
| `bundle/stimulus.tsv` | `e6f674fb5e8417e1c9185d48d2e8f9c18c94427a0ee739f6543a375510c86249` |
| `actual.tsv` and `bundle/expected.tsv` | `57bdb8d4cce6ca242ccbe9b491a9f05bd8dc23a3246b233511c44f9a24d3e09d` |
| `verilator-lint-receipt.txt` | `43c38942f8a046316f8da52fe43f8da0b5fb7b938361a03a01c097ac02574706` |
| `verilator-build-receipt.txt` | `b1d76148053c1e89fcbb185be4a51fc290e44cec611ea363721534994628f970` |
| `verilator-execute-receipt.txt` | `30e6f7a1b1fe50dc4b0948621c860391277027ba8a76cecce529719417fe5676` |

Additional seeds, remaining fault owners, independent capacity/wrap,
the complete synthesis matrix and named formal obligations remain separate
gates. No physical RAM, frequency, area, power, FPGA or silicon claim follows.

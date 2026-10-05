# Fetched DMA protocol fault replay on 2026-10-06

The `fetched-concurrent-8x8-k64-dma-poison-owners` fixture passes pinned
Verilator lint, build, execution and typed audit. All 30 public outputs agree
across 21,072 cycles: 632,160 observations. Actual and expected TSV are
byte-identical. This covers two fixed malformed-response owners, not the
complete Phase 6 gate, unbounded safety or physical performance.

Implementation checkpoint `4fab0380b75623bdaaba0f9e9ea9efbad890db7a` uses
Device ABI 1.0, descriptor encoding 0.2, an 8x8 array, reduction capacity 64,
16 ring slots, queue/retirement depth 16 and 16,384 host bytes. The
[workload contract](../PHASE6_DIFFERENTIAL_DMA_POISON.md) fixes the signed
setup, two ownership epochs, host timing and observable obligations.

## Observed ownership and recovery

Each malformed response uses the saved tag/data of an actual accepted DMA
request and status 2. It handshakes on an edge that advances accepted compute.
Both epochs admit exactly nine descriptors; the four admitted fault-batch
commands retire in order. Unadmitted StoreC1/Fence packets receive no fabricated
completion. The owner faults 10 at its accepted request address; the unfinished
sibling faults 15 with only previously successful ACK-backed progress.
Reader fault remains zero and shared poison records the actual owner's address.

| Owner | Tag | Address | Loader ACK bytes | Storer ACK bytes | Discovery active count |
| --- | --- | --- | --- | --- | --- |
| Loader | 1489 | 112 | 64 | 128 | 8 |
| Storer | 1490 | 4256 | 65 | 128 | 12 |

Fence200 remains successful and unchanged for 912 held edges in each epoch.
The accepted MatMul drains 78 active edges, 79 elapsed cycles, zero stalls and 64
capture edges. No later request, publication or packet admission is accepted
after discovery. Each ordered drain ends with eight quiet edges. The loader
epoch accepts 32 result-word writes; the storer epoch accepts 33, including the
full four-byte host effect preceding the malformed ACK. That ACK adds no
successful completion progress. This is not a partial remote-write replay.

Accepted result-word writes match the independent signed old-C0 matrix oracle.
Every 16,384-byte host checkpoint matches, including untouched padding
and explicitly refilled descriptors. Four joint resets flush transport ownership
and metadata without rolling back SRAM or host writes. After each fault epoch,
stale-slot MatMul rejects with 4 and Fence succeeds; the first new request tag
is 0. Only the explicit between-epoch host reinitialization changes host seeds.

The complete stream contains 3,109 accepted requests: 3,044 read bytes and 260
requested write bytes. Independent RTL receives frozen inputs, rather than an
environment adapted to its observed outputs.

## Validation and retained evidence

The full native slice gate passes 822/822 tests, interface generation,
formatting, strict native checking including warning 73, CLI smoke and
dependency/source-size checks. Targeted DMA tests pass 1/1 and fixture CLI
tests 11/11. Tests include deterministic artifacts, complete ports, audit counts,
foreign identity rejection and a deliberately corrupted observation.
All 66 artifacts of the six older replay bundles remain byte-identical.

The unchanged network-disabled volume runner uses Verilator 5.050 and locked
`linux/arm64` image
`docker.io/verilator/verilator@sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`.
The compiler was killed by the guest kernel at 4 GiB RAM and again at 8 GiB;
the second kill records 7,682,340 KiB anonymous compiler RSS. These were resource
failures, not RTL mismatches. Failed command logs and kernel observations remain
retained as `rtl-build-failed-oom`, `rtl-build-failed-oom-8g`, `vm-oom` and
`vm-oom-8g`. Startup after the memory increase was delayed by failed guest DNS
during package bootstrap; the same startup process subsequently exited 0 and
Docker became available. No successful DNS-repair claim follows.

The successful retry uses 8 GiB VM RAM plus a scoped 4 GiB guest-root swap file.
Pins, compiler flags, hardware, inputs, test bounds and warning policy are
unchanged. Resource setup commands and before/after memory observations are
retained. Compiler walltime is not hardware throughput or timing evidence.

Original inputs, compiled RTL work, actual trace, three published operation
receipts, validation/resource logs and 24 checkpoint source files are retained at
`/Users/kq/Workspace/lunachip/.phase6-dma-poison-evidence-20261006`.
The original run is `/private/tmp/lunachip-dma-poison-20261006.DDsf2R`.
The verified inventory contains 534 files with SHA-256
`088aa20e6a817d92b0715f6125c0acf3e5821757dde2b36b0cc26b992d206a4f`.
Individual dirty pre-commit validation contexts and clean committed tool
contexts remain distinct. Frozen implementation hashes match the committed
checkpoint; earlier native runs are not claimed to share its HEAD.

| Artifact | SHA-256 |
| --- | --- |
| `bundle/design.lcir` | `b44c4620c7d6e4d9430038d117a8e282a6745eb767bba2926cbd06aa84f63d11` |
| `bundle/stimulus.tsv` | `073b71bf97d5fa80b4d61abd2917ada045934154c71c50aae01c8ba52f04c4ed` |
| `build/actual.tsv` and `bundle/expected.tsv` | `a3e655f9a43d2382b92aca50540d68f3124c4b6fb486199320c6bb97121ddc12` |

Matching remote failures/partial writes, arbitrary invalid descriptors,
capacity/origin wrap, remaining synthesis coverage and full-device
safety/fairness remain separate Phase 6 requirements. The fresh unchanged-source
Phase 5 aggregate also remains required; its standalone FIFO gate passed
separately. No physical RAM, metastability, frequency, area, power or silicon
claim follows.

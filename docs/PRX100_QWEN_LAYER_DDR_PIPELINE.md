# Complete-layer DDR read pipeline

`export-transfer` selects the unchanged four-lane BF16/FP32 overlap core and
controller with an opt-in MoonBit DDR bridge in `targets/prx100_layer_ddr`.
The original integer bridge and all earlier export commands remain available.

An accepted aligned 128-byte request reserves storage for eight ordered native
128-bit read returns. Separate four-bit issue and return counters bound native
ownership to eight lines. Commands advance only on MIG command acceptance;
returns advance only on an owned, valid, correctly terminated response. Thirty-two
word registers hold the complete request independently of downstream readiness.
There is no speculative native command beyond the eighth line.

A registered output stage emits 32 ordered words through a 64-entry asynchronous
FIFO, holding its payload under backpressure. This FIFO can retain a complete
burst without waiting for slow-side credit synchronization. The source contract
remains one request owner, 32 words and LAST only on word 31. Ordinary word reads,
cached reads, four-word line reads, masked writes and four-word line writes retain
their original protocol and cache invalidation rules.

Malformed native returns and calibration loss poison the bridge until coordinated
physical reset. Remaining owned words drain with faults; already queued words
retain their recorded payload. No new native command issues after registered
poison. Reset invalidates both FIFO endpoints and all counters/output ownership.
Job reset does not reset this transport. The full return reservation prevents
overflow even when all eight responses arrive before any source word is consumed.

The production bridge keeps its source and fast-domain ownership in one generator
to make priority and fault drainage reviewable; supporting helpers, native outputs
and evidence observations live in focused files. It remains below the 800-line
ADR threshold. Qualification requires directed native stalls/fault/reset cases,
exact physical RTL differential replay, pinned synthesis and bounded control
checks, integrated zero-SCC checks, routed timing, and complete-layer physical
CPU comparisons. Performance is claimed only by the measured evidence report.

Physical qualification and the fresh CPU-verified complete-layer A/B campaign pass; see [the measured evidence](evidence/prx100-layer-transfer-20261019.md).

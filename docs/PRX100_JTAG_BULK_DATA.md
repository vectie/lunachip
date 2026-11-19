# PRX100 bulk-transfer host data handling

This host-only experiment first compares `queue` and `lean` data handling,
then compares a fresh `queue` baseline with a `buffered` policy on
the unchanged qualified FPDDR1.3Q bitstream. Both use the preceding coalesced
warm-request campaign, the same 30 MHz JTAG link and 16-entry DDR queues. The
integer core, FP hardware, register map, all 106 projections and 848 outputs are
unchanged.

`queue` retains per-object DATA fetching for every queued read and write.
`lean` obtains the queued read DATA properties as a list, requires exactly one
correctly shaped value per transaction, and retains every actual read word.
Queued operand writes record submitted words and final group BRESP without a
redundant write-object DATA fetch. They use an explicit `GROUP_SUBMITTED` tag
and `-` in the actual-data field; no actual write-data observation is invented.
MMIO and short serial writes retain their existing object/response checks.

Every queued write word is independently read back from physical DDR. Before
the timed upload, complement poisoning is written and fully read back. Every
actual input write replaces verified poison. Every model word is read before
START and again after the campaign. The CPU audit reconstructs intended writes
and checks these actual reads, every output, guards and all completion counters.
The lean tag is admitted only for queued writes wholly inside the pinned weight
or activation region. Missing/corrupt reads, malformed values, unaccounted tags
or writes outside those regions fail validation. Final group responses do not
establish per-transaction response visibility.

The buffered variant retains the same lean write policy and batched read DATA
fetch, buffers each group's trace output into one write per stream, and omits
dummy read-request zero words. Such read records use `GROUP_READ_DATA`, with
`-` in the request field and every actual DDR word in the actual-data field.
The CPU audit treats a read as having no input data; no missing actual value is
replaced. Result/counter/control records retain their original format. Bulk
read results are appended in order without repeated concatenation. Both series
and every actual trace remain retained; only fresh interleaved buffered-series
measurements establish that variant's performance.

Bulk groups remain homogeneous, with at most 16 transactions, at most 256 words
per transaction and no 4 KiB crossing. Transfer order and all actual DDR payloads
are identical across policies. Completed-result/control access semantics remain
unchanged. Compare fresh interleaved measurements of actual 22,528-byte upload,
both full input readbacks, complete batches and complete application timing.
Startup/programming and CPU-reference preparation remain outside those timers.

Independent CPU, group, timing, cache, launch, logical-warm and bulk-policy
audits are required, with source-bound raw traces and all samples retained.
Measurements: [board report](evidence/prx100-fpw-20261018.md).

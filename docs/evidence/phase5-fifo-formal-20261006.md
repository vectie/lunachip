# Complete asynchronous FIFO formal result

The complete standalone asynchronous FIFO formal gate passes on unchanged
commit `7bcf1a749931810759b39aba43de8800c5578f85`. All nine fixtures and fifteen
logical tasks produced validated typed results and transport receipts: one
bounded safety pass, six cover witnesses and eight counterexamples on their
exact expected assertion labels. Phase 5 remains in progress until its native
and nine child gates pass together on one unchanged snapshot.

## Scope of the result

The safety task partitions the same twenty-two assertions into five internal
shards, each retaining all seven parent assumptions and the parent bound of
128 global steps. All five shards pass. The supplemental completion shard
repeats the exact completion relation at bound 204; it does not broaden the
parent bound or establish an unbounded proof.

The six cover tasks retain witnesses for coincident edges, full occupancy,
write-pointer wrap, read-pointer wrap, simultaneous transfers and watched-token
completion. All eight negative fixtures fail their selected labels, covering
Gray equations, full equations, address selection, storage ordering, both
synchronizer pipelines and both address bounds.

The locked OCI provider uses Yosys 0.68, SBY v0.68 and Bitwuzla 0.9.1 on
`linux/amd64`, with image digest
`10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`.
The Docker context remains `colima-lunachip-phase3`; the two-CPU, 4-GiB VM,
volume transport, assumptions, bounds, warning policy and tool pins are
unchanged. Start/end repository manifests and Git status match exactly.

## Retained evidence and reproduction

The original run is `/private/tmp/lunachip-phase5-fifo-fresh-20261006`.
Its whole completed tree is copied and verified outside Git at
`/Users/kq/Workspace/lunachip/.phase5-fifo-formal-evidence-20261006`.
The copy retains all bundles, command logs, models, witnesses, counterexamples,
typed results, transport receipts and source/tool context. Original receipt,
status and inventory bytes are preserved.

| Artifact | SHA-256 |
| --- | --- |
| Final gate receipt | `ff620622655ff5bd1e679b06bc48c7b92dcc2822f0e7d5ca4ed821c14b2c5e6b` |
| Original 734-file artifact inventory | `2548358eab5609179df739d8aae0d31eb02ae4e926784a77ebbecc1587ae3830` |
| Separate 737-file retention inventory | `78c4fb308412de24ae0692a5aab69bdf68d3bf0f160d0c56f97bba8d35d3b66d` |

Reproduce on a clean checkout with the locked provider available:

```sh
DOCKER_CONTEXT=colima-lunachip-phase3 LUNACHIP_YOSYS_MOUNT_MODE=volume sh scripts/phase5-async-fifo-formal-gate.sh /absolute/new-run-root
```

This result closes the standalone FIFO formal requirement without modifying
earlier incomplete receipts. The aggregate must rerun its own child gates;
this standalone receipt is not a substitute. The claim is a bounded digital
two-state result, not metastability, MTBF, unilateral-reset, timing, physical
RAM or full-device fairness evidence.

# Fetched Store witness receipt and aggregate integration

The validated fetched Store witness now has a typed, content-addressed cover
result and a verified partial aggregate for the exact
fetched1×1/K2/host1024/ring4/q2 directed R1/H1/C1 profile. This closes evidence
integration for that existential cover, not fetched symbolic safety or Phase6
as a whole.

## Implementation contract

1. Add a focused MoonBit evidence package. Bind its receipt to the sealed
   independent-field archive, the native predecessor and the original cover
   task by exact SHA256. Reuse the formal package's bounded cover result type.
2. Record the actual Bitwuzla basis and concrete-validation method in a
   separate derived task, with840 states through global839. Preserve the
   original source-set, eight assumptions, selected cover and clock/reset
   contract. Retain the original1024-step SBY task as a separate linked input;
   do not manufacture an SBY PASS or alter previous timeouts.
3. Add a native receipt collector that checks complete archive inventories
   before publishing anything. Its partial aggregate admits only this exact
   cover and explicitly leaves symbolic safety, fairness8×8, remaining matrix
   and same-snapshot final gates open. Successful collection is not a phase
   gate pass.
4. Test result round trips, scope/method/bound separation, altered inputs and
   aggregate non-promotion. Collect actual receipts, rerun targeted checks,
   retain unique outputs by digest and commit each verified step.

## Semantic boundary

No production graph, SMT equation, initialization, memory policy, address
width, search constraint or solver run changes. All15342 independent fields,
18 unknown initial memory words,11 undefined high-address slices and five
anyseq fields remain represented. Native comparison preserves517 unknown
bits rather than forcing them to zero. The prior sealed archive and its
historical `original_typed_receipt=false` and `phase6_pass=false` fields remain
immutable; the new receipt is a later integration artifact.

## Evidence inputs

- Basis archive inventory:
  `ec86792f2a6bb02030d823f7816fad6f5abd16ef62579a37a42366a1009d237e`.
- Native predecessor inventory:
  `29f55cce2e8fec214d02e801e1950143be5bd7d22315f3d9212451278d98b516`.
- Original cover task:
  `69038350695dc9f2672fbcfad427bec6b3cb9b72f125c13e11eaeff9f7727f63`.
- Validated witness summary:
  `37b8aa4694a6bf607995b47b484d213848106688924b4372273e9ecca5efe52a`.

The underlying proof chain and limitations are recorded in
[the basis certificate ledger](phase6-fetched-basis-certificate-20261015.md).
This integration needs host-only archive verification, not another solver or
shared VM window.

## Typed implementation checkpoint

The focused `validation/phase6_evidence` package now emits a mode-checked
`CoverWitness` result for the separate validation method and a content-addressed
receipt. All six native deny-warning tests pass, including the documentation
example. They check formal-result round trips, exact original assumptions and
timing, bound/method separation, each archive role and digest, altered address
and unknown-bit metadata, and the incomplete aggregate boundary. The new public
interface has been generated and reviewed. Collector publication remains the
next checkpoint.

## Collector implementation checkpoint

The `.mbtx` collector checks complete inventories before and after encoding,
retains command logs and targeted validation, reads the saved typed result back
through the existing formal parser, and reconciles every saved receipt and
aggregate record. Its three native deny-warning tests reject changed payloads,
extra files, inventory/payload links and wrong inventory pins. Targeted native
checking of the encoder and collector passes. Automation remains in `.mbtx`;
the small reusable native command is an identity encoder and record reader,
not a replacement solver or a standalone filesystem acceptance gate. No new
module dependency or external tool run is introduced.

## First collection attempt

At implementation commit `78cae70`, six receipt tests,22 formal-codec tests,
three collector tests, formatting, interface generation and targeted checking
all pass. All three original archives verify exactly before and after encoding;
the saved cover result, receipt and aggregate also reconcile. Publication then
fails with exit1 because recursive directory creation rejects a parent already
created for a preceding provenance file. The unsealed attempt is retained at
`artifacts/phase6-fetched-receipt-integration-20261015`, explicitly failed and
unpublished. Guarded parent creation and a focused regression precede a new
collection directory; no solver rerun or semantic change is needed.

The failed attempt is sealed at inventory SHA256
`5b7aa93964b0f03d78e6529e3f5a9f0ed9c9d6dabd66d8566675af5365bd1aa3`.
All four collector tests now pass, including retention of two source files
sharing the same destination parent. The failure archive is not overwritten.

## Published receipt and partial aggregate

The retry at implementation commit `fd947e5` completes with exit0. Its sealed
archive is `artifacts/phase6-fetched-receipt-integration-20261015-r2`, with61
inventory entries and62 files, using approximately232KiB on disk. Inventory
SHA256 is
`694d32d0857980dc6f6baf33f7c93f7a565dadc0cb48c08b0febabca5f58ea91`.
The independent verifier retained in the earlier basis archive verifies the
complete directory and every file digest for both this success and the failed
first attempt. Neither archive is modified after sealing.

| Published record | SHA256 |
|---|---|
| Original1024-step task | `69038350695dc9f2672fbcfad427bec6b3cb9b72f125c13e11eaeff9f7727f63` |
| Derived840-state validation task | `5ae23750c6b4f4d3f70723970116034eb7e67a5154bf5265336d8af4c1bbe54b` |
| Typed bounded cover result | `178584d2da9324c1646d11be6b5c81ef7544d27af2d55bbc6e7956508c37b777` |
| Validated witness receipt | `02f66977130a9404b6dbfe3e0e5f3c001b731b360452ea64ac636a505ca37923` |
| Partial aggregate | `793c37462f4e569526e57059c1b7a2b793d4455392d9231160928f0eccf40038` |

The collector verifies every file in all three pinned proof archives both
before and after encoding. It parses the saved formal result as a bounded
`CoverWitness`, then reconciles all five saved records against the exact typed
construction. All thirteen selected integration source/interface/fixture files
remain unchanged and are retained with their digests. Previous proof trees and
build caches are referenced, not copied.

All32 targeted native deny-warning tests pass: six receipt tests,22 existing
formal-codec tests and four collector tests. Targeted native checks, interface
generation and format checking also exit0; actual commands, compiler versions,
stdout, stderr and exits are retained in the archive. This is a host-only
evidence checkpoint, not a same-snapshot full Phase6 regression. No solver is
rerun and no shared VM or foreign resource is used.

## Accepted scope and next work

The aggregate accepts only the validated useful fetched Store existential
cover. It explicitly remains `STATE incomplete` and `PHASE6-PASS false`.
Fetched symbolic safety/address/dependency composition, explicit-fairness8×8
completion, the remaining workload/fault/synthesis matrix and final
same-snapshot native/tool aggregation remain open obligation groups, not a
four-task estimate. Separately accepted Store/packet safety scopes and all
historical failures remain unchanged.

The new result records Bitwuzla0.9.1 with the independent-field and concrete
original-model validation method, not an SBY run. The original SBY task,
original equations, initialization, unknown memories, full-width addresses and
search constraints are unchanged. Historical `original_typed_receipt=false`
fields describe their sealed earlier checkpoints and are not rewritten.
The next proof work is fetched symbolic safety and address/dependency
composition, not another retrieval retry for this already validated witness.

Implementation commits are `f2e955e` for the plan, `9671003` for the typed
receipt, `78cae70` for collection/reconciliation and `fd947e5` for the focused
publication fix. The final documentation commit records the sealed results.

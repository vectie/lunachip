# Fetched Store witness receipt and aggregate integration

The validated fetched Store witness will become a typed, content-addressed
cover result for the exact fetched1×1/K2/host1024/ring4/q2 directed R1/H1/C1
profile. This closes evidence integration for that existential cover, not
fetched symbolic safety or Phase6 as a whole.

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

# Fetched Store batched certificate requests

## Scope

Batch the existing 841 certificate terms into one `get-value` request. Preserve
every search byte through `check-sat`, the original term order, and the existing
exit suffix. The [output-shadow run](phase6-fetched-output-shadow-20261014.md)
returned SAT but timed out while returning states: only 79 of 840 were retained.
Batching is a serialization experiment, not a change to the reachable states.

The exact profile remains fetched 1×1/K2/host1024/ring4/q2, with its full initialized
states0..839, 839 transitions, 13417 assertions, eight host premises, and original
sampled cover839. Public input guidance remains confined to0..837. All unknown
initial memory, held-read state, undefined address slices, invalid-read anyseq,
full-width addresses, masks, bounds and read/write equations remain unchanged.

## Implementation and validation

1. Verify every sealed predecessor entry, inventory digest
   `2e09276fd13dc8a28c6533dc6b08a31842e3a0d57fd2d5ab302102a2eb801599`,
   and query digest
   `4bffcfaba4654203e86693ef2d8e9e4c250a078e5d71b19e39cebf61a5a51af0`.
2. Replace only the 841 post-check requests with one list containing the same
   `s0..s839` and original cover term. Mechanically compare the complete search
   prefix and exit suffix; retain the original model/layout/guidance bytes.
3. Test whitespace-independent response parsing and reject incomplete, duplicate,
   reordered, unknown-bit, wrong-width, false-cover and extra responses. A clean
   process and all 840 known 9716-bit states plus true original cover are required.
4. Commit implementation and qualification before execution. Freeze tracked
   source and full Git status for the actual pinned Bitwuzla0.9.1 job, using the
   same QEMU-only4CPU/8GiB/20GiB profile and600-second host deadline. Retain raw
   outcome, state values, kernel/runtime/profile and owned cleanup records.
5. If a complete certificate returns, check it against the untouched original
   model and validate native known-mask outputs and causal read/ACK, Store−29
   and four ordinal retirements. SAT alone or a partial batch is not accepted.
6. Seal unique evidence without build/format caches, stop the dedicated VM,
   reconcile the status/formal ledgers and commit the actual outcome.

MoonBit automation and repository-documentation skills keep this experiment
private and documented in LunaChip. No new assumption, initialization waiver,
state cut, native/private value pin, solver-resource increase or fabricated
SBY/typed receipt is allowed. Full fetched safety, explicit-fairness8×8 and
remaining Phase6 matrix/aggregate gates retain their own acceptance requirements.

## Implemented batching and parser

The 379-line `scripts/phase6-fetched-batch-certificate.mbtx` verifies the sealed
predecessor, batches only the exact original requests, and parses a single
whitespace-independent response. Parsing requires the original term identities
in order, all 840 known 9716-bit states, and the true original cover. It rejects
incomplete, duplicate, reordered, extra, unknown or malformed answers. A complete
batch may be normalized losslessly to the older sequential certificate format;
normalization alone does not validate the witness against original equations.

Three focused native deny-warning tests pass, including a synthetic full-size
840-state response. Formatting and interface generation pass without API changes.
Fresh query digest:
`05240717aff0f7af94d6787438880a1a8875f7abeb8c46655644aaafdf5020fb`.
Search prefix through `check-sat` digest:
`4ed9be0a1de4c9d977413f4560bb54f3725e94be0f948d00785b76b84d14c54d`.

## Packaging qualification

A separately implemented mechanical audit compares the whole UTF-8 search
prefix, re-extracts all 841 original terms, and checks the exact batched tail
and original exit suffix. Original model/layout/guidance bytes and all six
prepared hashes match. All 13417 assertions and 15342 remaining fresh fields
are unchanged. No new equation or constraint is introduced after `check-sat`.
The audit report digest is
`bd4e7d471f0e9def86350485b16e2848b6ea5ff41c3999034ceb000dad66fc9b`.

The pinned AMD64 Bitwuzla0.9.1 format probe exits0 and returns two known two-bit
states plus a true cover in one multiline response. The new parser accepts it.
This isolated synthetic probe validates command/response compatibility only;
its literals never enter the fetched search. No runtime benefit or full fetched
witness is established by the probe.

## Actual run and partial batch

The pinned run freezes HEAD `a2a1b52` and full Git status. Runtime
`ca62e83f8dd57a59fec538967e79586c0104e257fab70017e67f5d7db8834588`
starts at04:37:41.470155610Z, reaches the query marker at04:37:52.435208430Z,
and returns SAT at04:44:32.310473159Z: 10.965 seconds to query entry and410.840
seconds to SAT. These are this run's timings, not a controlled speedup result.

At the unchanged600-second host deadline, stdout contains77 complete known
9716-bit state pairs (`s0..s76`) and a truncated `s77` pair. The outer batch
and original cover response are absent. The runner records `TimeoutError`,
`host_timeout=true` and `child_exit=null`; its explicit stop yields runtime137
with `OOMKilled=false`, finishing at04:47:42.858465762Z after601.388 seconds.
Neither kernel snapshot contains an OOM event. Stderr is empty. Raw stdout
digest is `61e3ca25da6756d58b1e0a1e2efdc20d43ebad75a892c17253ddecffd700e333`.

The outcome audit verifies actual input/review/source binding, pinned command,
profile/isolation, deadline-stop classification, ordered known-width complete
pairs, trailing fragment and exact owned cleanup. Its focused rejection test
passes, bringing the new native deny-warning tests to four, plus the actual
pinned format probe. The certificate extractor correctly refuses this timeout:
no normalized complete certificate, original-model ground query, causal/native
audit, accepted cover or typed receipt is produced. An absent cover response
is not an observed false cover value. Prior accepted Store/packet proofs remain.

Retained memory samples are753.8MiB early,1.51GiB mid-run and6.094GiB near SAT;
they are not peak measurements. The audit and run preserve all search bytes,
unknown memory and address semantics. Batching alone did not finish certificate
extraction under this deadline; neither safety nor unreachability follows.

## Next extraction candidate

The matching upstream0.9.1 parser still calls `get_value` once per term inside
a batched command. The solving context preprocesses a requested term before
obtaining its model value. These source facts do not profile or attest the
pinned binary, but suggest that command batching need not remove per-term work.
[Parser](https://github.com/bitwuzla/bitwuzla/blob/0.9.1/src/parser/smt2/parser.cpp#L970-L1018),
[context](https://github.com/bitwuzla/bitwuzla/blob/0.9.1/src/solving_context.cpp#L117-L135).

The next separately qualified candidate is one lossless packed certificate
expression containing all840 original9716-bit states and one encoded cover bit:
8161441 bits in a checked order. Request and decode it after the unchanged
`check-sat`; no constraint or declaration before the check may change. Verify
all bit boundaries, Bool encoding and round-trip reconstruction before running.
This is a candidate, not implemented or measured here. Do not repeat this same
batch, fill missing states from native/private observations, initialize unknown
memory or raise the resource budget. Useful cover and all remaining Phase6
safety/fairness/matrix/aggregate gates remain open.

## Sealed checkpoint

The157-file archive `artifacts/phase6-fetched-batch-certificate-20261015` is
sealed, about79MiB with no compiled or formatting caches. Its156-entry inventory
digest is `49d625c9e43e8dc09ea9e3c9fb4624c11c3870d47e92c73ed11c5f3300155c3d`.
All entries and the unchanged sealed predecessor reverify successfully. Raw
partial output, refusal, mechanical audits, probe, profile/kernel/runtime/source
records and source-inspection references are retained. Owned containers/input
volume are removed and the original QEMU-only VM is stopped. Four stepwise
commits record plan, implementation, qualification and actual outcome.

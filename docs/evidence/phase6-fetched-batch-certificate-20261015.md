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

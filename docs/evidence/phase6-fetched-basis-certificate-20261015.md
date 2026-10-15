# Fetched Store independent field certificate and reconstruction

## Scope and acceptance

Reduce only post-search observation. Preserve the complete searched prefix,
SHA256 `4ed9be0a1de4c9d977413f4560bb54f3725e94be0f948d00785b76b84d14c54d`,
including all840 original initialized states,839 transitions,13417 assertions,
eight host premises, original cover839 and input guidance only through837.
Unknown memory, held reads, undefined address slices, invalid-read anyseq and
free tails838/839 remain unchanged.

The certificate basis is every remaining original `declare-const` field, in
its exact declaration order and sort. Request those fields only, packed with
explicit Boolean-to-bit conversion. Do not request derived states or the cover
expression: the original cover assertion stays in search and is rechecked
against reconstructed states during original-model validation. No independent
field may be omitted because it appears irrelevant to this workload.

## Implementation sequence

1. Verify the sealed failed-retrieval predecessor and derive the basis roster,
   widths and intervals from its declarations. Mechanically show every free
   declaration is included exactly once, with complete original field coverage.
   Preserve every search byte and change only the post-check request.
2. Qualify strict complete decoding, distinguishable per-field values, Bool
   conversion, boundaries and rejection of corrupted/truncated/reordered data.
   Use a small pinned format probe before the actual run.
3. Reconstruct losslessly by substituting returned basis literals for exactly
   those declarations in the original qualified equations. No zero fill,
   guessed field, native/private pin, omitted state or changed address equation
   is permitted. The reconstruction input has no free declarations, retains
   the full assertions and requests the original840 full states. This is a
   deterministic evaluation/check, not another guided search.
4. Independently validate reconstructed full states against the untouched
   original model and all original assertions, then perform known-mask/native
   and causal read/ACK, Store−29 and ordinal-retirement checks. SAT, decoding
   or reconstruction alone is not an accepted useful cover.
5. Commit qualification before freezing an isolated checkout. Reserve the
   existing QEMU-only4CPU/8GiB/20GiB VM; preserve pinned AMD64 Bitwuzla0.9.1 CLI,
   container isolation and600-second per-process deadlines. At most one actual
   basis retrieval, followed by reconstruction and ground checks only if each
   prerequisite completes. Retain failures without unchanged retries.
6. Seal unique evidence and record actual outcomes step by step. Leave unrelated
   PRX100 work and the pre-existing VM intact. Full fetched safety,
   explicit-fairness8×8 and remaining Phase6 matrix/aggregate gates stay separate.

The MoonBit guide keeps automation in private `.mbtx` tools. The documentation
skill keeps acceptance conditions and actual evidence in the repository ledger;
there is no production hardware or public API change in this slice.

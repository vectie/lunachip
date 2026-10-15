# Fetched Store single-expression certificate

## Scope and acceptance

Replace only the post-`check-sat` observation of the
[batched predecessor](phase6-fetched-batch-certificate-20261015.md) with one
lossless bit-vector expression. Concatenate the original states `s0..s839`,
each9716bits, most-significant first, followed by the original cover encoded
as `(ite (|lc_formal_fetched_useful_top_c 0| s839) #b1 #b0)`. Use balanced
binary `concat`; total width is8161441bits. No helper definition, declaration,
assertion or constraint is introduced before the unchanged check.

The search prefix remains SHA256
`4ed9be0a1de4c9d977413f4560bb54f3725e94be0f948d00785b76b84d14c54d`:
all840 initialized states,839 transitions,13417 assertions, eight host premises,
original sampled cover839 and input guidance only through837 remain intact.
Unknown initial memory and held-read state, invalid-read anyseq, undefined
high address slices, full-width guards, masks and collision equations remain
unchanged. This is an observation experiment, not a new formal search.

## Implementation sequence

1. Verify every sealed predecessor entry and its inventory digest
   `49d625c9e43e8dc09ea9e3c9fb4624c11c3870d47e92c73ed11c5f3300155c3d`.
   Validate its exact old observation suffix and preserve every search byte.
2. Generate a checked bit map and one balanced expression. For state index i,
   high=`8161440-i*9716`, low=`8161441-(i+1)*9716`; cover is bit0.
   Test distinguishable values, ordering, boundaries, Bool encoding, complete
   full-size decoding, malformed/truncated and extra response rejection.
3. Independently audit expression leaves, bit map, untouched prefix and original
   model/layout/guidance. Run a tiny actual pinned Bitwuzla format probe; its
   literals must never enter the fetched search. Commit qualification first.
4. Freeze tracked source and full Git status for one pinned600-second run in
   the existing QEMU-only4CPU/8GiB/20GiB validation VM. Retain actual process,
   runtime/kernel, raw output, input/source identity and owned cleanup records.
5. Accept only a clean exit0 and complete identity/width-checked expression
   response containing all840 states plus true original cover. Decode losslessly
   to the sequential certificate format, then independently check the untouched
   original model and native known-mask/causal read, ACK, Store−29 and ordinal
   retirement history. SAT or successful decoding alone is not an accepted cover.
6. Seal unique evidence without caches, stop the VM and commit the actual
   outcome. Preserve unsuccessful evidence honestly; do not repeat an unchanged
   full query, increase resources, fill missing states or initialize unknowns.

MoonBit automation and repository-documentation skills keep implementation
private and evidence in this repository. No public API or production hardware
change is planned. Full fetched safety, explicit-fairness8×8 and the remaining
Phase6 matrix/aggregate gates retain their separate acceptance requirements.

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

## Implemented and qualified

The442-line private MoonBit script
`scripts/phase6-fetched-packed-certificate.mbtx` implements generation, pinned
format probing and strict decoding. Three focused native deny-warning tests
pass, including distinguishable full-size840-state round-trip reconstruction.
Malformed, reordered, wrong-width, unknown-bit, false-cover, incomplete and extra
responses are rejected. Targeted native checking and script formatting pass.

A separately implemented grammar/interval audit reconstructs concat widths
bottom-up, verifies all841 ordered leaves, every bit boundary and no gaps or
overlaps, and compares the entire search prefix as UTF-8 bytes. All seven
prepared hashes, original model/layout/guidance,13417 assertions and15342 fresh
declarations match. New query SHA256:
`e3186d29f213bff9e1c5043697bf0096b8d86e409529d7cb21bfc9776d10885e`.
Mechanical audit SHA256:
`6e59cbf9179189c76e07ab8180a90632a539bc14e9b1744d990d4204d456d6fc`.
Input inventory SHA256:
`22a66a156ec7d39dbe587a1487426950d13b77be49e3cf7c414439657f9da014`.

The actual pinned AMD64 Bitwuzla0.9.1 probe exits0 and returns one expression
with the expected five-bit value, decoding to two distinct two-bit states and
true cover. This validates syntax/printing only, not runtime benefit or the
fetched witness. Actual profile fields confirm4CPU/8GiB/20GiB, ARM64/VZ,
Rosettafalse and no host mounts.

`moon info` completes without tracked interface changes but reports warnings
from separate, concurrently appearing untracked `targets/prx100` work. Module
`moon fmt --check` similarly reports formatting differences in that work; it is
not a module-wide formatting pass. Those unrelated sources and documents are
left untouched. The new script's own checks pass. Source/checkout freeze will
be checked around the pinned run; Phase6 is still open.

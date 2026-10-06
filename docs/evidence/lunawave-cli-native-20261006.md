# LunaWave replay command checkpoint

The native LunaWave command runs saved replay bundles through the existing
public replay engine and exports exactly `trace.txt` and `trace.vcd`. It requires
both the declared stop condition and expected trace digest to match. Failed
outcomes preserve those actual artifacts; existing output paths are not reused.
The [command guide](../../cmd/lunawave/README.md) documents usage and limits.

Implementation commit: `f3e83ac04cada8538f4c7bce2c805ffa68b84606`.
The full clean-snapshot native gate passes: interface generation, formatting,
warning-strict native check including warning 73, all 853 tests, both CLI builds,
bootstrap smoke and dependency/source-size boundaries. Every gate's before/after
HEAD and complete status snapshots match; the snapshot remains clean.
The entrypoint reports checked errors and exits 1 rather than allowing native
error propagation to abort without outcome details. No replay format, hardware
graph, simulator semantics, emitter or library interface changes are introduced.

## Focused behavior

All eight new native tests pass. They check schema-1 exact trace/VCD output,
schema-2 timebase and coincident domains with unknown masks, retained mismatches,
a matching digest with an unreached stop, malformed input without output,
existing directories/files without modification and explicit argument handling.

Actual executable checks on the clean implementation exercised success 0,
digest mismatch 1 and unreached stop 1. The latter matches the trace digest but
still fails; all three runs retain byte-identical trace/VCD for that input.
These smoke inputs reuse the existing canonical replay golden, changing only
the expected digest or requested stop. They are command checks, not an
independent hardware oracle.

The first strict check exposed two test collection-conversion errors and a
cleanup warning; supported iterator conversion and scoped `defer` corrected
them. Plain `README.md` avoids executable-package blackbox-input processing.
An initial native smoke aborted with code -6 despite preserving artifacts,
which led to the checked-error entrypoint correction. An unused temporary
bootstrap could not import the unpublished local module in standalone script
mode; the existing golden input was used directly instead. No workaround
framework or bootstrap source was added to the repository.

## Retained checkpoint

The complete support root is retained at
`/Users/kq/Workspace/lunachip/.lunawave-cli-native-evidence-20261006`.
Its 158-file inventory plus `outputs.sha256` matches
`/private/tmp/lunachip-lunawave-cli-support-20261006.ULXfn0` by recursive byte
comparison; all 158 digests verify. Inventory SHA-256:
`cbfb4fecaf33a6384c8ff3b1889d48c4d7f67cbb97954e1b547e7072379e284c`.
The clean native gate runs in
`/private/tmp/lunachip-lunawave-native-20261006.XDszAI`, separate from the main
checkout's existing untracked codec test, whose bytes remain unchanged.

The three clean executable outcomes use the same actual trace and VCD bytes.
Trace SHA-256:
`5018280e181c441721aeaad38881f42e6722e663411f870e8a4ce51ca6e5a27e`;
VCD SHA-256:
`5313b5ce29384d4e49ba3a487ad3545e6122e11f70b2491efc374287990876cd`.
The CLI's expected-result digest remains the existing canonical `fnv1a-64`
contract; retention SHA-256 does not change that replay format.

## Claim boundary

This is a user-facing simulator command over existing, versioned semantics.
It does not establish independent RTL agreement, formal safety, physical
timing, FPGA execution or completion of Phase 6. The separate retirement
formal outcomes and their original obligations remain unchanged.

# Directed fetched Fence execution on 2026-10-05

The first directed legal-host Fence search is incomplete. The unchanged pinned
runner exited16 after510 seconds because Bitwuzla closed its protocol stream:
`Unexpected EOF response from solver` at global step128. SBY recorded ERROR,
no solver status and no traces. This is not a timeout, counterexample, proof,
or evidence that the cover is unreachable. The retained logs do not establish
the cause of the solver termination; no OOM claim is made.

The immutable bundle was exported from implementation checkpoint `6d1beeb`;
the executed source checkout was `0fbb29d`. It contains the production-identical
fetched 1x1/K2/host1024/ring4/q2 device, one cover,12 explicit legal-host/reset
assumptions,256 global steps /128 DUT clocks and timeout600. Production safety,
write reachability and eventual completion are not claimed.

## Measured resource limits

Preparation took127 seconds. Solver checks cost approximately2.8 seconds per
global step early, increasing to approximately3.1 between steps84 and104.
Controller review predicts the first concrete Fence retirement around106
post-reset DUT edges /global212–214: configuration and publication;32
three-edge descriptor byte transactions; then packet admission, FIFO pop,
capture, reservation, termination and retirement. This is a source-derived
expected path, not an observed witness. Extrapolated search alone exceeded
the unchanged600-second budget even before trace export. The
[dependency negative](phase6-dependency-20261005.md) separately measured134
seconds of trace/finalization after its much shorter search; trace export
cannot be presumed free or constant for this longer, different design.

An unchanged retry or timeout extension would not resolve the solver EOF
cause. The next encoding refinement therefore drives only this concrete
profile's12 external host inputs continuously from the same legal-host
equations, initialized state and actual config/publication/request/response
handshakes. All observed-edge input values, clock/reset timing,12 selected
assumptions, stable cover label,256-step bound, timeout600 and production RTL
are unchanged. The original three symbolic pilot bundles remain separate.
Direct drives expose constants to preprocessing instead of asking the solver
to reconstruct equality-constrained symbolic pins. Removal of between-edge
variation does not alter this all-rising-edge synchronous fixed profile.
No internal DUT progress is constrained. Runtime improvement and successful
witness export remain unmeasured until a fresh execution completes.

## Retention

The exact input, complete output and outer log are retained outside Git at
`/Users/kq/Workspace/lunachip/.phase6-directed-evidence-20261005` as `directed`,
`directed-output` and `directed-run.log`. Output copies compare byte-identically
to the original root
`/private/tmp/lunachip-phase6-dependency-20261005.Cc5eiH`.
No typed result or receipt is manufactured for incomplete execution.

| Artifact | SHA-256 |
|---|---|
| `directed/source-set.lcfs` | `5a423ddedf3dcbc8803c958977940a4b477ad0c86921ff317c5404274e12a52a` |
| `directed-run.log` | `6752f0e71a81a0def3bbec3e0bfd17a882a0ca7b2bd316bec4dbf470794634ae` |
| `directed-output/...-work/status` | `99591af9325a4d7c62edfd4b188784b35939b61a7f748ab36ecb6fba1c8a4777` |
| `directed-output/...-work/model/design_smt2.smt2` | `80dca0c378c9e0f836cd86c5796448a17f38b715cf7d0ed5674c3c6063f988b3` |

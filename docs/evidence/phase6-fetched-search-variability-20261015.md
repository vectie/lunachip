# Fetched Store search variability on an isolated snapshot

## Scope

Separate search-time variability from certificate extraction and checkout
interference. The prior packed run did not return SAT within600seconds, while
earlier identical search prefixes returned SAT at410.840 and467.461seconds.
Those are uncontrolled observations, not a measured packing regression.

Keep the entire qualified prefix through `check-sat` byte-identical, SHA256
`4ed9be0a1de4c9d977413f4560bb54f3725e94be0f948d00785b76b84d14c54d`.
For timing diagnostics only, replace the post-check certificate request with
the original exit suffix. All840 initialized states,839 transitions,13417
assertions, eight host premises, original sampled cover839 and guidance only
through837 remain. Unknown initial memory, held reads, undefined high slices,
invalid-read anyseq, full-width address guards, masks and collision equations
remain untouched. A search-only SAT is not an accepted cover certificate.

## Measurement plan

1. Commit focused instrumentation and tests, then create an isolated validation
   worktree at that exact commit. Use its clean HEAD/status and an input hash
   inventory, not the concurrently edited PRX100 checkout. Build caches stay
   in the one shared automation cache outside evidence.
2. Reverify the sealed packed predecessor and the unchanged search bytes with
   an independent audit. Preserve the pinned AMD64 Bitwuzla0.9.1 CLI and defaults,
   QEMU-only4CPU/8GiB/20GiB VM, isolation and600-second host deadline. Retained
   help from all three earlier runs shows seed27644437 and one solver thread;
   this rules out differing advertised defaults, not every nondeterminism source.
3. Refuse to start while any other container is running. Observe container
   lifecycle events continuously and sample process CPU ticks, resident memory,
   VM pressure and host load during the actual search. Stop only our own runtime
   if overlap is observed; any foreign start contaminates the measurement even
   if the search later returns. Never stop or modify another job.
4. Run one predeclared search-only diagnostic once the VM is idle. A second
   sequential replicate is permitted only if the first is uncontaminated and
   the validation window remains idle. At most two600-second runs; no new VM,
   resource increase, seed tuning, unchanged blind retry or formula modification.
5. Retain actual SAT/UNSAT/timeout/OOM, wall and sampled CPU observations, source
   identity, event stream, input checks and owned cleanup. Compare only like-for-
   like measurements and state limits on causal attribution. Seal unique evidence
   and commit findings; do not promote search timing into witness acceptance.

The MoonBit automation and repository-documentation skills keep this work private
to LunaChip validation. Hardware, public APIs, the user codec, accepted Store and
packet theorems, full fetched safety, explicit-fairness8×8 and remaining Phase6
matrix/aggregate gates retain their existing status.

## Qualified setup

The154-line preparer preserves the entire search prefix and removes only the
post-check observation. Its regression test passes. The434-line session adds
read-only CPU/pressure sampling, timestamped runtime log capture and a continuous
container lifecycle stream. Three native deny-warning tests pass, covering
prior-active and short-lived overlaps, CPU-field offsets and observer-task
cancellation. A separate interval/timestamp audit test also passes.

The detached Git worktree is
`/Users/kq/Workspace/lunachip/_build/phase6-search-snapshot-20261015`.
Inputs were prepared at36292a2; execution is frozen at
`ee5196559953fd06fa23e06387da8e6db23fe158`, whose only further instrumentation
change retains timestamped runtime output. Query bytes are identical in both
prepared replicas, SHA256
`e78184557952ad86dc0e7732bb944362de9b2f7f2e8eca6019bbfc42353d92e0`.
All221 sealed predecessor entries and the unchanged search-prefix hash verify.
Worktree interface generation and formatting checks pass with clean status.
The app worktree helper is bound to the separate LunaNexa checkout, so the
LunaChip snapshot is created directly with Git, detached at the declared commit.

The user authorizes coordination with the PRX100 chat. Its current synthesis
finishes normally; it commits to start no more containers for the reserved
window. Our probe starts only after the VM's running-container list is empty.
The actual pinned synthetic observer probe exits0, records own start/die with
no foreign overlap, preserves clean worktree HEAD/status and performs owned
cleanup. This validates observer plumbing, not fetched reachability.

CPU counters use the documented process user/system tick fields and record
process start identity to detect PID reuse. Raw pressure, host load and swap
observations are retained alongside guest uptime. These are guest accounting
and sampled memory observations, not physical CPU cycles, peak RSS or an
exclusive-host guarantee. See the primary
[Linux proc documentation](https://docs.kernel.org/filesystems/proc.html) and
[pressure documentation](https://docs.kernel.org/accounting/psi.html).

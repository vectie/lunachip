# Fetched Store search variability on an isolated snapshot

## Scope

Separate search-time variability from certificate extraction and checkout
interference. The prior packed run did not return SAT within600seconds, while
earlier identical search prefixes returned SAT at410.840 and467.461seconds.
Those are uncontrolled observations, not a measured packing regression.

Keep the entire qualified prefix through `check-sat` byte-identical, SHA256
`4ed9be0a1de4c9d977413f4560bb54f3725e94be0f948d00785b76b84d14c54d`.
The target remains fetched1×1/K2/host1024/ring4/q2 with the directed R1/H1/C1 host.
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

The preparer preserves the entire search prefix and removes only the
post-check observation. Its regression test passes. The session adds
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

## First completed measurement

RunA uses runtime
`44a73db2d7285d77f57189b8e20fed95c20c35178f81c58cb9c07a88e96300af`.
It starts at05:31:16.748225515Z, enters the original query at05:31:29.503009046Z
and returns SAT at05:38:58.404526632Z:461.656seconds from runtime start and
448.902seconds after query entry. Clean exit0 follows at05:39:10.092630078Z,
473.344seconds total. Neither Docker nor kernel snapshots show OOM.
There is no host timeout, certificate request or accepted witness.

The independent interval audit verifies the full start/die history, including
pre-existing and short-lived overlap cases: no foreign runtime intersects A.
Detached HEAD remains ee51965 and complete status remains empty. Actual query,
input and review hashes match. All owned containers and input volume are removed.
Sixteen retained process samples yield457.13 guest CPU seconds over463.99 guest
uptime seconds, ratio0.9852. This covers the sample interval, not whole-run CPU
or physical host cycles. Raw stdout SHA256 is
`31c299d495cb7a3948b71196aef47bce63926db2cde3bccc2472bba30cc71e05`.

Host conditions are not constant. The PRX100 native suite overlaps A until its
reported completion at13:37:27Shanghai. At05:32:20Z, host swap occupancy is about
29962M and compressor occupancy is739348 host pages. By05:35:46Z, machine-wide
swap-in/out counters increase by12314/23300; compression/decompression counters
also increase. These are observed host memory changes, not process attribution
or proof of the timing cause. VM memory-pressure averages remain zero in the
retained samples. No exclusive-host baseline or packing speedup is claimed.

RunB starts only after A's clean audit, empty VM preflight and the other chat's
confirmation that the native suite has exited and no further heavy validation
will start in the reserved window. It uses the exact same query and execution
snapshot. Both measurements are complete; no third run is performed.

## Second measurement and interpretation

RunB uses runtime
`bac98a0a056491078d3716fb18fb25daceadbb72ef3fa808473f8e040c51b925`.
It starts at05:40:56.552352591Z, enters the query at05:41:05.600735406Z,
returns SAT at05:46:23.378124741Z and exits0 at05:46:35.925521473Z. Its actual
interval/source/input audit passes with no foreign container overlap, source
drift, host timeout or observed Docker/kernel OOM. Raw stdout has the same digest
as A. Both query and input/review inventories match exactly.

| Measured interval in seconds | A | B |
|---|---:|---:|
| Runtime start to query entry | 12.755 | 9.048 |
| Query entry to SAT | 448.902 | 317.777 |
| Runtime start to SAT | 461.656 | 326.826 |
| Runtime start to clean exit | 473.344 | 339.373 |
| Sampled guest CPU time | 457.13 | 333.65 |
| Sampled guest uptime span | 463.99 | 338.98 |

B's observed SAT elapsed time is134.831seconds, or29.206%, lower. Query entry
and search both change by roughly the same proportion. This is consistent with
a host-throughput hypothesis, but it does not distinguish physical throughput,
cache state or differing internal solver work. Guest CPU-to-uptime ratios are
0.9852 and0.9843; these are not instruction counts or physical CPU cycles.
Two observations do not establish a variance distribution or causal regression.

The B host-counter interval05:43:36–05:47:45Z, which extends beyond its runtime,
records10584 swap-ins, zero swap-outs,304693 compressions and337983 decompressions.
The A interval05:32:20–05:35:46Z records12314 swap-ins,23300 swap-outs,
5091830 compressions and4303353 decompressions. The intervals differ in length
and the counters are host-wide, not attributable to a particular process.
They establish changing host memory conditions, not the sole cause of the
earlier timeout. B still begins with31409M of occupied host swap, so swap
occupancy alone is not an appropriate new validation gate.

The operational conclusion is narrower and actionable: a clean detached source
snapshot and an observed VM reservation remove the prior checkout/VM-overlap
blockers. Avoid overlapping known heavy host validation and retain load/paging
observations; do not change memory initialization, address semantics or search
constraints to chase wall time. The packed-certificate timeout is not established
as a packing regression. Next is separately qualified packed retrieval in this
frozen, reserved context, followed by untouched-model and causal/native witness
checks if a complete certificate returns. Search-only SAT is not that witness.

## Closure

Six focused native deny-warning tests, targeted script checking, snapshot
interface generation/formatting and diff/status checks pass with raw records.
The pinned observer probe and both actual measurement audits pass. A's original
optional-duration JSON is retained; the final v2 reports use explicit number/null
encoding with a regression assertion and identical CPU sample bytes. No raw solver
output or historical failure is overwritten.

All three owned runtimes/staging containers and input volumes are removed and
absent in read-only closure listings. The user-authorized VM window is released;
the pre-existing VM is left unchanged for the other job. No foreign resource is
stopped or deleted. The clean detached checkout remains available for the next
Phase6 slice. Unrelated PRX100 edits and the user codec are untouched.

Evidence is relocated to
`artifacts/phase6-fetched-search-variability-20261015`, with exact former and new
paths in `relocation.tsv`. The original tool command paths remain recorded rather
than rewritten. Source identities, two complete self-contained SMT inputs,
actual outcomes, continuous events, timestamped logs, counters, host snapshots,
audits and focused validation are retained; no old regression tree or build cache
is bundled. Useful fetched cover, full fetched safety, explicit-fairness8×8 and
the remaining matrix/aggregate remain open.

The1027-file archive is sealed, about137MiB without build caches. Its1026-entry
inventory SHA256 is
`a879d53d74eb0d831bcf7e55b6448af253781a52c7cc97502fb2b27090b6b896`.
Exact directory-walk/hash verification covers every entry and rejects extra
files; the unchanged packed predecessor also rechecks. Six stepwise commits
record plan, instrumentation, timestamp capture, qualification, A's outcome and
the final comparison. The formal ledger is updated; concurrent PRX100 changes
in the shared status/board documents are deliberately left unstaged and intact.

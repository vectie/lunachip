# Joint generation and saved compute proof

At clean source `94f620d1a2068784535d40906adf211365eb5552`, the exact
generation/compute slice passes actual pinned base checking and k-induction.
Its comparison-only negative control fails the intended saved-authorization
assertion after reset, legal local outer acceptance and a real inner handshake.
This is an unbounded binary local result under the stated environment, not
full-device safety, a four-state equivalence claim or an ordinary gate receipt.

## Exact inputs and scope

The slice retains all 27 original registers: generation 336 bits plus compute
80 bits, totaling 416. Original next expressions, synchronous reset, widths,
initialization and rising-clock domain are copied, not replaced with a modeled
controller. DUT initial state remains arbitrary. Eighteen nonstate cuts remain
free binary inputs (340 bits), plus the clock; there are no memories in this
slice. Queue, load terminal, conflict, preflight and core-completion boundaries
are environmental cuts, not proved subsystems.

The unchanged independent raw decoder and generation reference are combined
with the original compute owner/saved-authorization updates. Functional reference
state is 444 bits; the reset/hold observation pair is 860 bits. Nonfeeding
generation history remains present but is not live relation state. Actual
compute Done, saved ticket and fault feed generation collection. Saved ticket,
ABC and MNK are captured at actual acceptance; later current writers do not
reauthorize a pending Issue. Clear-before-accept and reset priority are preserved.

The clock initializes zero and toggles on each global step. Only the original
first-rising-edge `seen_edge || reset` is assumed. Later reset and all cuts are
symbolic. Equality, legal admission, saved authorization, ownership, readiness
and fairness are not assumptions. Six assertions conclude:

- generation and saved-compute relation at rising PRE sampling;
- both live banks zero after a preceding rising reset;
- relation establishment at all global phases after the first reset;
- the complete 860-bit pair holds over nonrising intervals;
- offered inner commands preserve the independent saved authorization;
- compute terminal ticket matches the accepted compute owner.

`compute-generation DIRECTORY` and the new purpose-specific public exporter
produce exactly six proof inputs. They do not run engines or issue typed
receipts. The full ghost refactor preserves its emitted bytes. No production
hardware, simulator hot path, ordinary task/schema/runner, tool lock or resource
allocation changes; these additions perform no device runtime work.

## Native and compatibility validation

The full native suite passes 816/816, formal-package tests 91/91, and fixture
CLI tests 9/9. Strict native checking including warning73, interface generation,
formatting, default CLI smoke and dependency/source-size boundaries pass.
The public API has a checked documentation example and black-box coverage;
private tests bind every source/reference digest and normalize the single
negative mutation back to the positive bytes.

Fresh exports of all thirteen previous generation artifacts and all 46 ordinary
fixture artifacts remain byte-for-byte and SHA-256 identical. The comparison
inventory digest is
`ad5bcd83ad8a88c4cdb3c25ab47d7c63d955424ca899864f423c3b881671da73`.
All thirteen comparison helpers pass pointwise SAT equivalence over defined
binary operands; the negated miter fails its selected proof. This helper result
does not claim four-state or sequential equivalence by itself.

## Actual engine results and causal witness

The retained external MoonBit driver binds the six inputs, production/reference
identities, clean source, driver and existing pinned lock. It runs two serial
SBY jobs with Yosys 0.68 `38e001a6f`, SBY v0.68 and Bitwuzla 0.9.1;
both use depth12, timeout600, multiclock on and smtbmc/Bitwuzla.

Positive `mode prove`: actual PASS/exit0 in ten seconds. Base checking passes
global steps0–11; induction tries12,11,10,9 and succeeds. Both engine results
are pass. No positive trace is produced. No speedup inference follows from
comparing this local slice with the previous full-harness timeout.

Negative `mode bmc`, `expect fail`: actual FAIL in 22 seconds at global11,
selecting only `lc_inner_compute_preserves_saved_authorization`. Exit0 reflects
the declared expected failure, not a safety pass. Only the checked reduction
comparison changes to `saved_K ^ (inner_accept ? 13'd1 : 13'd0)`; actual DUT
and reference state, reset behavior and all other assertions are unchanged.
Complete VCD, Verilog testbench, SMT constraints and Yosys witness are retained.

The independently reviewed causal sequence is:

| Low-clock PRE step | Following rising step | Actual observation |
| --- | --- | --- |
| 0 | 1 | Joint reset1 commits zero state. |
| 8 | 9 | Legal raw Mat0.2, ticket2, A1/B0/C0, M1/N1/K2; both source resolutions Success, preflight0 and actual outer acceptance1. |
| 10 | 11 | Inner valid/ready/accept1, authorized1, reset0; actual and reference identity remain ticket2/K2, while only checked K is3. |

At PRE10 a different raw head offers ticket3/K1, but outer acceptance is0 and
does not replace the saved identity. The relation remains true. POST11 clears
authorization/inner validity and restores checked K2; those POST values are
not the cause of the assertion failure. Actual `clk2fflogic` preparation samples
the preceding predicate and enables it on the `01` clock boundary. The corrected
collector uses the complete preceding low-phase snapshot for rising-edge causes,
with engine-free PRE/POST and missing/unknown-bit diagnostics. Global-clock
assertions retain their own sampling semantics.

Independent inspection of the actual positive prepared model observes six
assertions, one assumption, 44 anyinit, 22 anyseq, 80 FF and no memories.
All 27 DUT state-Q samplers remain arbitrary (416 bits); zero-initialized
next-data samplers do not initialize that state. The 17 wrapper anyinit cells
are sixteen generation fields (272 bits) and the previous 860-bit pair.
Eighteen declared cuts contribute 340 anyseq bits; four original indexed-ghost
fallback witnesses contribute another 68 unconstrained bits. Four assertions
use the rising PRE sampler; two global assertions retain constant-one enables.
Actual combined source bytes equal the exported Boolean SV, one newline, and
the exported bridge. No extra premise or projected model is introduced.

## Retention and remaining work

The retained source is the exact tested twelve-file implementation at `94f620d`;
native logs record the unchanged precommit tree and engine logs record its clean
commit. Independent emitted-input, prepared-model and actual-trace reviews
are retained with actual preparation, commands, statuses, models and logs.
The temporary root is
`/private/tmp/lunachip-compute-proof-20261006.WpXx4z`; an independently
byte-checked copy is retained at
`/Users/kq/Workspace/lunachip/.phase6-compute-proof-evidence-20261006`.
Its 360-record aggregate inventory SHA-256 is
`7e7dba8d5abbbe2ebf48e28213bc78c9c5769b680352006e89a6af2c786f30b9`.
Compiler caches are excluded; actual positive/negative statuses, four trace
formats, copied driver, tool lock, input inventories and audit files remain
unchanged. Retention verifies bytes without reinterpreting expected FAIL as PASS.

Reproduce the six inputs with `moon run --target native
cmd/phase6-formal-fixtures -- compute-generation /absolute/new-directory`.
The retained helper-staging, sampling diagnostic and proof driver `.mbtx` files
record the exact external sequence. The ordinary full-model runner is unchanged.

Full core, leases, FIFO/memory, load/store ownership, queue/retirement, fairness,
liveness, four-state behavior and the ordinary Phase6 composition gate remain
unfinished. The next step is substitution of the remaining concrete controller
and ownership boundaries, not treating symbolic cut offers as full-device
scheduling evidence or eliminating banks from ordinary tasks without justification.

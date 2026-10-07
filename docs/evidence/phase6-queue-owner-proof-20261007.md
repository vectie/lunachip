# Original engine/live-entry ownership supporting proof

The exact ownership projection at clean source
`ea27f7ec30c252ddf5d48935a051c49e0381e108` now passes actual base case and
k-induction. Its ticket-only negative fails solely the intended engine-identity
assertion after a genuine control admission, saved reservation and loader
acceptance. This establishes the scoped binary ownership theorem, not the
complete Phase 6 device gate. The
[ownership design](../PHASE6_QUEUE_OWNERSHIP_LEMMA.md) and
[input checkpoint](phase6-queue-owner-inputs-20261007.md) remain authoritative
for extraction, correspondence and prior native validation.

## Source and execution binding

The driver requires the reviewed complete six-input inventory SHA-256
`da4a254a853c506e610b4700071d6473c9c24c9b26b056f79ab4ee2d5730765d`,
all five source digests, exact clean committed HEAD and empty full before/after
source status. Every retained input is byte-identical to the sealed export.
Original DUT state, transitions, collectors and all nine conclusions remain
unchanged. The only negative source difference is the guarded checked-loader
ticket plus one; it does not change the real engine ticket.

The pinned image is
`ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`.
Actual versions are Yosys 0.68, SBY v0.68 and Bitwuzla 0.9.1. Tool lock SHA-256
is `b068cdf2900f18b15ec6b484971ac6c8c634767f67ad2a42ef009469b1830973`;
existing version-runner SHA-256 is
`82f85a040af591720a52d20ad9c18b8d0828163fb766f1fe3a1fed499144f56a`.
Execution explicitly uses Docker context `colima-lunachip-phase3`, volume
staging, no network, read-only container root and restricted owned volumes.
No global Docker setting or unrelated resource is changed.

## Exact helper reuse

All nineteen current comparison-helper before/after pairs reproduce the
historical proved miter byte for byte: equality widths 8,16,7,40,3,1,32,13,2,4,
64,5 and unsigned-less-than widths 16,8,13,5,2,64,4. The nonhelper RTL remainder
also matches exactly, SHA-256
`7abc36381a572e3fc89e52a8e30432243b7f58a23fbbeb335bd18a9855e7ce44`.
The prior actual positive SAT success and selected negated-control failure,
their complete logs, source context and pins are verified and retained in 31
reuse records plus their manifest. The historical miter SHA-256 is
`f4668f135892b3728aa73dc3706c20ae19d7812ffc32af52b9b8751ec519f939`.

No identical helper engine is rerun. This reuse establishes pointwise binary
helper qualification; the ownership induction is a new, separate execution.
It does not establish four-state equivalence or universal sequential RTL
equivalence.

## Actual prepared model and clock semantics

Independent review checks actual RTLIL, JSON and SMT, rather than inferring
prepared state from source declarations.

| Actual prepared inventory | Positive | Negative |
|---|---:|---:|
| Hierarchical cells, including DUT instance | 2,745 | 2,778 |
| Assertions / assumptions | 9 / 1 | 9 / 1 |
| Free anyseq cuts / bits | 82 / 1,069 | 82 / 1,069 |
| Original DUT anyinit registers / bits | 30 / 304 | 30 / 304 |
| Observer anyinit registers / bits | 43 / 616 | 43 / 616 |
| Lowered ff cells | 88 | 94 |
| Memories / covers | 0 / 0 | 0 / 0 |

Every original cut name and type is preserved: 24x1, 13x2, 4x4, 23x13, 14x32
and 4x64 bits. Observer anyinit comprises 42 retained PRE samples/312 bits
and previous-state pair/304 bits. Eight unused FIFO PRE samples/12 bits are
removed; positive also removes three negative-only history flags. These are
optimized measurements, not the earlier source declaration counts of 58
observers/635 bits plus a separate one-bit clock.

Seven rising assertions and the sole startup-reset premise retain original
rising trigger polarity. Lowered predicates sample the preceding global state
and enable on seen-global plus sampled-low/current-high clock. The sampled
clock initializes one, the actual toggling clock zero and all eight sampled
predicate registers true. Two global assertions remain always enabled. Raw
busy includes Done, and raw establishment has no later-reset bypass. No
ownership, history, readiness or progress premise is introduced.

Prepared RTLIL SHA-256:

- Positive: `0f26867f3533e4680b900ad5b4b2bafc5c93edf5c4646f39f8640338a4ca73fe`.
- Negative: `93d1e2a7097d25317e7e62e972889cc2686070c7a8445a750f18007210a29642`.

SMT SHA-256:

- Positive: `e648db8e6d779924e0511f695cc6df41227bf9c9966306a9eaeaf1b4884707c0`.
- Negative: `6ff444717157d27c443b14dd972e2f6d8d39e56829fb93d94544679afa113972`.

## Observed engine results and causal sensitivity

Both serial jobs use smtbmc/Bitwuzla, multiclock enabled, depth 20 and timeout
600 seconds. Positive `prove` reports explicit base-case PASS and induction
PASS: 27 SBY clock seconds and 46 process seconds. This is scoped unbounded
k-induction, not merely a 20-step bounded pass. No positive trace is produced.

Negative `bmc` retains all nine assertions and reports FAIL solely for
`lc_owner_engine_identity` at global step 13: 49 clock seconds and 52 process
seconds. Its expected-failure child exits zero, which is not a safety PASS.
VCD, Verilog testbench, SMT constraints and Yosys witness are all retained.

Independent trace decoding and the read-only collector confirm this chain:

| Actual low-clock PRE step | Witness |
|---|---|
| 2,4,6 | Genuine earlier control admissions |
| 8 | Allocate slot zero with saved ticket zero |
| 10 | Committed live nonterminal slot zero/ticket zero; idle loader accepts it |
| 12 | Busy loader FSM 1/ticket zero, raw owner mask `001`; checked ticket one/mask `000` |

At PRE 12, reset is zero, all three causal histories are one, and original
structure, ticket order, bijection, event and raw engine-ownership invariants
remain true. The collector saves reservation identity independently, requires
its committed entry/ticket at loader acceptance and clears epochs on sampled
reset. Genuine additional admission at PRE 10 is also observed.

The failure at global step 13 evaluates the preceding low PRE 12 predicate.
Current POST 13 reset is one and mutation gate zero; those POST values are not
the sampled witness. POST 11 reset is also not a rising-edge sampled reset and
does not break the causal epoch. No POST-only admission or mutation-derived
ownership is substituted for the real PRE chain.

Corrected synthetic diagnostics accept the valid PRE witness and reject
POST-only, unknown, missing, wrong-ticket, no-admission and wrong-sole-label
cases. Actual collection exits zero after checking exact source copies,
complete six-input and 41-engine-artifact membership/digests before and after,
the sole failure and complete trace formats. No engine is rerun. The initial
driver result remains honestly causal-qualification-pending; subsequent
acceptance is supplied by the separate collector log.

## Retained attempts and validation cadence

The initial read-only helper script has four JSON-construction compiler errors;
its source and complete failed logs are retained. Four `.to_json()` repairs
produce a successful read-only reuse qualification. The initial collector has
two missing asynchronous `Unit` return annotations; its original source and
complete failed logs remain. Two annotations and a reviewed literal inventory
pin precede successful synthetic and actual collector runs. Neither repair
changes engine inputs, and no failed attempt is relabeled a pass.

An interactive digest check initially names the parent manifest from the wrong
directory and exits two. The corrected read-only path verifies with exit zero;
no evidence is changed. The support work note distinguishes that interactive
diagnostic from complete raw child logs.

Product source is unchanged this checkpoint. Prior clean 151/151 targeted
formal/Phase6/Phase4 CLI tests, interface/format/strict native checks with
warning 73, exporter build and exact 184-artifact compatibility qualification
are reused, not rerun or counted as new tests. The full native matrix is not
rerun. The documentation guide keeps chronology, observed failures and claim
boundaries explicit in the established repository evidence format.

Sealed support root:
`/private/tmp/lunachip-queue-owner-proof-20261007.O7kpak`.
Immutable repository-local copy:
`.phase6-queue-owner-proof-evidence-20261007`.
The 237-file manifest SHA-256 is
`48c42fa3f4cfab7a9197fe97bb4cd964ef3f6bce4ead2e7bd0c6754ed850c82d`.
Both complete digest checks and recursive original/copy comparison exit zero.
Script caches are excluded. Existing sealed evidence and the user's codec
test remain untouched.

## Remaining gate

The cuts omit packet contents. This proves the named binary ownership
projection under its one public startup-reset premise and arbitrary foreign
conditions, not public packet provenance or completed whole-device composition.
No typed proof receipt or new runner framework is added. Solver durations are
observed costs, not a runtime or solver speedup claim.

FIFO storage order, packet provenance, generation composition, whole-Store
leases, DMA cursor/address/arbiters and nested memories, explicit-fairness
completion, fetched transport and the full 8x8 formal gate remain open. The
original full-device timeout remains unchanged and is not retried here. No
FPGA execution, physical timing, GDS, fabrication or silicon performance follows.

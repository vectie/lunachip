# Original DMA arbiter proof input checkpoint

Commit `f1493e069c7ffc8804bdb4101df473a8c4bd6f76` exports six deterministic
supporting inputs for the original two-client DMA arbiter. All 171 targeted
native tests pass from a clean checkout, and all 190 preceding artifact files
remain byte-identical. These are reviewed proof inputs, not an arbiter theorem
or a completed Phase 6 gate.

## Exact state and emission view

The accepted native component retains 108 original nodes, eleven registers
totaling 172 bits, fifteen raw symbolic boundaries totaling 233 bits and seven
original constant boundaries. Its 28 root/event aliases remain unchanged.
Proof export adds one direct observation output for the retained raw response
data input, with no new operation, state, cut, premise or conclusion. The
exported module therefore has 29 outputs, sixteen inputs, one rising domain
and no memory or CDC primitive.

This observation is necessary because raw response data has no consumer among
the original 28 aliases. The strict emitter correctly rejects original node14,
mapped to local8, as unreachable. An independent regression preserves that
rejection and compares the emission view's complete nodes, specifications,
domains, metadata and first 28 outputs against the native component. The
extra output is an inspected interface observation, not a client-record
passthrough theorem. Production hardware, the original materializer and the
emitter's reachability rule are unchanged.

## Observers and declared conclusions

The bridge samples an independent 104-bit selected raw grant tuple and owner.
Public request/response history records accepted owner, global/local identity
and a modular request counter. Saved PRE values check simultaneous updates;
the next tag is compared with request count, while Wait's expected tag is
compared with the accepted transaction's tag, not the incremented next tag.
No observer feeds the original component or reconstructs missing history from
current controller state.

Eight assertion groups cover payload, history, routes, arbitration, edge
updates, reset-zero, raw establishment and nonrising hold. Six sample on the
original rising edge; establishment and the full 172-bit hold relation sample
on the explicit global clock. The sole premise is first-sampled joint reset.
Later reset, readiness, raw contender payloads and host responses remain
symbolic; no client stability, matching-response, fairness or progress premise
is added.

Saved local-tag identity is checked against the independently captured raw
grant tag. Both original client record tag fields refer to that saved driver,
and both data fields refer to raw host data in the separately reviewed source
contract. These erased record aliases are not invented named IR ports. No
response-data stability or independent passthrough theorem is declared.

The negative changes only the checked payload comparison: bit32 of the
104-bit tuple, corresponding to request data bit zero. It is enabled only
after a real grant and a committed stalled Offer, with the unmodified payload
still equal to the saved grant. Original controller state, observers, premise
and the other seven conclusions are identical. Engine failure and causal trace
qualification remain separate requirements.

## Actual fault and reset paths

The preceding test commit `aa2421d3b2d138a5b5a985d4b7ff73c300b715f7` adds three
finite actual-device correspondence scenarios. A matching remote fault routes
status one without poison, produces the documented completion fault nine,
and permits a fresh matching load without reset. Reserved statuses two and
three do not poison during unconsumed Offer/Wait observations; actual valid
response consumption routes protocol fault two, enters poison and requires
reset before matching recovery. Real Offer and Wait states each retain all
eleven full LogicValues through two changed drive-only events, including
unknown response data and changed clock/reset levels, then clear on joint
rising reset and recover. Counters require the claimed paths to occur.

## Validation and retained inputs

The detached checkout
`/private/tmp/lunachip-queue-control-composition-native-20261007.pnlu45` is clean
at `f1493e0`. Interface generation, formatting, strict native checking with
warning 73, all 171 formal/CLI tests, exporter build, fresh 190-artifact exact
comparison, new input export and source hashing exit zero. All eighteen
retained committed-checkpoint HEAD records match the complete commit and all
eighteen corresponding status files are empty. The 24 focused tests also pass.
The full module test matrix is not rerun.

The public interface adds only
`generate_two_client_arbiter_proof_artifacts()`. The CLI operation is
`dma-arbiter DIRECTORY`; it exports exactly six files into a fresh directory
and refuses overwrite without changing existing bytes. No runner family,
task receipt or proof result is produced.

| Input | SHA256 |
| --- | --- |
| `sequential.lcir` | `630270c01a203c6bf3c8eb0362e4d37693d20daf7ec1e7f883f533488bfb064b` |
| `sequential-production.sv` | `7f816553beebd71f105e5d4da4645631d0a57cae076ef80fd40e36741d413921` |
| `sequential-boolean.sv` | `2b07babdb281679b8a6305c53a5cea68da46c892ccd0b3741a960c2dc73db8fc` |
| `bridge.sv` | `74f5cb9d563ab97f1ad84a922f07eabfe34729792720166a389ae4506c602baf` |
| `negative-stalled-payload.sv` | `f015457400b1762e941397958d10239db7c74f67a540c8a919b7b7e20e4e7c57` |
| `bridge-inputs.txt` | `313043a8550f9d6f1300b65ea966b8dfaf332398b94c2ee064260fbfcf074d8f` |

Support root:
`/private/tmp/lunachip-dma-arbiter-inputs-native-20261007.1DJscW`.
Repo-local copy: `.phase6-dma-arbiter-inputs-evidence-20261007`.
Both verify 533 files with manifest SHA256
`e8acdd0c4a784c378a02c22409846922fbd4a1c19b21a957bf3225bc6e1d377a`.
Recursive comparison is exact excluding disposable caches. Initial parse/type
errors, strict unreachable-node failures, the parsed-output-order test error
and a concurrent interface-generation provenance rejection are retained with
complete logs and corrections. No witness, premise or emitter rule is weakened.
Previous sealed evidence and the user's untracked codec test remain unchanged.

Next qualify the three comparison-helper replacements using the accepted
defined-binary lemma, review actual prepared clock/state/input lowering, and
run serial local induction and the isolated stalled-payload sensitivity task.
DMA bounds, Store lease/payload preservation, storage/provenance composition,
fetched transport, fairness and the full 8x8 formal gate remain open. No
runtime speedup, FPGA, fabrication or silicon claim follows from this checkpoint.

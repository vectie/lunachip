# Engine/live-entry ownership discovery and native checkpoint

Implementation commits `87f9d44` (private discovery) and
`4573cb1de5d56128c2f61737c7d4f8ceaaab0fe7` (native ownership checks) complete
the first checkpoint of the [ownership design](../PHASE6_QUEUE_OWNERSHIP_LEMMA.md).
Clean targeted tests pass 143/143: 140 formal-package/CLI tests and three actual
queue/ownership scenarios. This is candidate discovery and finite native
validation, not an accepted sequential projection or an ownership theorem.

## Exact discovery boundary

The private probe discovers 30 original registers/304 bits through the existing
115 typed observations. It preserves their complete original register
specifications and walks all next/reset/enable expressions and 59 required
derived events. The result contains 1,155 original combinational nodes and
82 candidate foreign leaves. No accepted cut list, remapped module, exporter,
task, result or proof receipt is created. Public interfaces are unchanged.

Canonical production IR remains
`35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc`.
The complete snapshot records every root, event and candidate signature,
including each foreign register's next, clock, reset, enable and initial value.
Root and an independent reviewer inspected the complete actual inventory
before the snapshot update. Report compaction removes only formatting newlines.

The 82 candidates are seven public inputs and 75 foreign registers; there are
no memory-read or asynchronous-storage candidates. Canonical node ordinals
below document actual discovery, not hand-selected replacement roots.

| Candidate group | Count | Original nodes |
|---|---:|---|
| Reset and public descriptor/completion/memory handshakes | 7 | 1, 4, 9–13 |
| Saved head packet lanes | 4 | 16–19 |
| Writer status/tickets and captured dependencies | 16 | 47–62 |
| Arbiter state, owner and tags | 4 | 387, 388, 391, 392 |
| Loader selection, shape, cursor, tag and operand | 7 | 426, 428, 429, 432, 433, 435, 439 |
| Storer selection, shape, cursor and tag | 6 | 442, 444, 445, 448, 449, 451 |
| Compute lease, selection and shape | 7 | 456, 458–463 |
| A/B slot validity and shape | 12 | 558–569 |
| Slotted wrapper state and selectors | 6 | 704, 707–711 |
| Underlying execute FSM | 1 | 733 |
| Operand-bank prefixes | 4 | 791, 796, 822, 827 |
| C result validity and shape | 6 | 1082, 1087, 1088, 1131, 1136, 1137 |
| Result response fault and ID | 2 | 1177, 1178 |

All foreign registers use original rising clock node 0, synchronous active-high
reset node 1 to zero, and no initialization. Six retain nonempty
enable fields: four C shape latches and the result response pair. None of these
signatures is omitted or accepted as an arbitrary cut by this checkpoint.

Source review finds the proposed narrow abstraction plausible only while shared
opcode decode, reset, Idle, response, failure, terminal, local-termination and
collector equations remain exact. An arbitrary shared packet value within an
edge is not several independently free engine-accept bits. Foreign payload/core/
transport state may alter delay or failure; this does not establish dependency
generation, packet identity, leases or DMA correctness. No internal relation,
readiness, fairness, payload stability or response-pairing premise is added.

## Actual native scenarios

The private test helper checks the relation continuously over unchanged hardware,
using existing observation and host helpers. It treats Done as busy, checks the
pending-head-or-engine bijection for every live nonterminal entry, distinct
owner tickets, the contiguous ring and modulo-UInt32 live ticket order, and
exact acceptance, collection, allocation and acknowledgment equations.
PRE snapshots additionally check POST capture, ticket stability, terminalization,
Done-to-Idle and acknowledgment effects; no second transport model is introduced.

The existing six-command duplicate-ID scenario retains every preceding assertion
and gains PRE/POST ownership checks plus an unconditional witness requirement
for simultaneous reservation and older acknowledgment. It exercises loader,
compute, storer, local rejection/fence and held ordered retirement.

One added scenario requires genuine Store/compute overlap with distinct owner
tickets, younger collection while the older Store is nonterminal, and a fresh
compute acceptance/collection behind held oldest retirement. It checks the
actual stored numerical result 31 and ordered completion drainage, all with
repeated caller ID 73. Another reaches loader Wait with a delayed host response,
asserts joint reset with adversarial public handshakes, checks all 30 essential
registers zero, explicitly flushes the host epoch, and requires exactly one
fresh acceptance/collection with requests only at addresses 64 and 65.
Reachability counters are required, not inferred from test names.

These finite runs do not exercise physical UInt32 ticket wrap or establish an
unbounded relation, triple-engine overlap or the complete 8x8 product gate.

## Committed-source validation and compatibility

The clean frozen checkout is
`/private/tmp/lunachip-queue-control-composition-native-20261007.pnlu45`, at exact
commit `4573cb1de5d56128c2f61737c7d4f8ceaaab0fe7`. Its existing build cache is
reused; preceding sealed roots are untouched. Interface generation, formatting,
strict native deny-warning checking with warning 73, all 140 targeted formal/CLI
tests and three targeted native ownership/queue tests exit zero. Every frozen
command retains unchanged committed HEAD and empty source status. The full
native module matrix is not rerun.

The support root retains three intentional pre-update inventory mismatches:
complete multiline output, an incomplete first-newline-only formatting attempt,
and the corrected complete one-line-per-signature output. Each runs three tests,
passing the two structural tests and failing only the deliberately empty
snapshot. The final clean committed rerun passes all three. The formatting
repair changes reporting only; no ownership predicate or production logic is
weakened.

Fresh exports of all 184 preceding artifacts across nineteen inventories match
exact bytes and SHA-256 without normalization: 153 ordinary artifacts, 13
generation inputs, six compute inputs, six queue-control inputs and six original
monitor inputs. Source HEAD/status and helper/exporter hashes remain unchanged
through comparison. Independent review verifies this exact source-bound reuse.
No formal engine is invoked at this checkpoint.

- Prior 178-artifact manifest: `e87dced38059bf4320763d1ad69b6072685ec01905a75ffddacb208be0db6bd5`.
- Sorted six-monitor manifest: `4fff9be6f74b7808cb3f8dcbfae3b0e2f22cdce6c3cf1b8e1f20869eb5757182`.

The monitor manifest uses sorted names, unlike the preceding separately ordered
manifest. Only manifest row order differs; every monitor file remains byte-identical.

Sealed support root:
`/private/tmp/lunachip-queue-owner-native-support-20261007.Vd38lL`.
Repository-local immutable copy:
`.phase6-queue-owner-native-evidence-20261007`.
The 466-file support manifest SHA-256 is
`b5484fde90a5f575be8daec7d8b3902ca0d1d4b7cf2b21a500a967ef6764b26f`.
Both complete digest checks and the original/copy recursive comparison exit
zero. Script build caches are excluded from sealing and retention; no sealed
evidence is modified or used as a writable build directory.

## Remaining work

Next freeze a reviewed, fail-closed candidate allowlist, materialize the exact
sequential projection with existing remapping helpers, test correspondence and
transitions, and establish the ownership relation by original-clock induction
with a genuine ticket-identity sensitivity failure. This checkpoint does not
complete larger composition, FIFO storage order, provenance, generation, Store
leases, DMA/memory safety, fairness, fetched transport or the full Phase 6 gate.
No physical chip or performance claim follows.

# Direct queue retirement record checks

This supporting slice checks immutable terminal records and selection of the
oldest stored retirement entry in the actual direct 1x1/K2/host1024/q3 device.
It extends the [queue conservation obligations](PHASE6_QUEUE_CONSERVATION.md)
without replacing them. Ordering from independently saved public-admission
packet bytes, engine ownership, leases and eventual completion remain separate
requirements of the complete Phase 6 gate.

## Fixed inputs and compatibility

Reuse all 115 existing typed observations, the ordinary hardware graph,
production RTL, Boolean comparison adapter, property exporter, registry,
task schema and pinned runner. No new hardware node, debug ABI port, shadow
controller, internal cut or receipt framework is introduced.

Add two approved identities to `QueueFormalFixture`:

- `RetirementRecords`: `phase6-queue-retirement-records`;
- `NegativeHeldPayload`: `phase6-queue-negative-held-payload`.

Both existing queue bundles and all nine older formal bundles must remain
byte-identical. The new positive task selects all three conservation assertions
and the three record assertions below, not assumptions about their truth.
Keep four public-peer assumptions, initial joint reset, symbolic later reset
and malformed responses, PRE sampling, two global steps per DUT clock,
256 global steps / 128 DUT clocks, timeout 600 and `smtbmc-bitwuzla`.
No fairness or internal-progress premise is added.

## Record assertions

`terminal_entry_immutable` watches each of the three entries independently.
At a nonreset PRE sample, `EntryValid && EntryTerminal && !EntryAcknowledge`
saves its ticket, caller ID, fault, progress and address. At the next nonreset
PRE sample, require valid and terminal plus equality of every saved field.
This includes the PRE boundary at which acknowledgement first becomes true.
Reset clears the watch. Invalid entries may retain stale terminal bits; they
are not immutable live records and must not activate the watch.

`oldest_terminal_selected` independently selects entry zero, one or two using
the observed retirement read pointer. Require its range, and require public
completion-valid exactly when that selected entry is valid and terminal.
When public completion-valid is true, compare caller ID, fault, progress and
address with the selected entry. A younger terminal must not bypass an oldest
unfinished entry. This is oldest stored-entry selection, not a proof that its
contents came from the corresponding public-admission packet.

`held_completion_immutable` samples public valid with ready low, saving all four
payload fields, read pointer and selected ticket. At the next nonreset PRE
sample require valid and equality of the entire saved record and selection,
including when ready becomes high on that release edge. Reset cancels the
watch; the current ready value must not disable it.

## Nonvacuity and sensitivity

The positive bundle has one six-assertion bounded safety task and one separate
held-oldest/younger-collector cover task. Keep the old property IDs and append
the three assertions and the new cover; the older full/refill cover remains
declared but is not selected by this new profile. Its existing task remains
unchanged in the conservation bundle.

The new cover requires one coherent adjacent-edge history. At the first PRE,
the oldest completion is held, and an actual collector fires for another
valid nonterminal entry. Save both selected tickets, the younger entry index,
oldest read pointer and public payload. At the next nonreset PRE, require
the same younger entry and ticket valid and terminal, and the same oldest
completion still held with unchanged pointer, ticket and payload. Clear
history on reset; do not accumulate unrelated sticky milestones. Caller IDs
may repeat and are not substitutes for tickets or entry identity.

The negative selects only `held_completion_immutable`. After a genuine stable
hold with the raw current record matching the saved record, flip bit zero of
the saved caller ID only in the checked comparison. Leave DUT, raw observations,
assumptions, watch updates and other comparisons identical. Restoring that one
expression must reproduce the positive harness exactly. An actual selected
counterexample is required; generated expected-failure metadata is not evidence.

## Implementation and acceptance

Keep record monitor construction in focused private files in `validation/formal`.
Extend the existing bundle and CLI additively; no first-party service or new
automation architecture is needed. Separate authoring and native validation
from independent tool execution. Compiler, tests and external engines run
serially; agents may author isolated source and review concurrently.

Native tests must bind exact property and task selections, timing, registry
identity, deterministic artifacts and full production IR/RTL identity. Check
the negative's single comparison mutation and unchanged history, and preserve
older bundle bytes. Exercise actual hold, release, later reset, younger
collection and duplicate IDs in a real-DUT replay; monitor text checks alone
do not establish these behaviors.

Actual acceptance requires exact-adapter pointwise Boolean helper SAT and its
negated control, the complete six-assertion safety result to the declared bound,
a complete cover witness and the selected negative counterexample through the
unchanged pinned runner and typed result mapping. Inspect PRE ownership and
adjacent-edge history in both traces, retain failures and original receipts,
and archive all inputs and outputs by digest.

No unbounded, fetched-device, 8x8, fairness, complete Phase 6, physical RAM,
timing, power, FPGA or silicon claim follows from this supporting slice.

The [actual formal execution](evidence/phase6-retirement-record-formal-20261006.md)
accepts the selected negative counterexample. Full safety times out, and the
cover times out before exporting a complete witness. These retained outcomes
do not satisfy the positive acceptance requirements above.

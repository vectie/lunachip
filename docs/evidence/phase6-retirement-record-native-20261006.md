# Retirement record native checkpoint

The additive retirement-record implementation passes the complete native gate:
842/842 tests, public interface generation, formatting, strict native checking
including warning73, CLI smoke and dependency/source-size boundaries. The
implementation and CLI are committed separately as `147295c` and
`1c9277730aab2c77653518bd71c74d75d1914a91`, then integrated into the main tree.
This is native validation and artifact preservation, not a device formal pass.

## Source and retained evidence

The native gate ran before those commits at HEAD
`65a5400ce62c4f5cfcb25c381b651d9e341daaef` with the pending source edits. Its
before/after HEAD and complete dirty status listings match; this does not assert
that formatting never changed a file's contents during the gate. The subsequent
native build and thirteen serial CLI exports ran on unchanged, clean `1c92777`.
No precommit validation is relabeled as a clean-source result.

The full support directory is retained at
`/Users/kq/Workspace/lunachip/.phase6-retirement-record-native-evidence-20261006`.
Its316-file inventory, plus the inventory file itself, agrees by recursive byte
comparison with `/private/tmp/lunachip-retirement-support-20261006.MLdTBl`.
Independent review also verified actual exits, source contexts and all artifact
digests. Retention inventory SHA-256:
`dedcada05653018fe80472a9eb14da44b704a37a842e4e42af7a142e17462aa4`.

Earlier attempts remain intact. Standalone interface generation succeeded but
its source-freeze wrapper correctly rejected the newly generated interface
status. Two strict checked-example qualification warnings were corrected, and
an invalid targeted-test argument failed before running tests. The first export
test detected an expected-order mistake: canonical task labels sort lexically,
so p10 precedes p4. The corrected test checks that exact order; no generated
hardware or task bytes were changed to satisfy it. A source review also caught
missing combinational settlement before PRE samples in the new behavioral test;
that was fixed before its successful execution.

## Implemented checks and actual native behavior

The [frozen design](../PHASE6_QUEUE_RETIREMENT_RECORDS.md) extends the existing
115-observation direct1x1/K2/host1024/q3 fixture. The only public interface
additions are the `RetirementRecords` and `NegativeHeldPayload` enum cases.
Private monitors watch all three terminal entry records, independently select
the oldest stored entry, and preserve a held public completion through its
release edge. Each entry comparison includes its ticket and complete132-bit
record; public payload comparisons include all100 bits, pointer and ticket.
Reset clears history rather than requiring stale records to survive.

The separate cover binds an actual younger collector and its immediately
following terminal entry to a still-held oldest pointer, ticket and payload.
The negative changes only one saved caller-ID comparison after a genuine stable
hold. Restoring that expression reproduces the entire positive harness.
Generated task expectations are not executed proof results.

The real-DUT native test uses six commands with repeated caller ID73 and tickets
0..5. A delayed first load permits a younger local terminal without bypassing
the unfinished oldest entry. Genuine younger collection occurs while the
oldest completion is held; all three terminal records are watched and the
release boundary is checked. Five actual request/ACK pairs and result31 match
the full1024-byte oracle. A later held Fence is jointly reset; fresh Fence
admission restarts at ticket0. Both new focused tests pass individually.

## Exact preservation and outstanding tools

All93 older formal artifacts plus the two original queue bundles'20 artifacts
retain exact filenames, bytes and SHA-256 digests:113 total. The two new bundles
export eleven and nine deterministic artifacts, inventoried separately.

| Inventory | SHA-256 |
| --- | --- |
| 113 retained artifacts | `54f97a37dda50b94ba8c950bd4857b4209ae0f544f428d4923255fad8ec5debb` |
| 20 new artifacts | `889bf14abbae893506bb5629e9545127bbda4af86bdd2452b4978570212eab55` |

Both new bundles' canonical IR, ordinary production RTL and isolated Boolean
adapter also match the original queue fixture byte-for-byte. They add no
hardware state, ABI port, cut, shadow controller, internal progress or fairness
assumption. Their four public-peer assumptions, PRE timing,256global/128DUT
bound,600-second timeout and pinned engine remain unchanged.

The new six-assertion safety task, adjacent-edge cover and selected negative
still require their own actual outcomes. Oldest stored-entry selection is not
independent public-admission packet provenance. Saved-packet identity, engine
ownership, leases, ticket wrap, fairness, full-device/fetched/8x8 safety and the
complete Phase6 gate remain unfinished. Physical claims remain excluded.

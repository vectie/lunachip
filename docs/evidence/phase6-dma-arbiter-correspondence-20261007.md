# Original DMA arbiter actual device correspondence

Test-only commit `3f4b408cf8edbc3c50271f4c16ec4b06b67a9524` validates the
[exact original sequential component](phase6-dma-arbiter-materialization-20261007.md)
against the actual queued accelerator at PRE and POST edges. All 159 targeted
tests pass. The prior 190-artifact compatibility result is reused with unchanged
implementation sources. This establishes finite native correspondence, not an
unbounded arbiter theorem.

## Original graph comparison

The actual fixed direct 1x1/K2/host1024/q3 queued device executes unchanged.
Fifteen original boundary LogicValues drive the projection, preserving width,
value bits and known mask. Every sample compares all eleven retained registers
and seventeen derived events. The source and projection each commit once from
PRE state; only afterwards are POST boundaries mirrored and outputs compared.
Retained register values are never injected as inputs. Startup unknown state is
sampled explicitly, and actual joint reset clears all eleven registers.

The scenarios use finite named public response transcripts and existing packet/
observation helpers, not a second host-memory model or replacement controller.
All accepted request fields, addresses, owner identities and local/global tags
are checked. Production hardware, IR, simulator, exporter and public interfaces
are unchanged; no premises or proof-input exports are added.

## Required actual paths

The matching transcript first loads A0=[2,3], B0=[5,7] and computes C0=31. A
younger LoadA1 waits for its first bus response while StoreC0 is admitted. The
response is consumed on the same settled PRE edge as actual Store engine
acceptance, exactly once. Subsequent original transitions produce simultaneous
raw reader/storer requests; an actual tied grant must favor Store. Its real Offer
is held for three edges with both contenders valid, checking complete saved
payload through the acceptance edge.

The seven accepted request addresses are 32, 33, 64, 65, 128, 256 and 129,
with global tags 0 through 6. Store data is 31, size four and mask fifteen;
reader requests use size one and mask one. Local tag capture and owner identity
are checked separately from global tags. Required request/response counters
are six reader transactions and one storer transaction. The younger load and
Store complete successfully with two and four bytes respectively. Counters
require the contested grant and stalls; test names alone are not witnesses.

The malformed-tag transcript consumes a response tagged one when the accepted
request expects zero, routes protocol fault two only to the reader and enters
poison. Four subsequent actual poison edges suppress requests and response
readiness while unsolicited host tag/data change. A later joint reset clears
state; a fresh LoadB at addresses 64/65 consumes matching tags 0/1 and completes
successfully. Total reader requests/responses are three each, malformed
consumption exactly one and sampled reset count two.

Remote/reserved response status, active-Wait reset, nonrising events and arbitrary
symbolic contender changes are outside these two finite scenarios. The
supporting proof must cover its declared symbolic boundary separately.

## Source validation and compatibility reuse

The clean detached checkout
`/private/tmp/lunachip-queue-control-composition-native-20261007.pnlu45` is at the
complete test commit above. Interface generation, formatting, strict native
checking with warning 73 enabled, all 159 targeted formal/CLI tests, compatibility
reuse verification and source hashing exit zero. All twelve before/after HEAD
records match the exact commit and all twelve source statuses are empty. The
two focused tests are included in the total. The full native module matrix is
not rerun and no HDL compiler or formal engine runs.

The exact diff since `ae84d15` contains only three white-box test files and the
three preceding checkpoint documentation files. All non-test implementation,
exporter and tool sources remain identical. Accordingly, the previously accepted
190 exact artifact byte comparisons are reused, not re-exported. Their pinned
479-file sealed support inventory is reverified read-only with SHA-256
`3c53a4373101a8a6bce784483a512369f68dc4073a97d910176118995d8df7ca`.
The source allowlist, prior verification command/exit and reused comparison are
retained; no fresh exporter build or fresh artifact comparison is claimed.

The initial strict check exits 255 with effect error 4122 inside a pure iterator
lambda. A typed array loop preserves the same eight payload fields, order and
full LogicValues while propagating the checked error. Corrected check and both
focused scenarios pass without weakening any witness. Initial/final sources,
complete child logs and independent acceptance are retained.

## Retained evidence and next scope

Support root:
`/private/tmp/lunachip-dma-arbiter-correspondence-native-20261007.jKQEvY`.
Repo-local copy: `.phase6-dma-arbiter-correspondence-evidence-20261007`.
Both verify 109 files, with manifest SHA-256
`dc672a08b6bffd2a113f4c3c666b4fc4a6ced9fc5915683b605cb3b05b6846c3`.
Recursive comparison is exact excluding disposable build caches. Previous
sealed roots and the user's untracked codec test remain unchanged.

Next add reviewed observer conclusions and export source-bound proof inputs,
then run local induction and the comparison-only stalled-payload sensitivity
control. The full Phase 6 gate, Store/memory/storage obligations, fetched
transport and explicit-fairness completion remain open. No speedup, FPGA,
fabrication or silicon claim follows from native correspondence.

# Direct8 pending payload and client phase qualification

This qualification adds original-state pending-read ID/status and active
C-slot metadata support for the remaining client/engine phase-ownership
conclusion. The accepted 51-conclusion ACK/credit proof and every earlier
sealed outcome remain unchanged. New inputs and passing native tests do not
constitute an unbounded proof.

## Frozen inputs

Clean source: `1b369ade3e25a06a1bad0f92ad131cf8b1e65cd0`.
The design and qualification order are in
[the pending payload plan](../PHASE6_DIRECT8_PENDING_PAYLOAD.md).

| Task suffix | Selected conclusions | Actual assertions |
| --- | --- | --- |
| `engine-service-payload-r2-h2-prove` | Prior 48 plus three metadata/response groups, 51 total | 135 |
| `engine-service-phase-payload-r2-h2-prove` | Original joint 52 plus those groups, 55 total | 139 |

Both use the `phase6-flux-tile-direct8-q3-` prefix and retain k-induction32,
the original 600-second cap and seven public R2/H2/C2 premises. Every
support fact is jointly asserted, never assumed. The joint task can qualify
its included facts independently of the smaller task's outcome; no smaller
component becomes a permanent extra gate.

Ten typed aliases follow original Store-valid comparisons, indexed read
acceptance, full UInt32 ID latches, UInt2 read status and C-slot metadata.
The three new groups assert active Store/C shape agreement, pending ID
identity and accepted/pending good status. They do not read SRAM words or
change the original hardware, reset, enable or memory equations. All 38
memories/8,960 unknown initial storage bits, unknown read INIT, UInt13
cursors, UInt64 DMA address arithmetic and complete payloads remain.

| Artifact | Payload SHA256 | Joint phase payload SHA256 |
| --- | --- | --- |
| DUT | `4be9d6b6423a3b8ac568c5284d3bd83392b68314e46ef0059727fb27dc928bd3` | `ae94910f5b22f163ece206a83de6b949b9ff3e37d0c27ada71551639d733541f` |
| Source set | `9b0f94eee813d370acd8954be1f50461029765640273e15ca8a277147cd10eee` | `665bb70c840573660b054a842847264bff051f16c2f63349a4c7d6f47e8aac76` |
| Properties | `f02706eac572c6fad76e64071d6166f60def56d406dfe5be097b303000b8e10b` | `db36a98dace14a2358056faf4b157a2f36be1a38fe6d3d23a40d8934e6f2b13d` |

## Input validation and resource boundary

Three focused tests pass, including two competing complete slot pipelines
with 128 real indexed reads, held requests, preflight rejection, reset without
erasure and high-ID-bit/status/full-width-dimension mutations. These native
checks are not formal reachability witnesses.

Fresh clean-snapshot preflight passes 63 native tests (20 baseline, 10 arbiter,
33 engine), six verifier tests, seven automation tests, 22 typed task checks
and 20 exact helper audits. Strict checking, formatting and interface generation
pass with no API or frozen-source diff. Accepted 51 and earlier 48/49/52/57
input pins remain exact. Removing only added aliases/support and replacing
the assertion export restores the prior DUT byte-for-byte; regeneration is
lossless and canonical IR, names and the public harness remain unchanged.

Implementation is committed in the existing private snapshot during the
peer's shared-source freeze, then published after its explicit checkpoint
release. The peer's separate 1,180-test production/PRX pass is not this proof's
source identity. Heavy validation and solver measurements use a coordinated
window after both native and Docker release. The pinned QEMU startup check
passes with Yosys0.68, SBY0.68 and Bitwuzla0.9.1; no Rosetta or VM change is
made. At most two distinct sequential 600-second jobs are reserved, preserving
actual outcomes and original-model/typed-binding review before acceptance.

## Payload component outcome

The payload component returns `TIMEOUT 8 343`, runner exit 8, 609 host wall
seconds and 601 SBY clock seconds under the original cap. Base 0–31 passes
at 201 solver seconds; induction last reports step 19. The status's 343 is
process time, not wall duration. No trace, typed result or receipt is produced.
The timeout does not diagnose a false predicate or a reachable failure.

Independent review passes for 135 actual assertions, seven original premises,
all 38 memories/8,960 unknown storage bits, unknown read INIT, exact compiled
sources and a clean unchanged snapshot. Protected-volume inventories match
and owned transport cleanup leaves Docker empty. The distinct joint task
follows under the same frozen source, without assuming the payload groups
or changing memory/address semantics, induction depth or the search cap.

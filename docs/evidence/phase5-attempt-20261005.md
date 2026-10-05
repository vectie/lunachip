# Phase 5 aggregate attempt — 2026-10-05

Status: **incomplete, not a Phase 5 pass**.

The new `scripts/phase5-gate.mbtx` ran against snapshot
`62f083b810c1aeb200e46aeff6dbf81e6e8cd6a9` in an isolated checkout. It reused
the existing native gate and nine child gates without changing their claims.
The pinned images ran through the existing `lunachip-phase3` Colima profile,
using volume transport.

Completed before the failure:

- warning-strict native check, all 542 tests, CLI smoke, and dependency/source
  boundaries;
- the pinned synchronizer differential gate, including its required negative
  ordering case. Child receipt SHA-256:
  `0fcc6817107510d6902eebb21c6e6b4e34159ea8e9fb4ec6a93a976b0a118169`.

The handshake gate stopped at fatal `DECLFILENAME` lint for the coincident
refill fixture. Its injectively encoded module identifier exceeded Verilator
5.050's internal long-name boundary. The checked source describes automatic
hashing for names longer than 127 characters:
[Verilator v5.050 V3Options.cpp](https://github.com/verilator/verilator/blob/v5.050/src/V3Options.cpp#L641-L647).
The internal fixture was renamed from `Phase5HandshakeCoincidentRefill` to
`Phase5HandshakeRefill`. No logic, warning policy, canonical encoder, or
published naming contract was changed. This is a fixture compatibility fix,
not a claim that arbitrary long identifiers are independently validated.

The full standalone handshake gate then passed: five fixtures, 295 exact-time
events, and its required sequential-order negative. It ran on the same commit
plus the name patch, with unchanged start/end child input inventories. Receipt
SHA-256: `a38fef41e46145e38fc460f469e2bec5cc589b04de7b68256c41aca425fae046`.

Retained local artifacts:

- aggregate attempt: `/private/tmp/lunachip-phase5-aggregate-20261005`;
- failed aggregate summary SHA-256:
  `948ab43d520b7ca498d749e18f6e779038c33dde5e1f923fb784b0310eae2f1a`;
- incomplete artifact manifest SHA-256:
  `34b63cb11089e46230b11e38c576939e927443bf24a6a32d674e3137236061b4`;
- standalone handshake rerun: `/private/tmp/lunachip-handshake-20261005-shortname`.

The aggregate stopped before FIFO differential, three synthesis gates, and
three formal gates. Individual successes are not combined into a phase pass:
all nine child gates and native validation still need one successful aggregate
run on an unchanged snapshot. Temporary local artifacts are not durable
checked-in evidence; this note records their identities and the observed
failure without promoting any additional product claim.

## Second aggregate attempt

An unchanged clean snapshot of `61b38aff6e06ec4cdeefb63c11ca5c631c15780a`
ran the aggregate at `/private/tmp/lunachip-phase5-aggregate-20261005-r2`.
Native validation (542 tests), all three differential gates, and all three
synthesis gates passed. The FIFO synthesis receipt records actual pinned
pre-map typed-graph and memory-topology checks for three profiles; physical
RAM mapping and timing remain unclaimed.

| Child receipt | SHA-256 |
|---|---|
| Synchronizer differential | `c578e5292dfe86a083bc9d52f1b64ad54178768c6870dfc7f9584e5860371de5` |
| Handshake differential | `40c321f8fa493d6862ce231cecf03f407619fe33d6ee298a7cbe4b742885e102` |
| FIFO differential | `a984345554709b78de4608333dd7ae8fc9ad6c5312d3750b91db06da4610935f` |
| Synchronizer synthesis | `763ac33161f393fe9714e7c9597cc20f3be320a1951b624d208b021e017798ea` |
| Toggle synthesis | `49c222cd863d1ac3a3b6e12c8344f9ada9278c3fac9dc87191532bd77394acfe` |
| FIFO synthesis | `5d2d40334a721cf435d6b157acb37bd1026c356ec10f1fe885bb1a84e10c9cc8` |

The aggregate stopped during synchronizer formal. Its deliberately broken
pipeline correctly failed the named assertion at step 7 and retained a
counterexample, but the separate pinned `sby --version` process crashed with
`Segmentation fault`. The resulting version record lacked `SBY v0.68`; the
runner correctly refused evidence with a version mismatch. The incomplete
aggregate summary hashes to
`8b40f3ab0fb79be429e57d72dd21f1e8751f6c7dccbb56453433b1e4319d0802`.

An immediate unchanged pinned version probe passed. A fresh standalone
synchronizer formal run also passed all four fixtures/five tasks, including
the required negative controls, at
`/private/tmp/lunachip-sync-formal-resume-20261005`. Its receipt hashes to
`138885cf5df412358be7118f815ab52eefea5fa6a4aab998eba08049eb300e1a`.
The underlying executable crash has not been established as a source defect;
no runner, lock, assertion, or version check was weakened. Separate child
passes still do not replace a successful unchanged-snapshot aggregate.

## Repeated external startup failures

A fresh unchanged aggregate at
`/private/tmp/lunachip-phase5-aggregate-20261005-r3` again passed native,
three differential, and three synthesis gates. It stopped with status 139
when launching `valid-synchronizer-bmc`; this time the task itself failed to
start, not only a version probe. Its log contains the transport initializer
and `Segmentation fault`, with no formal result. The incomplete aggregate
summary hashes to
`cc3c48b7209ddf0fe66d6bc996cc27f6466e4dd5cbf13ac13a0f58bc018d66e6`;
the failed task log hashes to
`e1bcb9bb9ffa32a62833e9d15f1a31509bd306a8b3f370b11c324bc27a9f0749`.

The unchanged standalone toggle formal gate passed nine fixtures/twelve tasks
at `/private/tmp/lunachip-toggle-formal-resume-20261005`, receipt SHA-256
`d024c8820c0770162ffe2bf6439d469917d2a50b5da5fe42fb6cfae5b38e0849`.
A standalone FIFO attempt at `/private/tmp/lunachip-fifo-formal-resume-20261005`
retained another missing-SBY-version failure after its intended broken-address
counterexample. These failures establish repeated external process-startup
instability; they do not establish a positive hardware assertion failure.

Read-only runtime inspection found an aarch64 VZ guest with Rosetta disabled,
running the pinned linux/amd64 image through QEMU x86-64 7.0.0. The image's SBY
entry point invokes `/usr/bin/python3`, Python 3.14.4. Newer Python under that
older cross-architecture emulator is a plausible explanation, not a proven
root cause. No VM configuration, image lock, assertion, or evidence check was
changed. Reproduction on a more reliable supported runtime remains required;
Phase 5 is still incomplete.

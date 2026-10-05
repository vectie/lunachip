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

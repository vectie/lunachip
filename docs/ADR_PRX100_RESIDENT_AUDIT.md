# ADR: complete resident audit and completion-snapshot evidence

The existing `scripts/prx100-layer-resident-audit.mbtx` is a single, ordered
independent audit of source identity, programs, input integrity, every numerical
payload, transaction coverage, counters, sample windows and timing. The paired
completion-snapshot experiment extends it just beyond 800 lines. Retain that
ordered closure in one script rather than duplicate its numerical and physical
checks in a second diverging auditor. This is a limited source-size exception.

Legacy receipt modes retain all original counts, emission reconstruction and
transaction guards. The explicitly marked paired mode has ten full and ten
decode samples; exact counts change accordingly. Captured counter/status files
are verified by the focused completion auditor against the actual final two-word
DONE poll and legal nine-word count/counter transaction and are not represented as physical scatter reads.
The new policy is accepted only after reviewed-source emission replay, complete
policy/order/count-cache/capture checks and unchanged hardware qualification.

Keep vendor-host emission and its modeled regression tests in separate focused
`.mbtx` scripts. No unrelated audit mode or hardware feature belongs in this
exception. Archive the exact auditor source used for every campaign; historical
sealed auditors and evidence remain immutable.

The 2026-10-22 paired weight-layout campaign reuses the same complete numerical
and physical closure with an explicitly marked receipt: all twenty measured
launches use the unchanged snapshot host policy. Its diagnostic scatter plan
therefore has 321 entries and 26 calls. A separate packed-weight auditor checks
the byte permutation, disjoint DDR extents, every program installation and
the alternating layout schedule. Hardware qualification remains separate.
The existing policy-pair and ordinary modes retain their original checks.

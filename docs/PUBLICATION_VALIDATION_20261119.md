# GitHub publication validation — 19 November 2026

Pending changes were committed separately as execution/core foundations,
board and memory protocol validation, hardware workflows, and target/evidence
documentation. Existing sealed archives were preserved. Newly generated hidden
phase build directories and Python caches remain excluded from Git.

`moon info`, `moon fmt`, `moon check --target native --deny-warn` and
`moon test --target native --deny-warn -j 2` passed. The complete native suite
finished with **1,421 passed, zero failed**. These are software simulation and
protocol checks, not a new physical FPGA, synthesis, timing or board campaign.

Before publication, a complete Git bundle was saved and verified at
`/tmp/lunachip-before-lfs-20261119.bundle` (local recovery artifact).
An all-ref inventory found a historical 136,989,167-byte object, but the
main-only reachability audit found **zero blobs over 100 MiB**. Therefore the
canonical main history is published unchanged; no LFS conversion or history
rewrite is required. An isolated experimental LFS clone is not the publication
source. The original repositories, refs, archives and raw artifacts remain
available locally.

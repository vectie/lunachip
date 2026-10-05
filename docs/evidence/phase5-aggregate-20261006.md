# Phase 5 aggregate result

Phase 5 passes locally on unchanged commit
`58ed2d80ef890d86489386617e5b9929f4a107f8`. The full native gate passes
832/832 tests, and all nine independent child gates exit zero in the same
aggregate run. This closes the named Phase 5 digital gates; Phase 6 remains
in progress.

## Completed gates

The aggregate runs native validation, synchronizer/handshake/FIFO differential
validation, synchronizer/toggle/FIFO synthesis, and synchronizer/toggle/FIFO
formal validation. Every child publishes a passing receipt. The formal matrices
contain five synchronizer tasks, twelve toggle tasks and fifteen FIFO tasks.

The FIFO matrix includes one bounded safety pass, six cover witnesses and eight
counterexamples on their exact selected assertion labels. All five safety
partitions pass at the parent bound of 128 global steps. The supplemental
completion check passes at 204 steps without broadening the parent claim.
All fourteen FIFO witness/counterexample VCD hashes match their typed results.

The source HEAD, Git status and complete repository-input manifests match
byte-for-byte before and after execution. No standalone receipt is substituted
for a child result. Earlier incomplete attempts remain retained unchanged.

## Retained evidence

The original run is
`/private/tmp/lunachip-phase5-aggregate-20261006.mGNRt3`. Its complete tree is
copied and compared byte-for-byte at
`/Users/kq/Workspace/lunachip/.phase5-aggregate-evidence-20261006`.
The separate retention inventory covers 3,512 files, including native logs,
all child inputs/results, emitted RTL, synthesis models, typed receipts,
formal witnesses and counterexamples.

| Artifact | SHA-256 |
| --- | --- |
| Published aggregate receipt | `61617a96beeae8b3f7f1f3a26090cef1db22f81ef4c5c7ef86b15c597c8e71d4` |
| Original artifact manifest | `f51ce193560821919673ef32be5b4c4a7b79d31c6ea54c6c4d6685491fba2c26` |
| Complete repository-input manifest, start and end | `b4dbe3048c7bc9cc066b71a4e02dff25553772d0718c4a2e773980cd81bcc165` |
| Separate retention inventory | `def31c4b464d709fb7af0408b9bb5def1f8a332a21bb4d9e4fa40c62eb071359` |

Reproduce from a clean checkout with the locked providers available:

```sh
DOCKER_CONTEXT=colima-lunachip-phase3 LUNACHIP_VERILATOR_MOUNT_MODE=volume LUNACHIP_YOSYS_MOUNT_MODE=volume moon run --deny-warn scripts/phase5-gate.mbtx -- /absolute/new-run-root
```

The run uses the locked Verilator 5.050 ARM64 provider and
Yosys 0.68/SBY v0.68/Bitwuzla 0.9.1 AMD64 provider through volume transport.
The validation VM has two CPUs, 8 GiB RAM and 4 GiB scoped guest swap.
No assumptions, bounds, warning policy or tool pins are relaxed.

## Claim boundary

The result supports the named deterministic multi-clock and bounded binary
digital tasks under their recorded reset and environment contracts. It does
not establish analog metastability behavior, MTBF, unilateral-reset safety,
unbounded device correctness, physical RAM mapping, placement, timing closure,
power, FPGA execution or fabricated silicon.

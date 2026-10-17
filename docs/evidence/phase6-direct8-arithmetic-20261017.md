# Qualified arithmetic preparation and command-age induction

The four original age/potential groups now pass jointly with accepted55 on
the pointwise-qualified binary direct8 model. This reduces preparation cost
and closes the age/potential induction checkpoint, not explicit command
latency or aggregate Phase 6. See the
[implementation and isolation plan](../PHASE6_DIRECT8_ARITHMETIC_PREPARATION.md).

Frozen clean source: `3b07994eb06022ea3e303cb8441ec48fd7d42999`.
Canonical original IR:
`12e94f78c7136ada755eed2f35c92af52d77aa75fa2f1398bab19872057ff3ae`.
These results concern that original direct8 identity, not the independently
validated PRX100 word-read-core d2 identity. No PRX100 file, portable production
library or public package API is changed by this experiment.

## Model preparation

Discover all 13 add/sub helpers from original typed IR operation/width pairs.
Match the complete original emitted bodies, then substitute only same-width
modular `a+b`/`a-b` in two opt-in proof profiles. Record original/replacement
body digests and reverse the replacements to restore the old DUT exactly.
All earlier task inputs, production emission, property bodies, observer state,
memory/address connections, public premises and clock/reset equations remain.

Pinned Yosys SAT proves every helper pair for all defined binary inputs,
including all 64 address bits. A sole bit-63 mutation of the add64 result
produces an actual SAT counterexample and expected `-verify` failure. This
qualifies the binary proof substitution, not four-state production equivalence.
The miter SHA-256 is
`779392fc3cf03370279a50aff4e834a324ca0bee512ecbb7c68738a7e0215eb3`;
the helper-report SHA-256 is
`957730b66955a1ef05ae1ff9fa8e1abaea7e5459c7409b926101767aaa5d8d74`.

One sequential baseline/adapted pair prepares the same 59-group selection:

| Preparation | Yosys reported time | Peak memory |
| --- | --- | --- |
| Original ripple helpers | 92.14 s | 343.54 MB |
| Qualified operators | 7.99 s | 159.48 MB |

The approximately 11.5x time difference is one observation, not a stable
benchmark or explanation of earlier timing variability. Unrelated host builds
were observed earlier in the window. The coordinated VM workload and this
task's heavy builds were serialized; the entire Mac was not reserved.
This optimizes proof preparation, not production chip throughput.

Both prepared models retain all 38 memories and 8,960 unknown storage INIT
bits, with every read INIT unknown. Full sorted memory parameter inventories
are byte-identical, SHA-256
`a04b7c2c72c8be717c3c9d5bf7069906ecc3339f407e41ebd7a208a68a1a522b`.
No unknown data is initialized, constrained, cut or replaced. Full UInt13
cursors and UInt64 DMA arithmetic retain their original modular width.

## Preflight and retained setup failure

Targeted native tests pass 4/4. Both fresh preflights pass 82 tests each:
67 native design, six verifier and nine automation tests, plus 26 typed fixture
verifications and 24 comparator-helper audits. Strict native checks, formatting,
interface generation, old input pins and lossless regeneration pass. No public
interface changes result.

The first attempt stops before SAT because the pinned image's Rust coreutils
`chmod` stalls under AMD64 QEMU; a separate `timeout` probe panics. The setup
container is stopped and actual exit 137 retained. Its preserved output volume
is read-only audited, copied, and verified empty at both ends before removing
that exact owned volume. Nothing unique is deleted. The original eight
protected volumes remain unchanged. The failed attempt is sealed separately;
no solver result or receipt is fabricated for it.

The corrected diagnostic reuses the ordinary runner's pinned permission
initializer and single-purpose byte-hash/directory queries. Process timeouts,
all loops, parsing, transport checks and orchestration remain in MoonBit.
The ordinary device runner is unchanged. The existing QEMU-only VM, image
digest, Yosys 0.68, SBY 0.68 and Bitwuzla 0.9.1 remain pinned; no Rosetta,
extra VM, premise, memory initialization or device time-cap extension is used.

## Unbounded results

Both tasks retain k-induction32, the original seven public premises and the
600-second cap. Every support predicate is asserted, not assumed.

| Profile | Selected / actual assertions | Actual status | SBY wall time |
| --- | --- | --- | --- |
| Accepted55 plus bounds/history | 57 / 141 | `PASS 0 458` | 345 s |
| Accepted55 plus all four age/potential groups | 59 / 143 | `PASS 0 568` | 392 s |

The final numbers in the status records are process time, not wall seconds.
Both runners exit 0 and typed result/receipt verification passes.

The first task passes base steps 0–31 at 95 solver seconds; induction succeeds
at 324 seconds and status passes at 326. It establishes original potential
bounds and command-age history with the accepted support. Its 57-group
selection is different from the old full-latency57 selection.

The second task passes base steps 0–31 at 144 solver seconds; induction
succeeds at 353 seconds and status passes at 355. It additionally establishes
original potential-step and age-plus-potential in the complete 59-group
conjunction. Induction remains meaningful work after preparation is reduced;
the old timeout alone diagnosed neither a false predicate nor a missing lemma.

Actual SBY model preparation reports 8.94 seconds/158.79 MB peak for the first
job and 18.35 seconds/159.23 MB peak for the second. These separate device jobs
are not another same-selection preparation benchmark.

| Typed artifact | Bounds/history SHA-256 | Full age/potential SHA-256 |
| --- | --- | --- |
| Result | `6b20d763756bad54aceaf4b0b44c32ae474c791d47d044e4dd5e32c6d750f8b3` | `e5090dfedaa8888c6e1702221ea93d1974782dbca6096e47fdd4bda25c1d0804` |
| Receipt | `90d48f629cead41930c5e92ff6f27862faa8874cd2b26f80357dbe7844d0e59f` | `2e254cdcfdb7d231482e6e1e7a0dafafafc144eb7f84b4b3cb35aa2cedd47514` |

Independent reviews verify exact compiled sources, actual assertion counts,
seven original premises, all original unknown arrays/read INIT, and clean
unchanged private HEAD/status. A retained post-run MoonBit driver independently
recomputes both helper reports/miters and verifies actual positive/negative
SAT logs again; both commands exit 0. No extra solver job is launched.

## Retention and remaining scope

Both diagnostic and device inventories preserve the protected volumes. Owned
diagnostic outputs are copied and byte-hash verified before cleanup. Docker
is empty and the eight protected volumes are exact at explicit window release,
before sealing/documentation. Exactly two distinct device jobs ran: no third
job, unchanged repeat or cap extension. All earlier timeouts remain immutable.

The collector verifies the complete inventories before and after atomic
relocation into the main repository. This is rename, not copy-and-delete.
Caches and copied historical regression archives are not bundled.

- Setup attempt: `artifacts/phase6-direct8-arithmetic-20261017-r1`, 781 listed
  files plus inventory, 31 MiB; inventory SHA-256
  `9debd432e0dc869379a56f0482b00bfc51bf8a6ca0ce38c7bd82559dee282400`.
- Qualified attempt: `artifacts/phase6-direct8-arithmetic-20261017-r2`, 1,181
  listed files plus inventory, 124 MiB; inventory SHA-256
  `3ecb136444ed34792567336698bd64ee484d922d49d4d3025b174bc2079e7840`.

The accepted checkpoint now includes all four original age/potential groups
with accepted55. Neither task selects explicit `d8l_command_latency`. Named
L1666/S898/M99 latency selection, live-entry/dependency/queue progress
composition, useful formal Store reachability, the positive 11,718-edge theorem
and aggregate Phase 6 remain open. These receipts do not certify a different
PRX100 core or a four-state production model.

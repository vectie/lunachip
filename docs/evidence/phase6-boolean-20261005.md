# Dependency comparison helper equivalence on 2026 10 05

The isolated dependency formal adapter now uses native Boolean comparisons
instead of production four-state comparison helper bodies. Pinned pointwise
SAT equivalence passes for all19 current helpers; a negated miter fails its
selected proof. The fresh priority-cover task also completes with a retained
witness and verified typed receipt. Neither result is a dependency safety
proof. Production RTL and canonical IR remain unchanged.

## Measured cause and scope

The preceding priority-cover run reached global step21 after88 solver seconds,
then timed out during witness export. Independent prepared-model inspection
found4252 of4268 DUT `anyseq` cells feeding comparison-helper internals:
3459 from equality and793 from unsigned comparisons. These are explicit and
process-lowered X defaults inside four-state helpers, not dead canonical nodes.
The emitter intentionally requires every canonical node to be reachable.

The adapter changes19 whole helper bodies in deterministic first-use order:
equality widths1,2,3,4,5,7,8,13,16,32,40,64 and unsigned less-than widths
2,4,5,8,13,16,64. It preserves signatures and all387 comparison call sites,
including the reversed operands and inversion used for less-or-equal. It
retains production add/sub helpers and all other source bytes. No hiding
attribute, node pruning, pin constraint, state initializer, fairness, reset
change, property removal, bound extension or warning waiver is introduced.

The sixteen other DUT symbolic defaults, seven top-level reference-array
defaults, real unknown registers and SRAM contents are not simplified.
The48 typed observation references and all public ports remain exact.
Ordinary four-state simulation and production RTL emission are unchanged.

## Independent equivalence check

`scripts/phase6-dependency-boolean-equivalence.mbtx` extracts the exact original
helpers from the archived production source and exact replacements from the
fresh adapter. A combinational miter compares every helper with arbitrary
64-bit operands. Sharing operands does not restrict the input projection for
any width. SAT uses `-enable_undef -set-def-inputs -prove all_equivalent 1
-verify`; operands may take every binary value. There are no value constraints,
reset, memory, state or progress assumptions, and no X-wildcard `-prove-x`.
The exact old X-default paths remain available to the checker.

The locked image runs offline with read-only root, no capabilities,
no-new-privileges, user501:20 and a read-only owned input volume. The ordinary
runner checks image identity and Yosys0.68/SBYv0.68/Bitwuzla0.9.1 versions first.
Actual SAT reports `no model found: SUCCESS!`, exit0. Negating only the combined
miter yields an actual SAT failure, `proof did fail`, exit1. Both logs and
inputs remain retained. The checker records both source digests and the lock
digest; it does not manufacture a sequential formal-result receipt.

Three earlier probe attempts are retained separately: extraction encountered
an unchanged memory-knownness helper, the frontend could not read a seekable
module from piped stdin, and the first function renaming changed only its
declaration. These are probe errors, not equivalence results. The completed
fourth attempt uses owned-volume input and renames both function declaration
and result assignment. Transport resources are removed after each run; host
evidence is preserved.

Native validation passes strict checking with warning73, interface generation,
formatting,55 formal tests,7 exporter tests,31 emitter tests and4 observation
seam tests. New tests cover exact typed helper inventory, unsigned/signed
syntax, helper deduplication, source-byte restoration and extraction drift.
Signed helpers are absent from this production fixture and are not covered by
the actual19-helper SAT result. No newer full-native-matrix result is implied.
All three original public-transport pilot bundles compare byte-identically
after fresh export. The new dependency input passes the unchanged job preflight.

## Reproduction and retention

Export a fresh `phase6-dependency-latest-writer` bundle with the existing CLI.
Create a real empty output directory, then run from the repository root:

```sh
moon run --deny-warn scripts/phase6-dependency-boolean-equivalence.mbtx -- /absolute/dependency-bundle /absolute/empty-output
```

Check `result.txt`, source bindings in `inputs.txt`, exact miter and both actual
logs before running a device task. The equivalence precondition is procedural;
the ordinary job schema and runner do not enforce it automatically. Retain
fresh inputs and outputs rather than overwriting earlier evidence.

Original root: `/private/tmp/lunachip-phase6-boolean-20261005.eg54q2`.
Retention: `/Users/kq/Workspace/lunachip/.phase6-boolean-evidence-20261005`.
Complete directories are retained outside Git, including all incomplete probes.

## Completed priority cover

At checkpoint `58d3869`, the unchanged pinned runner completed
`phase6-dependency-latest-writer-cover-older-terminal-new-intent` with exit0,
SBY PASS and431 elapsed seconds. It selected only
`reachable_older_terminal_with_new_intent`, bound256 global steps /128 DUT
clocks, the same four host/reset assumptions and no fairness. The canonical
result records `RESULT cover-witness`; the existing full typed-artifact
verifier passes task/result/execution/status/version/provenance/output-inventory
and witness-digest binding. All four trace formats completed; the VCD retains
full values through step21 and the normal final step22 clock marker.

Independent trace review confirms real DMA and same-slot publication priority.
Old LoadA/A0 ticket0, caller `0xffffffff`, has shape1x1, base1023 and legal
single-row stride `0x80000000`. Its one-byte read at1023/tag0 accepts before
step15. At pre-step16 a matching response handshakes with remote status1,
not successful data. Steps17/18 expose terminal fault9/ticket0 while both DUT
and independent ghost A0 remain Pending/ticket0, with matching collection.
On that same reservation edge a syntax-valid new A0 intent publishes ticket1;
its zero dimensions will independently reject later with shape fault3.

At steps19/20 both DUT and ghost A0 are Pending/ticket1, not the old terminal's
Failed generation; next-ticket counters are2 and the selected priority cover
predicate is true. The other five writers remain Empty/ticket0, and all six
status/ticket pairs match along the complete witness. The later shape fault
changes only the new ticket1 generation to Failed at step21. The solver's
reached-cover step21 reflects the declared two-step clock/property sampling,
not a simultaneous clock count. No later reset or transport poison occurs.
This is a matching remote-error terminal/new-intent witness, not a successful
reload or the full seven-assertion safety result.

| Measurement at the same selected cover | Prior encoding | Boolean adapter |
|---|---:|---:|
| DUT `$anyseq` | 4268 | 16 |
| Whole-design `$anyinit` | 188 | 188 |
| Whole-design `$ff` | 240 | 240 |
| `$mem_v2` | 10 | 10 |
| Trace variable declarations | 6894 | 2653 |
| Solver time reaching step21 | 88s | 22s |
| Final task result | TIMEOUT, truncated trace | PASS, complete witness,431s |

These are two observed executions, not a repeated performance benchmark or
a hardware-throughput result. The production graph is unchanged. A read-only
snapshot at12:58:55 UTC recorded526376960 bytes current memory and526577664
peak (~502MiB), with all cgroup memory-event counters zero. This snapshot is
not a full-job peak or a comparison at the old deep OOM failure point. The
VM remains2 CPUs /4094447616 bytes. Trace export still dominates: the new
run spent roughly389 seconds after reachability finishing its trace formats.

The exact `priority-output` and outer `priority-run.log` are retained beside
the equivalence evidence; complete copies compare byte-identically.

| Artifact | SHA-256 |
|---|---|
| `dependency/source-set.lcfs` | `90988740da72e391e79837e97a05c49295f5b1b9e7bc441d69d4fcfb67a36e91` |
| `equivalence-r4/equivalence.sv` | `f4668f135892b3728aa73dc3706c20ae19d7812ffc32af52b9b8751ec519f939` |
| `equivalence-r4/equivalence.stdout` | `61669a6d319b6408af468c924f98b0bd1cdd3c97d8e04bbc05f1d120b12e50fb` |
| `equivalence-r4/negated-control.stdout` | `76b2fd4cdbc19fc4cf19f8ed4b23d477eb52e610de61d3c8ad020314a0fe7336` |
| `equivalence-r4/result.txt` | `f619f49321a2e2cf57e1ebdfb21dc44c90ff07b9c5c65354c205e26804cf3fdd` |
| `priority-output/result.lcfr` | `fd73f00d06572087a7ac2942474758262c554365fe947c2be853750ee0ba07d5` |
| `priority-output/receipt.lcfe` | `49afb898c647ba932883c223f87a54ad305328babe631b3f8b270be55abb9eb4` |
| `priority-output/outputs.sha256` | `a3c03890aff73abd0b2dd246bf7f700a45d2f4911eebd19409cbd80f20554141` |
| `engine_0/trace0.vcd` | `b1d0e235f37f2e52e3db844a0b2af2c2e0d77a950db6bfd3e2b1be61db4a7bd4` |
| `priority-run.log` | `a701998cb9fa1a51788a4ff08255eb482639e917e96055d7bcfbf64cadfc2857` |

The helper result proves only pointwise Boolean equivalence for the current
inventory; the cover proves this one reachable priority scenario. Dependency
safety, the four other covers,
FIFO/retirement/lease properties, liveness and the full Phase6 gate remain
independently required. VM settings and tool locks are unchanged.

# Dependency comparison helper equivalence on 2026 10 05

The isolated dependency formal adapter now uses native Boolean comparisons
instead of production four-state comparison helper bodies. Pinned pointwise
SAT equivalence passes for all19 current helpers; a negated miter fails its
selected proof. This permits a fresh device-task measurement, not a device
proof or performance claim. Production RTL and canonical IR remain unchanged.

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

| Artifact | SHA-256 |
|---|---|
| `dependency/source-set.lcfs` | `90988740da72e391e79837e97a05c49295f5b1b9e7bc441d69d4fcfb67a36e91` |
| `equivalence-r4/equivalence.sv` | `f4668f135892b3728aa73dc3706c20ae19d7812ffc32af52b9b8751ec519f939` |
| `equivalence-r4/equivalence.stdout` | `61669a6d319b6408af468c924f98b0bd1cdd3c97d8e04bbc05f1d120b12e50fb` |
| `equivalence-r4/negated-control.stdout` | `76b2fd4cdbc19fc4cf19f8ed4b23d477eb52e610de61d3c8ad020314a0fe7336` |
| `equivalence-r4/result.txt` | `f619f49321a2e2cf57e1ebdfb21dc44c90ff07b9c5c65354c205e26804cf3fdd` |

This result proves only pointwise Boolean equivalence for the current helper
inventory. Dependency safety, a completed priority witness, the other covers,
FIFO/retirement/lease properties, liveness and the full Phase6 gate remain
independently required. VM settings and tool locks are unchanged.

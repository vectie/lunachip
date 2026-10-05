# Dependency trace naming probe on 2026 10 05

The standalone MoonBit probe validates a naming-only projection of the pinned
prepared dependency model: 1,942 DUT `lc_n*` wires receive private names, while
all ports, cells, connectivity, aliases, state, memories and top-level monitor
signals remain unchanged. Four artifact-corruption controls are rejected.
The ordinary runner is not modified. The structural probe itself executes no
solver and claims no witness, replay, performance or safety result. A
[separate execution experiment](phase6-projected-witness-20261005.md) now
completes the projected cover and same-model replay, while older-model replay
fails on a generated witness name. It is not ordinary runner integration.

## Reason and conservative selection

The completed priority cover reached global21 after22 solver seconds, then
spent368s writing its VCD. The completed priority negative also spent388s
writing VCD after its selected failure. These measured export costs motivate
the probe; they are distinct from the broader safety search timeout.

The pinned Yosys naming pass and SMT/VCD exporter provide the proposed mechanism:
[rename](https://raw.githubusercontent.com/YosysHQ/yosys/v0.68/passes/cmds/rename.cc),
[SMT export](https://raw.githubusercontent.com/YosysHQ/yosys/v0.68/backends/smt2/smt2.cc)
and [trace export](https://raw.githubusercontent.com/YosysHQ/yosys/v0.68/backends/smt2/smtbmc.py).
Private combinational names are not queried as ordinary public VCD nets.
This is not an unvalidated SystemVerilog `hide_name` attribute or logic pruning.

After exactly the existing task's preprocessing and property selection, keep
all DUT ports and aliases touching ff, memory and nondeterministic cells.
Rename only remaining `lc_n*` wires, excluding every `unused_bits` wire.
Six otherwise selected wires have92 optimized-away high bits without stable
port/cell/named-net anchors. Their complete names remain public; no guessed
correspondence or comparison waiver is introduced.

## Actual structural validation

The probe reuses the existing typed fixture verifier and locked image/version
check. It runs offline with owned input/output volumes and the existing runtime
isolation policy. Complete commands, preparation script and before/after JSON
are retained. No SBY or solver runs, property assumptions or canonical device
source changes are introduced.

Numeric bits receive a bijective mapping from unchanged cell/port identities
and unchanged nets; constants remain exact. Each selected net must consume
one matching private replacement, preserving alias multiplicity and all
metadata except its name/hide flag. All other nets, cells, cell parameters,
attributes and connections are exact. The top ghost/property module is
unchanged. All84 DUT ports, including48 typed observations, remain unchanged;
all4,325 DUT cells retain identity and connectivity, including172 `$dff`,
ten `$mem_v2` and twenty emitter memory-bounds checks.

The actual checker rejects four separately retained modified models: a changed
cell type, an observation port's direction, a renamed net's private-name flag,
and a connection vector made to alias two previously distinct numeric bits.
These exercise the structural validator, not production fault sensitivity.
Independent review accepts the unchanged model and these controls.

Two initial attempts fail the checker on the unanchored high bits. A third
preserves their names and passes; a fourth adds corruption controls. The fifth
formatted run includes the exact probe source snapshot and passes all checks.
Earlier complete attempts remain separate; none is retrospectively rewritten.
Strict compilation/help, standalone formatting check and repository boundaries
pass. MoonBit module/package dependencies and the last775-test native checkpoint
are unchanged; no additional full matrix run is claimed for this standalone tool.

## Reproduction and retention

Create a real empty output directory, then run from the repository root:

```sh
moon run --deny-warn scripts/phase6-dependency-trace-projection.mbtx -- phase6-dependency-latest-writer-cover-older-terminal-new-intent /absolute/dependency-bundle /absolute/empty-output
```

Complete attempts live under
`/private/tmp/lunachip-phase6-boolean-20261005.eg54q2/trace-projection*` and are
copied byte-identically into
`/Users/kq/Workspace/lunachip/.phase6-boolean-evidence-20261005`.
All fifth-run `outputs.sha256` entries verify; `probe.mbtx` equals committed source.

| Fifth-run artifact | SHA-256 |
|---|---|
| `probe.mbtx` | `97d31b417af6743c411f6ad10e2f4c15b739f78c3c97caef718f8b87cadd64fe` |
| `model/before.json` | `dd23dc932fd6c100f4b3d658a802eca376174f9a35bddf51013c443decff35f3` |
| `model/after.json` | `61e27f6b26f1bc57f90c62ca11e196c1f81c9f89e1a05973e5bb912567234a28` |
| `negative-controls.txt` | `de395ece72130df61a3236c3fcf5ae16260408d6f98251fe1285c06f334a75fa` |
| `outputs.sha256` | `95aeea319f2b0730fcbcf2a6bdcfdd75046ae6c88708d2e239809a8d84afbfa2` |

Before runner integration, reproduce a complete positive priority witness and
selected negative counterexample with the projection, retaining needed
state/observation evidence and validating replay formats and all typed bindings.
Only then measure export cost. The full256-step safety gate and all other
Phase6 obligations remain required. Tool locks and VM resources are unchanged.

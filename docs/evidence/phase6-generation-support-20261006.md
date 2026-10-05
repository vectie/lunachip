# Full-harness generation-support experiment

The supporting BMC experiment timed out after 601 seconds at clean commit
`84d61eb7538c2f4c6b80826f80b42497ef4a39d4`. It last entered assumption checking
for global step 62 and assertion checking for step 61 of the declared 256.
There is no terminal solver status, counterexample, witness or typed proof
receipt. This is an unsuccessful gate attempt, not a bounded PASS.

## Exact experiment

`phase6-dependency-generation-support` reuses the production dependency DUT,
independent ghost, checked artifact registry and ordinary runner. It appends
`generation_all_boundary_matches_reference` as p16 after the unchanged sixteen
property definitions. This compares all eighteen raw next/head, writer and
snapshot fields at the original rising-pre-edge boundary, guarded only by
reset. It is an assertion, not an assumption, dispatch-only check or cut.

The task retains all seven original monitor assertions, twenty DUT bounds
assertions, four host assumptions, depth 256, timeout 600, multiclock and
the locked smtbmc/Bitwuzla engine. No production IR, RTL, memory policy,
initial-state restriction, tool lock, VM allocation or runner is changed.
Five cover definitions remain present, but this experiment has one safety
task and no cover tasks. The ordinary cover gate remains independently required.

Fresh control exports at `4c7a3eb` and current exports agree byte-for-byte
across all 46 artifacts in the four ordinary dependency bundles: nineteen
LatestWriter artifacts and nine for each negative. The support bundle's IR,
production SV and formal-DUT SV also agree with ordinary LatestWriter. Native
tests reconstruct the entire old harness by removing only the new predicate
and p16 assertion, and compare the original sixteen property objects exactly.

## Validation and actual preparation

Interface generation, formatting, warning-strict native checking with warning73,
77 formal-package tests, eight exporter tests and all 798 native tests pass.
The default CLI reports `FluxTile control cycle=4 value=4`; dependency and
source-size boundaries pass. Typed regeneration verifies the new bundle.
The only public interface addition is one explicit fixture enum case; no new
public function, schema, runner or export flag is introduced.

Independent audit of the actual prepared model observes 28 assertions and four
assumptions, 188 anyinit, 34 anyseq, 304 ff and ten memories. The ordinary
model has 27 assertions and 303 ff; the other totals agree. The DUT separately
retains twenty assertions, 172 anyinit, sixteen anyseq, 226 ff and ten memories.
The extra ff is the new property's one-bit predicate sampler using the same
rising-edge enable as existing monitors. P16 is an actual `$assert`, never
an assumption. All original assumption and memory-bounds labels remain.

The full formal-DUT source is byte-identical. Prepared DUT module bytes are
not: backend allocated numeric name suffixes change. The independent review
finds only consistent bijective backend-name renaming across complete DUT
RTLIL and SMT sections, with no other-byte differences. This is a scoped
preparation comparison, not SMT roundtrip, projected replay, four-state
equivalence or a new sequential proof. The early preparation copy is
byte-identical to every file in the final retained model directory.

## Actual execution and interpretation

The original runner executes:

```sh
LUNACHIP_YOSYS_MOUNT_MODE=volume sh scripts/phase4-yosys-run.sh oci formal \
  phase6-dependency-generation-support-bmc BUNDLE EMPTY_OUTPUT
```

Observed versions are Yosys 0.68 at `38e001a6f`, SBY v0.68 and Bitwuzla 0.9.1.
SBY returns `TIMEOUT`/exit8 after 601 seconds; its solver returns no status or
trace. The wrapper records that nonzero child exit rather than converting it
to a pass. Source HEAD and clean status are identical before and after.

The prior ordinary attempt also timed out after 601 seconds, last checking
step69. This experiment does not establish a full-gate speedup. These two
attempts are not a statistical performance comparison, and neither checked
prefix substitutes for depth256. The fixture is retained as an explicit
diagnostic assertion experiment, outside the standard bundle matrix. It adds
no production device or simulator runtime work.

The next semantic step is a small sequential clock/reset bridge for the
already-proved exact eighteen-field transfer: retain arbitrary pre-reset
state, initial joint reset, symbolic later synchronous resets, enabled
transfer/hold, the global toggle clock and unchanged locked preparation.
Validate the relation at original rising-pre-edge boundaries and hold between
edges. Only then consider a separately justified equality-elimination
experiment; do not assume owner, Issue authorization or internal readiness.
Ownership, saved authorization, FIFO, retirement, leases, ticket uniqueness,
liveness and the ordinary full gate remain unfinished.

## Retention

Complete exports, native logs, executed command, clean source records,
preparation models, engine logs and independent review are retained under
`/private/tmp/lunachip-generation-support-20261006.WCZIPw/`, with byte-identical
copies under
`/Users/kq/Workspace/lunachip/.phase6-generation-support-evidence-20261006/`.
The hash inventory excludes only script build/dependency caches.
All 204 inventoried files verify in both locations.

| Artifact | SHA-256 |
|---|---|
| Complete retained inventory | `2a8fa4adcbad0259b716d7383f227297d7461d64d4c753f959eedec958115826` |
| Harness | `d3e359404533d5bf78dd7b46f084158683236e22a59e5c114184821d8aa145f9` |
| Source set | `92c8bcc46b2952f1825da1da02548e56c95230ba2f9f564685cc80b2f3223ec1` |
| Executed SBY configuration | `9f84c8aeabba599860bf9c21698352017c9b55cb7dda8f1de6f25bbc80a05d98` |
| Actual SMT model | `b75fb7d0e4b88bce40e4cf3c5698251531d47f4f1fcdbec837dd1a9725efd4f4` |
| Independent preparation audit | `a35ae59a3316b55522e62cb632cdad58106828996e5ae9f4b06201609fe076d4` |

# Store bounded safety validation

Continue from the sealed full Store safety conjunction at `40521bd`. Run a
fresh 256-global-step bounded check of all nineteen original safety assertions
and ninety checked support assertions over the unchanged binary2x2/K2/host1024/q3
projection. This is 128 DUT clocks, not 256 DUT rising edges.

The new task uses exactly the accepted full109 source bytes. Only the task name
and solver policy change from prove/depth20 to bmc/depth256; timeout600,
Bitwuzla, strict preparation warnings and multiclock lowering remain pinned.
The sole premise is the original startup reset. Later reset, host inputs,
unknown SRAM/read initialization and four arbitrary32-bit producers remain free.
All support relations remain assertions, never internal assumptions.

Keep the existing private collector and runner, one native cache outside
evidence and the dedicated QEMU validation VM without Rosetta. Commit the plan,
native-qualified inputs, actual engine outcome and final ledger separately.
Freeze tracked source during execution, retain complete unsuccessful outcomes
and audit copied inputs, prepared models and final solver status before accepting
a bounded result. Historical timeouts and sealed archives remain unchanged.

This task addresses the outstanding Store bounded-safety obligation only.
Overlap witnesses, selected sensitivity, packet/fetched composition, explicit
fairness8x8 and the remaining Phase6 matrix still require their own evidence.
The existing unbounded positive result is not reclassified as this bounded run.

## Native qualified inputs

Three focused native collector tests pass, including the unchanged original
bridge digest, all109 assertion labels, one startup premise, no cover and exact
BMC256 policy. Strict native warning checks, interface generation, formatting
and the existing runner test pass. The bounded collector emits the exact sealed
full source digest
`5d95a3e4f4760ef9256c5b31776292cb717e2abe63f957150d27530e1e006180`.
No hardware or public interface changes accompany this task.

The earlier guided archive also contains accepted original overlap and selected
payload-sensitivity results. Its complete1,076-file checksum inventory verifies
with digest
`1859684cffad802526d2f2f4f0c63ad64da45a16dcfeae7a36143ddcd10bc22b`;
its qualification record verifies at
`1441f3949851524fcc2cc6511ca2bfbdfe2f411d9b0e363286e7ad642a3569ff`.
Review source identity and causal traces before reconciling the latest ledger.
These are input-guided existential/sensitivity evidence, not universal safety.

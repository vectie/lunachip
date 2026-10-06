# Exact queue-control local induction checkpoint

The six local queue-control conclusions pass actual base-case and k-induction
execution on clean implementation commit
`47736b118306d93236bea758768a85344eed936a`. The comparison-only negative
fails exactly `lc_queue_population` at global step 9, with a complete genuine
PRE reservation counterexample. These are supporting binary control results,
not a whole-device result, ordinary formal receipt, or terminal-ownership proof.

## Exact source and claim

The [control projection](../PHASE6_QUEUE_CONTROL_LEMMA.md) retains sixteen
original production registers, totaling 37 bits, with their original unknown
initial state, synchronous reset, enables, rising clock domain and next-state
equations. Eight explicitly listed free boundaries overapproximate external
and terminal timing. Admission, FIFO transfers, head reservation, retirement,
allocation and acknowledgment remain derived from the copied production cone.
There is no memory or additional hidden controller state in this projection.

One independent four-bit history counter measures actual public admission
minus retirement. It resets to zero and changes only on those public events;
it is never repaired from internal population. Illegal arithmetic holds rather
than wraps and is an asserted failure, not an assumed restriction. The only
source premise is the original first sampled joint reset. Later reset and all
eight boundaries remain symbolic, with no fairness or internal readiness,
event, relation or progress assumption.

The six assertions establish:

- lane occupancy/response equality, response iff head state one, head-entry
  range, and the exact contiguous live retirement interval and pointers;
- a widened six-bit physical population equal to independent public history;
- bounded public history and valid current admission/retirement arithmetic;
- zero state following a sampled reset;
- the raw invariant globally after initial reset, including later reset PRE;
- nonrising hold of exactly 37 DUT plus four history bits, excluding free inputs.

The twelve modulo-three ring cases specify both live entries and write pointer.
Population equality alone is not substituted for this structural relation.
Arbitrary terminal cuts can retire a reserved entry while dispatch still stalls;
there is deliberately no head-state-three-implies-live-entry claim.

## Clean native and compatibility checks

Frozen checkout:
`/private/tmp/lunachip-queue-control-proof-native-20261006.PNmpHV`.
Interface generation, formatting, strict native checking with warning 73,
targeted formal/fixture-CLI tests (125/125), and native exporter build all
exit zero. Every retained command records unchanged HEAD and empty source
status before and after. The complete native module matrix was not rerun.

Fresh exports compare 172 prior artifacts byte-for-byte and by SHA-256:
153 ordinary artifacts across fifteen directories, thirteen generation inputs
and six compute inputs. This includes exact comparisons for both earlier
packet-provenance bundles, not just their inventories. New queue-control
inputs have a separate exact six-file inventory and source hashes. The
compatibility inventory hash is
`9dcd2534bcacf1606417753f7a6ad3c2283b41c188a94ce4aeb8ff92ebcf3104`.

The exact exported production and Boolean copies also pass the unchanged
helper-equivalence script: all four scalar comparison helpers agree for
defined binary inputs, and the negated miter fails its selected proof.
This does not establish four-state equivalence or sequential device equivalence.

## Actual solver execution

Both jobs use the existing pinned AMD64 Yosys image and Bitwuzla engine through
the existing volume transport. They execute serially with network disabled,
read-only container filesystem, dropped capabilities, numeric host UID/GID,
`multiclock on`, depth 12 and timeout 600. This is a purpose-specific external
support experiment, not a new runner/profile/receipt framework. Original
full-device horizons and timeouts are unchanged.

The positive `prove` job passes base-case assertions at steps 0 through 11 and
temporal induction after attempts 12 through 9. Its actual SBY elapsed clock
time is two seconds. Both engine statuses are explicitly `pass`; no positive
trace is produced. This is an unbounded local k-induction result, not merely a
depth-12 BMC pass and not a measured speedup over the larger full-device model.

The negative `bmc` job keeps all six assertions and all raw state, ghost updates
and assumptions. Exactly one checked-population expression changes to XOR bit
zero on a genuine current-PRE nonreset reservation with the raw invariant
already satisfied. The sole assertion failure is `lc_queue_population` at
global step 9; SBY elapsed clock time is four seconds. Its expected-failure
exit is zero, and the VCD, Verilog testbench, SMT constraints and Yosys witness
are all retained. This demonstrates reserve-decision sensitivity, not a
post-reservation committed transfer.

Independent trace review identifies causal PRE step 8: reset zero, established
history one, head state two, empty FIFO/ring, public outstanding one, raw
population one, actual reservation and entry-zero allocation asserted, no
admission/retirement/acknowledgment. Every raw structural/population check
holds; only checked population becomes zero. The prepared edge assertion
reports its failure at global step 9. Initial arbitrary invalid state is visible
before first reset; the counterexample does not begin from assumed valid state.

The trace collector uses the preceding low-clock PRE sample, not the changed
post-edge values. Synthetic diagnostics accept a valid PRE witness and reject
POST-only reserve, missing required roles and an unknown causal comparison bit.
The initially incorrect unknown-bit diagnostic targeted startup because
`String::replace` changes only the first occurrence; its fixture was corrected
to inject the unknown directly at reservation PRE before accepted execution.
The production collector and solver settings did not change for that repair.

Negative VCD SHA-256:
`e57a2ccfeaae2e6b111e04db380469b66eaf5791c55db490de1cf704c8b4f1c1`.

Independent prepared-model review confirms six exact named assertions and
only `lc_initial_joint_reset` in both jobs. Each hierarchy has 18 `$anyinit`,
30 `$ff`, eight `$anyseq`, no memories and no remaining processes. The positive
has 441 cells and negative 447; only comparison logic differs. Sixteen DUT
arbitrary-Q samplers correspond exactly to the sixteen retained registers;
zero-initialized NEXT-data samplers do not initialize those Q values. The two
wrapper arbitrary cells are public history (four bits) and previous pair
(41 bits). Common rising-edge and PRE predicate samplers, original reset and
enable equations, and flag-guarded establishment/hold match the exported source.
No prepared relation, event or readiness premise was added. Input copies,
concatenations, mutation normalization, pins and all 133 proof-output digests
were independently verified; trace and compatibility reviews are separate.

## Remaining obligations

This local theorem has not been composed into the unchanged whole device.
Original structural queue, retirement-record and packet-provenance safety
timeouts retain their original status. FIFO storage order, packet payloads,
engine/ticket ownership, whole-Store leases, DMA/address and nested-memory
safety, explicit-fairness completion and the 8×8 product gate remain required.
No FPGA, timing, GDS, fabrication or silicon-performance result follows.

The next implementation-driven step is to carry this relation as an asserted
conclusion over actual whole-device queue state, using the existing independent
public history and existing observation bindings. It must not be inserted as
an assumption or treated as a cached composition proof. All old conclusions,
host premises, nested memory assertions and task settings remain required.

## Retention and reproduction

Original support root:
`/private/tmp/lunachip-queue-control-proof-20261006.Jh7fGS`.
It retains the six exact inputs, compatibility exports/comparisons, clean
command logs, helper miter sources/results, fixed external driver, tool lock,
both actual SBY jobs, prepared models, engine logs/statuses and counterexample
formats. Independent source, prepared-model and trace reviews find no blockers.
Final sealed inventory and retained-copy binding are recorded below.

Sealed inventory: 587 files, SHA-256
`d1dc8d5a1145ee720b165bc492f19858ea1930870f9ba5bf3b653bfd79f045ea`.
Retained copy: `.phase6-queue-control-proof-evidence-20261006` in this repository.
Every listed digest verifies in both original and retained roots, and their
complete directory contents compare equal. Build caches are outside the
inventory. Neither root may be modified by subsequent experiments.

Regenerate inputs from the clean implementation commit with:

~~~sh
moon run --target native cmd/phase6-formal-fixtures -- queue-control NEW_DIRECTORY
~~~

The CLI only exports inputs and refuses an existing output directory. Retained
external scripts and command JSON record the actual support execution; do not
execute a driver inside a sealed evidence root or overwrite its outputs.

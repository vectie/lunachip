# Direct8 explicit fairness completion validation

Validate the existing registered direct8 completion scope without changing its
deadline, premises or production model. The device is the ordinary direct
queued8x8/K16/host4096/q3 two-slot design. This is not fetched-ring publication
liveness, and the accepted fetched164-property safety theorem is unchanged.

## Fairness and completion contract

The existing public contract permits one initial synchronous joint-reset edge
and no later reset; a stalled producer holds all256 descriptor bits. Each
accepted memory request receives one matching successful response, with its
full tag and held response payload; unsolicited/duplicate responses are excluded.
Request-ready and retirement-ready each occur within two offer opportunities.
Response availability occurs at either of the first two edges after request
acceptance and remains offered until accepted. This constrains host availability,
not DUT response readiness, dependency readiness, lease release or core progress.

An admission-selected ordinal watch counts older admitted/unretired packets,
including an older retirement on its admission edge. Duplicate caller IDs must
not retire the wrong watch. The source-derived candidate deadline remains11718
DUT rising edges, inclusive, from the existing conservative q3 service bound.
The original23552-global-step horizon contains the complete deadline tail for
a watch admitted in the first32 post-reset edges. An active watch never stops
checking merely because the search horizon ends.

## Implementation and evidence sequence

1. Preserve the registered eventual, useful-Store and shortened-deadline bundles.
   Audit original SRAM/read unknowns and all address widths, public-only binding,
   seven named premises and same-edge age/ordinal conventions.
2. Add an independent native mirror of the public host/ordinal monitor. Exercise
   actual8x8/K16 legal traffic under R2/H2/C2 delays, both slots, repeated caller
   IDs, nonzero older work, response offers independent of DUT ready, and high
   address rejection. Preserve original unknown memory and reset behavior.
3. Export on a clean frozen snapshot and invoke the existing pinned typed formal
   runner for the exact deadline-negative task. Qualify a genuine canonical
   LoadA admission and age-one failure of its sole selected deadline assertion.
   Do not treat a tool failure or incomplete trace as a valid negative control.
4. Retain actual source/tool/results and review the prepared model and complete
   trace before claiming monitor sensitivity. Positive completion, terminal/
   retirement/useful-Store covers and supporting progress checks still need
   their own actual results; native latency is not a universal deadline proof.

No formal result or qualified11718-edge deadline is claimed at this planning
checkpoint. VM tools run only in a separately coordinated window, after the
current PRX100 owner releases the VM. Protected volumes and QEMU configuration
remain unchanged. No new solver/receipt framework or production debug port.

## Native public monitor checkpoint

Eleven focused tests pass, including the five existing direct8 bundle tests,
two registry tests and four new native checks. The original8x8/K16 device runs
the four repeated-ID73 commands on both slots under R2/H2/C2 delays, with256
byte reads and64 word writes per pipeline. The watch checks ordinal retirement
of LoadA and Store, not just caller ID equality. The high-address case uses
base `0xffffffff` and retires the expected8/4/5 faults without issuing a bus
transaction. All38 arrays initially retain8960 unknown storage bits and unknown
read results; a separate real reset after each native trajectory preserves
every cell and read result, including known masks. Later reset is outside the
completion premise, not silently allowed by its native watch.

Monitor tests distinguish a fair response offer from a stuck DUT, reject wrong
high tag bits, enforce held response/request payloads, count older duplicate-ID
retirements correctly and allow ACK at the exact inclusive deadline. Strict
native checking, formatting and interface generation pass; no public interface
or original completion bundle implementation changes. A draft native check
expected read mask0; the original loader equation specifies mask1 and the test
now checks that exact value. This correction does not modify the device.

These finite native trajectories validate the monitor and exercise the proposed
bound; they do not qualify the universal11718-edge formal deadline.

The MoonBit orchestration exports all three registered bundles and verifies
their five typed tasks through the existing phase-neutral CLI. It preserves
the full23552-step bound and600-second limit, and invokes the existing pinned
OCI runner for the negative rather than creating another solver or receipt
path. A separate review checks source identity, actual assumptions and remaining
unknown memory in the prepared cone, then checks the complete counterexample
for a real canonical LoadA admission and an active age-one/no-ordinal-ACK
deadline failure. Orchestration and top-scope VCD parser unit tests pass.

The first frozen preflight on `0d8b9b5` passes13 focused tests and verifies all
three eventual tasks, then stops at the reused fetched audit's final count:
direct8 emits19 comparator helpers, not the fetched20. Every emitted helper
body had already matched the retained qualified SAT miter. The repair adds an
explicit `helpers-direct8` entry expecting19 while preserving the original
fetched default20, all miter/hash checks and every complete function-body check.
The direct8 nineteen-body audit, original fetched twenty-body audit and audit
unit test pass. No DUT, premise, address, memory or task-horizon change.

No VM job runs for that failed preflight. Its source/logs are sealed separately
in `artifacts/phase6-direct8-fairness-20261016-r1`, inventory SHA256
`012bb692823bab7c258e967819bc6257d1f158a66b68239761aee6cc8710c79e`,
verified before and after relocation. A fresh frozen preflight is required for
the changed adapter before consuming the confirmed one-job VM window.

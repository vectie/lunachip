# Memory mapped SMT encoding for the fetched Store cover

The full fetched 1×1/K2, host1024, ring4, queue2 useful Store cover remains
open. The prior input-guided array encoding ended in a kernel-confirmed solver
OOM at query832; its separate later-window run timed out before query839.
Both archives remain immutable. This experiment changes only the SMT memory
encoding of the later-window task, not the hardware or host contract.

## Encoding and semantic boundary

Use the pinned `smtbmc --nomem bitwuzla` flow. SBY maps the ten small memories
with `memory_map -formal`, then runs
`formalff -setundef -clk2ff -ff2anyinit` before SMT export. Keep the original
DUT, harness, eight host premises, nonconstant useful cover, input guidance,
clock/reset equations and full initialized transition prefix. Bound1024,
query skip839, timeout600 and the QEMU-only 4CPU/8GiB validation VM are unchanged.
No initial state, output, memory content or cover predicate may be assumed.

The actual memories contain640 physical storage bits: four two-word INT8
banks, two one-word INT32 C banks and four two-word 64-bit descriptor lanes.
All original memory and read initialization is unknown. Audit the generated
formal state rather than interpreting unknowns as zero. Preserve held reads,
clock sampling, simultaneous writes, reset behavior and original address
guards, including the unused second address of the one-word C banks.

## Implementation and qualification

Three agents separately implement the explicit runner variant, review
initialization/address mapping, and review input guidance/full witness
qualification. Root owns pinned tool execution and commits.

1. Add `prepare-nomem` without changing the existing array-encoding paths.
   Validate the exact configuration change and reject any source drift.
2. Inspect pinned mapping semantics and the actual generated model. Retain
   all original source identities, properties and state/read bindings; any
   necessary focused semantic probe must be separately identified.
3. Commit the runner before one frozen-source cover attempt. Preserve the
   actual status and model even for timeout or engine error. Do not enlarge
   resources or shorten the prefix in response to a failed run.
4. If a witness returns, independently check the complete initialized prefix,
   every guided input and known native output bit, all132 read accepts/ACKs,
   the four-byte Store at768 carrying−29, its owner ACK and four ordered
   repeated-ID success retirements with progress2,2,0,4. Seal unique evidence
   without compiler caches and commit the qualified result.

A valid witness establishes only the original existential useful Store cover.
Full fetched symbolic safety, explicit-fairness8×8 and the remaining Phase6
matrix/aggregate require their own results. A different encoding is not by
itself a memory-saving or equivalence claim.

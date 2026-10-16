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

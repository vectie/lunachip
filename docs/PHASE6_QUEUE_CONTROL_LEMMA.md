# Exact queue control transition lemma

The next supporting proof isolates the existing direct 1x1/K2/host1024/q3
queue's control transitions. Its purpose is to establish the inductive state
relations missing from the timed-out structural search, without rebuilding the
device or adding internal progress assumptions. The original bounded queue,
retirement-record, packet-provenance and full 8x8 obligations remain required.

## Exact production projection

Discover state through the existing typed 115-role observation seam. Copy
the original register specifications and combinational next-state cones into
one private sequential module using the existing generation remapping and
closure helpers. Retain widths, initial unknown state, synchronous reset,
enable, edge, next expressions and old-state commit ordering. Metadata capture
and extraction must not change the ordinary device IR, RTL, ABI or existing
formal bundles. Unexpected graph leaves stop discovery instead of becoming
guessed inputs.

The intended state is sixteen production registers totaling 37 bits: four
UInt2 FIFO occupancies, four Bits1 response-valid registers, UInt2 head state,
UInt5 saved head entry, three UInt5 retirement pointers/occupancy, and three
Bits1 entry-valid registers. Resolve their exact types and reset controls from
production nodes. Preserve the derived public admission,
FIFO pop/response/capture, head reservation, public retirement, allocation and
acknowledgment equations; none may become independently free inputs.

For this control-only abstraction, descriptor-valid and completion-ready are
public inputs. Poison, current entry-terminal bits and dispatch finish may be
explicitly free boundaries, provided their original reset and head-state masks
remain in the cone. In particular, free finish affects head transitions only
in Dispatch state three, and free terminal bits still pass through the actual
oldest-entry valid/terminal selection before retirement. An exported raw finish
cut must not be mistaken for an already state-masked finish observation.
Such inputs overapproximate when work may be admitted,
finished or retired; they do not establish terminal identity, fault correctness
or engine ownership. List every cut by role, original node and type. No fairness,
payload agreement, internal readiness or progress premise is introduced.
Arbitrary terminal bits can permit retirement before genuine dispatch finishes;
this projection therefore cannot prove that a reserved head entry remains live.

## Inductive relations

Reset establishes equal zero lane occupancies and response-valid state, an
empty head, zero retirement pointers/occupancy and invalid entries. Subsequent
steps must preserve lane equality, bounded occupancy, the response/capture
gap, and packet population measured by public admission minus retirement.

The retirement invariant must describe the contiguous live interval, not merely
its population. With successor modulo three and read pointer r:

| Occupancy | Live entries | Write pointer |
|---|---|---|
| 0 | none | r |
| 1 | r | successor(r) |
| 2 | r and successor(r) | successor(successor(r)) |
| 3 | all three | r |

Both pointers are in range. Allocation selects a free entry and acknowledgment
selects the oldest live terminal entry. For example, occupancy one, read pointer
zero, write pointer two and only entry zero valid satisfy a population-only
relation, but allocating entry two leaves the next write pointer on the live
entry zero. This unreachable free state demonstrates why population equality
alone is not inductive.

A local step proof may use its explicitly declared current inductive relation
as the induction hypothesis. Reset establishment and preservation must both
pass before it supports a sequential bridge. The whole-device task must not
assume the local relation or an internal transfer predicate. A successful local
proof is supporting evidence, not a replacement for its composition into the
unchanged device gate.

## Implementation and validation order

First implement exact discovery and sequential extraction, with native tests
for deterministic mapping, copied controls, reset, simultaneous full pop/refill,
reservation/retirement wrap, held retirement and later reset. Independently
review every boundary and show ordinary hardware and older bundles unchanged.
This checkpoint validates extraction and selected transitions, not induction.

Then reuse the established local reset/step and clock/reset bridge approach.
Select explicit invariants, retain a sensitivity counterexample and execute
through the pinned toolchain. Record the actual result and scope without
changing original assertion inventories, public assumptions, bounds, timeouts
or unfinished statuses. Tractability is unmeasured until that execution.

Engine-to-live-entry ownership needs a larger relation retaining all three
engine FSMs and tickets, live ticket allocation order and collectors. FIFO data
order needs storage provenance; DMA safety and whole-Store leases need their
own composition. The control-only projection does not establish any of them.

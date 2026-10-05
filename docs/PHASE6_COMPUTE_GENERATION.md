# Joint generation and saved compute identity

This follows the verified [compute extraction checkpoint](evidence/phase6-compute-identity-20261006.md).
Its purpose is to remove the free generation-state boundary before proving
saved authorization across Issue. The target is a local sequential relation,
not a replacement full-device gate.

## Exact production slice

Retain all eighteen original generation registers (336 bits) and nine
original compute registers (80 bits): 27 registers and 416 bits total. Keep
one original clock domain, arbitrary pre-reset state, exact next expressions,
synchronous reset, enable and initial specifications. Copy nodes in original
order using one complete original-to-local mapping.

Recompute the closure from all register next/reset/enable expressions and
actual decoder/admission/Issue/terminal observations. Do not simply union the
old cut lists. Any original node derived by either retained cone, or retained
as a register root, must not remain a free boundary input. In particular,
compute terminal validity comes from the actual Done state, and terminal
ticket/fault come from the saved ticket/fault registers. The seventeen
generation fields used by compute admission must resolve to actual state.

Expected free boundaries are eighteen nodes / 340 bits, plus clock: nineteen
input ports / 341 bits. These are reset and raw poison; four raw head lanes;
head state and reservation; raw load terminal validity/ticket/fault; load/store
conflicts; compute preflight and inner ready; and raw core completion validity/
ticket/fault. No acceptance, authorization, dependency-ready or owner premise
is introduced. Conflict, preflight, load/core completion and raw queue cuts
remain a declared local environment, not proved full-device subsystem behavior.

## Independent reference and intended relation

Reuse the existing generation reference (336 bits) and exact existing compute
owner/saved-authorization reference (108 bits). Total live reference state is
444 bits. Factor only the existing source fragments; preserve full ghost
export bytes, declaration/reset initialization and interleaved load/store
updates. Do not add a mirror FSM, new fault model or monitor family.

The intended inductive relation asserts the original generation equality,
saved ticket/ABC/MNK equality, compute owned iff the actual FSM is non-Idle,
and saved authorization iff the actual FSM is Issue. Actual acceptance must
establish legality through independent raw decoding, priority and generation
reference state; legality must never be an assumption. Preflight failure may
own an accepted command without authorizing inner issue. Inner handshake and
outer terminal clear authorization with the original priority, while outer
accept captures the pre-edge head ticket and raw shape.

## Validation and proof sequence

First test exact specifications, deterministic extraction, original IR
preservation, no derived-cut shadows and inventory counts. Drive reset,
genuine local generation reservations and load terminal collection, then Mat
reservation and derived acceptance. Hold Issue while later raw head and real
generation state change; check all saved identity fields, inner handshake,
terminal collection and reset interruption. Label all local boundary stimuli;
full-device regressions remain separate.

Next compare all existing generation and ordinary fixture artifacts, run the
native phase gate and commit the tested source. Only then expose purpose-built
proof inputs and run the pinned sequential preparation with first joint reset,
later symbolic reset, no relation assumptions and actual induction status.
An inner-identity comparison control must fail on an actual handshake following
legal acceptance, not on arbitrary startup state. Preserve exact preparation,
logs and counterexample evidence. No formal claim follows from construction
or native tests alone; full ownership/core/FIFO/retirement composition remains
unfinished.

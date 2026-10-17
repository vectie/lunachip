# Direct8 pending read payload and client phase ownership

The accepted 51-conclusion ACK/credit proof leaves `d8l_client_phase` open
in the original 52-conclusion target. The ownership-only run passes base
0–31 but times out before induction. The original Store Request-valid equation
requires a pending response, matching Store ID and good read status. These
equations suggest additional induction support; the timeout supplies no
counterexample or diagnosis of a missing invariant.

## Original metadata and response equations

Discover the original response ID and status registers through the Store
request producer, not node ordinals or new input shadows. Require the ID latch
to capture the held full UInt32 Store ID on the real indexed read acceptance.
Require the status latch to capture the selected original C-slot status on
that same event. Decode the original valid/dimension metadata and preserve
the actual full-width cursor-to-index equations, including their checked
UInt13 coordinates. No SRAM word value is sampled by these metadata checks.

Jointly assert three new support groups under the original seven public
premises:

- An active Store retains valid selected C-slot metadata with rows/columns
  equal to its held full-width transfer shape.
- A pending read's original response ID equals the held Store ID.
- An accepted indexed read has good selected status and a pending response
  retains good latched status.

These are conclusions on original state, not assumptions of readiness, slot
validity, initialized data or a successful result. They must account for both
slots and prevent another compute from invalidating/changing the active
Store's selected C metadata. The accepted pending-slot and lease conclusions
remain jointly asserted rather than imported as premises. Existing assertions
and all older task identities remain unchanged.

## Qualification order

First qualify an additive payload component selecting the prior accepted 48
plus the three support groups (51 selected, 135 actual assertions). Then
qualify the original joint 52 with those three support groups (55 selected,
139 actual), including the unchanged `d8l_client_phase` and already accepted
ACK/credit conclusions. The latter remain jointly asserted, never assumed.
This retains their transport credit in the induction hypothesis as well as
qualifying ownership on the original model. The two tasks are independent;
run the joint task even if the smaller selection times out. A joint pass
qualifies all included groups without making the smaller task a permanent
extra gate or fabricating a receipt for any earlier timed-out task.

Pin the accepted 51 and earlier 48/49/52/57 inputs. Check exact selected names,
lossless regeneration, canonical IR/public-harness/name identity and restoration
of the earlier DUT by removing only added metadata aliases/support and changing
the assertion export. Exercise real competing two-slot pipelines, held reads,
preflight rejection, reset without erasure and metadata/ID/status mutations.
Native tests are not formal reachability or proof results.

Use the existing clean detached snapshot and one active cache. Respect the
peer's native/Docker reservation and freeze shared sources through its native
checkpoint. Then reserve at most two sequential k-induction32 jobs at the
unchanged 600-second cap in an isolated window. Preserve all 38 memories,
8,960 unknown initial storage bits, unknown read INIT, full UInt64 DMA address
arithmetic and complete payloads. Retain actual outcomes, independently review
the original prepared model and verify typed bindings before acceptance.
Command-age/potential, L1666/S898/M99, live-entry/dependency/queue rank and the
11,718-edge retirement theorem remain separate obligations.

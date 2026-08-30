# Asynchronous-FIFO formal evidence

The Phase 5 asynchronous-FIFO formal family proves bounded, two-state digital
properties of the public LunaWire `asynchronous_fifo` constructor and its
production SystemVerilog output. It reuses the phase-neutral formal artifact
registry and the unchanged pinned Phase 4 Yosys, SymbiYosys, and Bitwuzla
runner, lock, schemas, verifier, and collector.

## Fixed production fixture

Every fixture uses the same depth-4, 8-bit scalar, two-pointer-stage design.
The source and destination are sparse domains 0 and 2. Both active-high
synchronous resets start asserted; traffic is excluded until each domain has
sampled reset and two post-reset edges. Requested clocks use legal one-step
pulses, at most three idle scheduling intervals, and atomic global-pre-state
semantics for coincident edges. Source valid/data must hold until acceptance.
Conditional completion also assumes destination ready at least once per three
destination edges.

The bounded watched-token limit is 80 scheduling intervals. This covers four
items already ahead of the selected token, both pointer pipelines, bounded
clock gaps, and eventual ready. It is not unconditional liveness.

## Named evidence

Seven assumptions bind source/destination clock legality and fairness,
coordinated reset initialization, source protocol hold, and eventual ready.
The twenty-two assertions are:

- `source_transfer_guard_exact` and `destination_transfer_guard_exact`;
- `write_binary_pointer_hold_or_increment` and
  `read_binary_pointer_hold_or_increment`;
- `write_gray_equation_exact` and `read_gray_equation_exact`;
- `write_gray_hold_or_one_bit_transition` and
  `read_gray_hold_or_one_bit_transition`;
- `read_gray_source_pipeline_exact` and
  `write_gray_destination_pipeline_exact`;
- `full_equation_exact` and `nonempty_equation_exact`;
- `write_address_selection_exact` and `read_address_selection_exact`;
- `write_address_in_bounds` and `read_address_in_bounds`;
- `no_write_while_full` and `no_consume_while_empty`;
- `destination_payload_stable_under_backpressure`;
- `watched_token_ordering` and `watched_token_data_integrity`; and
- `watched_token_consumed_under_bounded_clocks_and_eventual_ready`.

Six individual cover tasks retain distinct witnesses for clock coincidence,
full, write wrap, read wrap, simultaneous enqueue/dequeue, and watched-token
consumption.

An independent four-entry ghost queue samples transfers from the global
pre-state, tracks storage order and pointer movement, and compares the
pre-consume visible word. Reference registers independently track both
two-stage Gray pipelines.

## Negative controls

Eight isolated harness mutants change one monitored behavior path while the
canonical IR, emitted production DUT, property predicates, and other monitored
paths remain identical to the valid fixture:

- Gray conversion flips one bit only in the observed write-Gray equation path,
  leaving the transition monitor on the production Gray value;
- full detection inverts the observed full-next result;
- address selection flips the observed write-address low bit to a different
  in-range address, so selection fails while the bounds assertion still passes;
  and
- storage ordering flips one bit of the observed consumed word, so data
  integrity fails independently of watched-token ordering.
- source-side read-Gray and destination-side write-Gray pipeline observations
  are mutated independently, with separate sticky error state and labels; and
- widened write/read address observations independently set the out-of-range
  bit, making each bounds assertion falsifiable without changing selection.

Each bundle declares one exact expected stable assertion label and requires
one retained counterexample. Wrong or additional labels, missing or multiple
counterexamples, absent cover witnesses, inconclusive results, tool errors,
and timeouts fail closed.

Watched-token ordering captures the accepted DUT write address. Every earlier
dequeue must be at a different address, and the dequeue whose ghost distance is
one must use that captured address. Payload equality is checked separately.
The 80-interval completion assertion applies to selected accepts that leave at
least 80 scheduling intervals in the 128-step BMC horizon; later selections do
not establish a universal beyond-horizon liveness claim.

## Commands and claim boundary

Run deterministic native checks with:

    scripts/formal-bundle-selftest.sh
    scripts/phase5-async-fifo-formal-selftest.sh

Run the pinned matrix with:

    scripts/phase5-async-fifo-formal-gate.sh [EMPTY_RUN_ROOT]

The pinned gate snapshots repository inputs, Git status, and HEAD before and
after execution; binds validator, artifact CLI, both selftests, relevant
schemas, lock, runner, gate, bundle, and result digests; retains per-task logs
and typed result artifacts; and requires one bounded pass, six witnesses, and
eight isolated counterexamples across nine fixtures and fifteen tasks.

This is bounded two-state functional evidence only. It excludes analog
metastability, MTBF, placement, routing, RAM mapping, recovery/removal,
unilateral-reset delivery, timing closure, and silicon reliability. An
unavailable pinned OCI runtime produces incomplete evidence, never a host-tool
substitution or pass.

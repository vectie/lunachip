# Saved compute identity implementation

This slice extracts the existing compute controller from the fixed direct-queue
dependency fixture. It addresses the saved command across the registered Issue
gap and accepted-owner terminal identity. It does not add a new controller or
monitor family, and it is not yet a proof of authorization or full-device
safety. The existing generation bridge is proved; composing it with this
controller remains an explicit later obligation.

## Production state and behavior

Retain nine actual production registers totaling 80 bits: the two-bit FSM,
four-bit fault, 32-bit ticket, three one-bit A/B/C selectors and three 13-bit
M/N/K dimensions. Resolve the same FSM structurally from the reset-inactive
Issue and Done observations rather than numeric NodeIds. Preserve each
register's next expression, domain, synchronous reset, enable and initial
value. Initial state remains arbitrary until reset.

Outer acceptance captures all seven identity fields, including a command that
fails preflight. Legal acceptance enters Issue; preflight failure enters Done
without inner issue. Issue holds the saved payload until the inner handshake,
then enters Run. Run observes inner terminal validity; a wrong ticket or
nonzero inner fault produces outer fault11, otherwise fault0. Done returns
Idle through the actual reset-inactive completion-ready expression. Reset
dominates all updates. Do not free completion-ready or derived Issue/Done.

The admission cone must retain the exact Idle/live/conflict masks and queued
dispatch validity: raw MatMul, syntax, dimensions, dependency resolution and
head Dispatch state. ComputeAccept, dependency-ready and authorization may not
be replaced by free inputs. Load/store conflicts, preflight and inner ready/
terminal payloads are explicit agreed boundary cuts, not proven lease/core
behavior. The nine-register slice also treats the required generation fields
as arbitrary cuts; that extraction alone does not prove they equal the ghost.

## Exact extraction

Private discovery resolves the existing observation bindings, checks types and
specifications, resolves admission and inner completion boundaries structurally,
and discovers the finite original combinational closure. Unknown sequential,
memory or external leaves fail with a checked error. Shared aliases are
deduplicated; outputs that the slice derives cannot be cut.

Materialization copies clock, cuts and closure in original node order. A full
original-to-local map is allocated before remapping forward next references.
Nine roots remain actual registers; nonstate cuts become typed inputs. The
existing operation remapper is reused. A small private exact-register copier
is shared with the generation sequential materializer to avoid duplicating
reset/enable/initial handling. Existing generation exports must remain
byte-identical after that refactor.

Expose private-module current state plus accept, preflight, inner valid/ready,
terminal and public halted outputs for native validation. Keep this checkpoint
private: no public function, ordinary task, fixture case, CLI flag, result
receipt or runner mode is required until proof inputs are ready. Production
IR and ordinary emitted RTL must not change.

## Validation requirements

Native tests compare every copied register spec, cone operation, type, output
driver and alias. They check deterministic extraction, untouched original IR,
unknown initial state, synchronous reset, nonedge hold, and exact transition
behavior. Corruption tests target demonstrated discovery boundaries rather
than adding a generic validator framework.

Behavior tests must show legal acceptance followed by held Issue, stable saved
ticket/ABC/MNK despite later raw command and generation changes, then inner
handshake. Also cover preflight failure with no inner issue, matching and wrong
inner terminal tickets, inner fault priority, reset interruption, and the
actual Done-to-Idle transition. If the full fixture cannot expose a stalled or
bad inner response, test the exact extracted boundary explicitly and label
that scope; do not pretend it is a reachable full-device trace.

Use targeted native checks during implementation, then interface generation,
formatting, strict checking and one full native suite at the completed
checkpoint. Compare original thirteen generation artifacts and the four
ordinary dependency bundles against their retained baselines. Commit the
implementation before any external engine runs.

## Sequential proof and composition requirements

Reuse the independent saved authorization/owner reference. Authorization is
established at outer acceptance from the independently decoded command and
generation relation, and retained through Issue; never re-evaluate latest
generations after acceptance. Do not assume accepted commands are authorized.
An actual proof must either include the original generation registers and
reference together with this controller or supply an explicit sound
substitution argument for the already proved relation. Free generation cuts
alone are insufficient to claim composition with the unchanged full ghost.

Retain original clock and reset sampling, arbitrary pre-reset state and later
reset, actual induction status where unbounded claims are made, and selected
counterexamples for comparison-only controls. Do not claim a complete gate
from extracted construction or native simulations.

Compute-only ownership leaves load/store owners, core/SRAM, arithmetic, FIFO,
retirement, leases, wrap, fairness and full safety outside this slice. The
normative phase gates remain unchanged.

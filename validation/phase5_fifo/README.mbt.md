# Phase 5 asynchronous-FIFO differential evidence

This native-only package generates three deterministic, self-contained
LunaWave/Verilator fixture bundles. It deliberately reuses the phase-neutral
atomic harness and pinned runner without modification.

The watched-token ledger observes `ready`, `valid`, and payload immediately
before each atomic edge batch. On a coincident boundary it accounts for a
destination dequeue before a source enqueue, then applies the whole timestamp
atomically. The ledger validates payload order and data conditional on the
observed transfers; it intentionally does not duplicate the DUT control or
pointer model. Ready/valid correctness comes from the LunaWave-versus-Verilator
output comparison and is strengthened by the separately named formal
properties.

Every input is fully known on every row. Coverage is mandatory: both pointers
wrap at least twice, the queue becomes full and empty and leaves both states,
and enqueue-only, dequeue-only, simultaneous, coincident, and backpressured
events all occur. A fourth bundle uses the same frozen stimulus with the
intentionally incorrect sequential-edge bridge and freezes its first public
mismatch as a negative witness.

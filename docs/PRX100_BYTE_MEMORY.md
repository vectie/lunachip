# PRX100 byte-memory read-port isolation

This records historical target1.3. The subsequent
[target1.4 word-read extension](PRX100_WORD_MEMORY.md) changes the opt-in core
transport and measures52.51% lower FPGA latency; the legacy generator and
these earlier receipts remain preserved.

Target revision 1.3 keeps the exact portable core, DDR bridge, workload and
50/100 MHz clocks. The core's globally outstanding tagged byte transactions
already receive their synchronous BRAM response on the earliest consumable
edge. A byte cache cannot remove the core's arbitration states.

The target gives result collection its own synchronous BRAM read port.
Core reads retain their registered output while backpressured, independently
of result reads. Both ports use ReadOld and HoldLast; the single write port
and the two existing C ownership regions are unchanged. Host writes still
exclude core writes. Operand and descriptor publication rules are unchanged.

Collection reads C[0] in the retirement-join state and reads C[channel+1]
while the current partial DDR write is issued or acknowledged. Each result
is latched only on a later edge after its read. This removes the shared-port
wait and a separate read-issue state without changing partial ordering,
bank lifetime, fault behavior or the host-visible traffic.

Version is 0x00010003; register layout and counter units remain unchanged.
Activity counters overlap and are not a latency partition. The
[physical qualification](evidence/prx100-byte-20261017.md) passes20 jobs per
image. Whole START-to-DONE median is1.12710ms versus fresh1.2 at1.12747ms:
only0.37us or0.033% lower. The earlier retained1.2 median is1.12750ms.
One additional BRAM tile is used. The unchanged core's serialized byte
transactions remain the dominant cost; this is not a substantial speedup.

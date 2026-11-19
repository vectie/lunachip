# PRX100 target loading pipeline

This describes the qualified1.1 baseline. The1.2 successor is specified in
[descriptor publication pipeline](PRX100_PUBLICATION_PIPELINE.md); its
[physical qualification](evidence/prx100-publication-20261017.md) passes20 jobs
at median1.12750ms with the original core unchanged.

This target revision overlaps DDR operand staging for tile t+1 with the
unchanged fetched concurrent core's execution of tile t. The portable core,
its 4096-byte aperture, ring depth, descriptor encoding, clocks (50MHz core,
100MHz MIG UI), workload and INT32 arithmetic remain identical.

Two operand staging regions alternate: A at256/2304 and B at512/2560.
Descriptors remain at0..127; C remains at1024..1055. Only the inactive
operand region may receive prefetch writes. A host staging write excludes a
core write acceptance on that edge; core reads use the independent BRAM read
port concurrently. An already held core response remains stable. The single
synchronous BRAM retains ReadOld and Reject policies.
Core writes remain restricted to the C aperture.

The first tile is staged before publication. During each nonfinal tile's
completion-drain state, one target-side prefetch owner serially reads the
next36 words. Its requests use the existing latched DDR owner. Both all four
ordered completions and all36 successful prefetch responses are required
before reusing the descriptor ring. Quiescence still requires equal producer,
consumer and retired counts plus no held completion or BRAM response.
Subsequent descriptor updates change ID, base and slot fields (12 words).
Publication never exposes an incompletely filled operand region.
Partial-result DDR acknowledgements directly advance the channel/tile, removing
one separate control edge for each of the512 partial words in a full job.

START resets prefetch state together with the idle core and all counters.
Health loss, remote error, malformed completion and watchdog retain the
existing fail-closed behavior; physical reset flushes all ownership.

Target register version is0x00010001 (1.1). The DDR-wait counter now includes prefetch request/wait cycles, which overlap
the core-wait counter. Staging cycles include prefetch request/wait cycles and
descriptor initialization. These counters must not be added as a disjoint
latency partition. Total START-to-DONE remains directly comparable. Logical
traffic and completion counters retain their prior meanings. This document
also defines core-wait as the publication/service/drain interval, including
the prefetch join if DDR finishes after the core. In the qualified full jobs
prefetch finishes first and this counter remains61440cycles.

The [physical qualification](evidence/prx100-core-loading-20261016.md) passes
20 jobs and all CPU checks, reducing median FPGA time from1.76730 to1.37524ms
(22.18%). Core IR/RTL and bridge IR/RTL remain byte-identical; clocks and the
4.5 BRAM/11 DSP footprint are unchanged.

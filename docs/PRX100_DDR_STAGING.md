# PRX100 DDR line staging

Target revision 1.5 removes repeated word-request overhead in operand staging.
The portable word-read core from target 1.4, arithmetic, clocks and pinned
Qwen workload remain unchanged. The [physical A/B](evidence/prx100-staging-20261017.md)
passes20 jobs per image, with median0.53596→0.48102ms:10.25% lower,1.11× faster.
Staging activity falls0.40906→0.29776ms (27.21%). The scalar CPU remains faster
at183µs; host workload time is essentially unchanged because JTAG dominates.

An aligned 16-byte job read owns one request and four ordered 32-bit response
beats. The bridge sends the existing native DDR line through its response
FIFO. Staging writes each accepted beat directly into the inactive operand
region, without requesting the three remaining words individually. Host
portal reads and all writes retain their single-word acknowledgment contract.

`request_line` distinguishes these job reads; `response_last` marks the fourth
beat. The source retains ownership until that beat. Both controller and bridge
must hold payload and last through backpressure. A malformed last, DDR fault,
calibration loss or reset prevents publication of incomplete operands and
requires the existing physical recovery procedure. A subsequent START after
success preserves resident DDR buffers and rebuilds job state.

Each K16 tile stages one activation line and eight weight lines: nine DDR
requests and 36 BRAM word writes. The staged-word counter remains 36 per tile;
the accepted DDR-read counter becomes nine per tile. Eight partial result
writes per tile and eight final sum writes remain unchanged. Version register
`0x00010005` distinguishes this changed counter/protocol meaning. DDR, staging
and core activity counters still overlap.

Native DDR line count and useful bytes do not change: the old cache already
fetched nine lines per tile. The gain removes slow-domain word requests.
Each full projection makes576 line requests, stages2304 words and writes520
DDR words. Core counters remain4352 word reads, zero byte reads and512 writes.

All1180 strict native tests,3552-cycle core/controller independent replays,
587 atomic bridge events, three pinned synthesis checks and scoped bounded
formal/sensitivity tasks pass. Routed setup/hold are+0.958/+0.059ns, all12
bus-skew constraints pass, and resources are20189LUT/14494FF/5.5BRAM/11DSP.
Full Phase7 and unbounded core/controller/bridge closure remain open.

The target1.6 [result-write continuation](PRX100_DDR_RESULT_WRITES.md) retains this operand line-staging behavior and the exact same portable core.

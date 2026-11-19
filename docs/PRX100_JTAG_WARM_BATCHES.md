# PRX100 repeated warm-request coalescing

This experiment keeps the integer core, FP arithmetic, target RTL and qualified
FPDDR1.3Q bitstream unchanged. It compares the preceding `joined` host path with
a `coalesced` path for the same selected BF16/FP32 Qwen3-0.6B projection.

The six adjacent warm requests each contain three jobs with K=1024 and three
activation vectors. All six requests are available together, use the same
resident weights and activation generation, have no intervening writes or cache
invalidation, and reset vector iteration on a multiple of three. The coalesced
path submits their18 jobs as one physical batch, within the existing 48-job
limit. The other campaign cases and all 106 projections remain unchanged.

Every actual DDR output is checked against the CPU reference and split back
into the six logical request results. Every physical batch retains observed
DONE/error-zero qualification and all 34 counters. Coalescing reduces physical
batch boundaries and their diagnostic snapshots; it does not claim per-request
hardware counters. Cache evidence must remain valid at each physical launch.

Measure the entire warm sequence, including launches, polling, every result,
counter checking, logical-result reconstruction and evidence logging. Record
the first and last logical result-ready times after physical CPU/counter checks
and before final logical-table reconstruction. These are not serving/network
delivery times. Coalescing is an aggregate-throughput
optimization; it can delay the first response and does not establish faster
isolated three-job execution. Preserve all samples and compare fresh interleaved
runs on the same bitstream. Application timing includes actual model upload,
both full operand readbacks, all 106 projections and final guards, excluding
Vivado startup and programming.

Independent audits must validate the exact physical campaign, every logical
slice, request order, vector alignment, unchanged operand generation, observed
completion, all results and counters, timing inclusion and command accounting.
The fixed experiment admits only the six identical adjacent warm requests;
it is not a general inference scheduler or serving adapter.

Measurements: [board report](evidence/prx100-fpv-20261018.md).

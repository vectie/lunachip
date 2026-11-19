# PRX100 JTAG launch and completion contract

The FPDDR1.3Q host path preserves the qualified eight-lane BF16/FP32 target and integer core. Launch contains optional descriptor,START,then optional status/error. Use sequential command-list ordering for mixed directions. Homogeneous hardware read/write queues are independent;AMD documents read-first mixed queued execution ([PG174](https://docs.amd.com/v/u/en-US/pg174-jtag-axi)).

Dedicated launch transaction handles prevent ordinary invalidation/control writes from mutating reused START DATA. A cached DATA update may be omitted only when that dedicated handle owns the exact unchanged payload. Batched DATA fetches require exact object count,width,hexadecimal validation and every write echo. Completed result/counter reads require observed DONE/error0;the full results and34-word stable counter snapshot remain mandatory. Group-final responses are not per-descriptor response evidence.

Compare serial/cached under identical logging,payloads and checks. Retain every preplanned interleaved pair. Select cached only if both application and launch/poll medians improve;report ranges and individual pairs. Do not claim faster arithmetic or full-model inference from host timing. The measured selection,failed experiment and reproducible evidence are in [the task report](evidence/prx100-fqa-20261018.md).

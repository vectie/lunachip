# PBlaze3 a11 AXI identity routing review

Read-only Vivado 2025.2 inspection of `/work/builds/pblaze3-work-20261026-a11/project/pblaze3.xpr`.
The BD 41-2384 warnings on the S00 boundary describe intentional padding and return-ID narrowing.
No message severities were changed. This probe did not generate IP, synthesize, implement, program hardware or alter licensing.

Verified public properties: crossbar ID width 5, two SI slots, one MI slot, S00 thread width 4/base 0, S01 thread width 0/base 16. XDMA uses 4 ID bits, MIG uses 5, and the accelerator is an ID-less single-thread master. The resulting downstream ownership ranges are XDMA 0..15 and accelerator 16.

All eight downstream leaf AWID/ARID/BID/RID pins expose LEFT=4, RIGHT=0. Public interface nets connect crossbar M00 to M00 coupler S, M00 coupler M to memory M00, and memory M00 to MIG S. Hierarchical interfaces expose no reliable width metadata, so the guard separately checks the emitted coupler declarations and all four passthrough assignments, downstream wires, SI zero padding and post-routing S00 response slicing. The guard fails if this exact expected 2025.2 structure changes.

`guard.tcl` exports `pblaze_assert_memory_ids GENERATED_TOP REPORT_CHANNEL`; invoke immediately after `generate_target all`, with the PBlaze3 block design current. `probe.tcl` is the exact read-only test input. `vivado.stdout` records actual queried values and the selected generated RTL lines without retaining the complete vendor-generated RTL or cache.

Positive: the complete a11 guard passed. Four independent negative controls rejected crossbar width 4, MIG BID LEFT=3, direct xbar-to-MIG routing in place of the coupler, and a mutated M00 BID passthrough narrowed to [3:0]. Mutations were local Tcl strings or deliberately incorrect expected values; the project remained read-only.

Generated-source SHA-256 identities (also queried in the actual Vivado process):

- `pblaze3.gen/sources_1/bd/pblaze3/synth/pblaze3.v`: `bb47b43366bd74c153344300ca4395aba538388323df5302c2fa0d8062ea728b`
- `pblaze3.gen/sources_1/bd/pblaze3/ip/pblaze3_memory_imp_xbar_0/synth/pblaze3_memory_imp_xbar_0.v`: `e718df269294ebcc2c78fc60aeafe54e1ccfc4fdef8bd93c35697c1b315ca3c5`

AMD documents distinct BASE_ID prefixes and per-SI THREAD_ID_WIDTH sampling in [PG059, Use of ID Signals](https://docs.amd.com/r/en-US/pg059-axi-interconnect/Use-of-ID-Signals). The ownership interpretation above follows those documented rules plus the actual queried configuration and emitted wiring.

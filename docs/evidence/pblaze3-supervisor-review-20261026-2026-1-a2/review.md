# Fresh accelerator supervisor synthesis review

The actual linked synthesis design of accelerator run `20261026-v20261-build-a10`, using sealed ready inputs `artifacts/pblaze3-ready-inputs-20261026-2026-1-a5`, passes the same independent 20 ns clock-ancestry and exact ten-endpoint reset-boundary checks. No earlier checkpoint was substituted.

The complete captured supervisor clock, primitive properties, pin drivers and register fanout are byte-identical to the separately inspected fresh smoke a9 supervisor. Therefore the same actual three FDPE ASYNC_REG stages, eight FDCE asynchronous-clear counter registers, registered bit7 release, raw-healthy inverter and final AND gate are present in this accelerator netlist. The only differences in the full structure report are PCIe clock net-segment counts (1017 versus 1025), caused by the larger accelerator design; the matching-net checks pass in both designs.

This receipt adds only the unique accelerator probe input, output, structure and applied-constraint snapshots. The shared probe/fetch drivers and detailed mapped interpretation remain in immutable `docs/evidence/pblaze3-supervisor-review-20261026-2026-1-a1`. Its fresh smoke evidence is referenced, not copied. The retainer independently compares the full supervisor portions before sealing this receipt.

Actual structure SHA-256 is `3b48dd54e30b0c596463a5c22a3a625598c686e7b1b7a3e44ec4893e8edb44e3`; applied-XDC SHA-256 is `a1736d2dd5ccd14a2f6ba66de84dd4cb308947f72bd20ba0cfc983f94f657bf0`. Guest scratch is `/work/builds/pblaze3-review-supervisor-a10-synthesis-a1`, and the project is `/work/builds/pblaze3-work-20261026-v20261-build-a10/project`.

This is synthesis structure evidence only. Both fresh routed designs still require setup/hold/pulse/CDC review and the exact seven-endpoint routed guard. There is no routed or physical-board acceptance claim. No synthesis, placement, routing, checkpoint save, bitstream creation or hardware access was performed by this read-only probe.

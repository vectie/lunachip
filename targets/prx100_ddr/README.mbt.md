# PRX100 standalone DDR diagnostics

This target constructs a MoonBit/LunaWire memory tester and AXI4-Lite control
registers for the PRX100's256MiB DDR3. The physical wrapper owns vendor
MIG/clock/JTAG IP and packs four32-bit lanes into the native128-bit beat.
It imports no portable accelerator and changes no existing Device ABI.

The [contract](../../docs/PRX100_DDR_DIAGNOSTIC.md) defines command/address
units, byte masks, ready/valid behavior, reset and counter timing. The
[physical ledger](../../docs/evidence/prx100-ddr-memory-20261016.md) records
three passing calibration/full-memory campaigns, measured bandwidth and
qualification limits. Validation lives in `validation/prx100_ddr`.

Export unique source bundles with the native CLI:

```text
moon run --target native cmd/prx100_ddr -- export /absolute/new-inputs
moon run --target native cmd/prx100_ddr -- export-replay /absolute/new-replay
moon run --target native cmd/prx100_ddr -- export-formal /absolute/new-formal
moon run --target native cmd/prx100_ddr -- export-formal-negative /absolute/new-negative
```

Use the pinned target `.mbtx` drivers for headless MIG generation, synthesis,
timing-gated routing, CPU_TAG programming and independent result auditing.
Build outputs require fresh directories outside sealed evidence archives.
The standalone image provides JTAG control; it does not expose the UART
accelerator service or yet connect DDR to the Array8 core.

# PRX100-D target preparation, 2026-10-15

The user selected PRX100-D and authorized a board contract, minimal MoonBit
UART/BRAM shell and reproducible target-build preparation. The requested model
was confirmed as Qwen3-0.6B. The [feasibility assessment](../PRX100_QWEN_FEASIBILITY.md)
excludes full-model inference from this initial target: raw4-bit weights alone
exceed256MiB, and the numerical/runtime/memory requirements exceed the existing
INT8 tile interface. No model weights were downloaded or model execution claimed.

## Implemented scope

[The transport0.1 contract](../PRX100_BOARD_CONTRACT.md) records DDRV1.0 document
identity, clock and IO pins, UART direction, distinct reset-button choice,
fixed request/reply frames, CRC-8, sequence echo, full-width address guards,
quiescent batch ownership, completion backpressure, counter snapshots and reset.
The MoonBit generator owns the digital UART, frame parser, command controller
and synchronous1024x32 host aperture. Memory has explicit ReadOld/HoldLast
semantics, tagged held responses and no reset clearing.

The canonical core and shell are emitted independently. A generated structural
wrapper connects their complete signal interfaces; a separate physical wrapper
owns STARTUPE2 startup and reset conditioning. There is no new IR hierarchy API,
portable-core change or imported serving product. Smoke1x1/K2 and array8x8/K16
targets both use host4096/ring4/q3. The eight-by-eight core retains exact digest:

`37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8`.

Tracked source bytes under designs/device/IR/wire/wave/emitter match the saved
pre-task SHA256 inventory. The user's pre-existing codec test and unrelated
concurrent Phase6 work remain untouched.

The POSIX `.mbtx` build runner exports fresh inputs, verifies their inventory,
checks an explicit local Vivado2025.2 launcher/version pin and records source
and MoonBit identity. Generated Tcl uses one implementation thread and fails
before bitstream generation on missing aperture BRAM, missing synchronizers,
unconstrained internal timing, negative setup/hold slack or implementation DRC.
The launcher pin does not hash an entire vendor installation. Cross-host
bitstream reproducibility, vendor API qualification and actual implementation
remain unqualified until a supported x86-64 Linux Vivado installation runs it.
The CLI encodes request files and validates replies; opening serial devices is
still a later host-diagnostic step.

## Actual independent digital evidence

Both Verilator cases pass strict pinned lint, compile, execute and the existing
typed identity-first comparator. Actual and expected TSV are byte-identical.

| Fixture | Actual checked scope | Result |
| --- | --- | --- |
| Composed byte interface | Real fetched smoke core + exact byte-control graph + host memory;3655 post-reset cycles;2 reply-interface outputs,7310 observations; signed−7x9→−63, busy-write refusal, bounds refusal, completion extraction and reset/persistence | PASS |
| Bit-level UART shell | Explicit RX synchronizer, UART RX, framing/CRC and TX at test divisor8;3890 post-reset cycles;13 shell outputs,50570 observations; independently decoded Identify reply with sequence0x4567 | PASS |

The byte seam is a separately named generator, not a claim that the complete
physical UART/core wrapper was simulated at divisor434. The UART test uses
mocked core-peer inputs; the composed test uses the actual core. Existing
Phase6 device-boundary results remain separately scoped. These results do not
establish analog CDC, physical pin behavior or default-baud board operation.

Verilator5.050 image/platform:
`docker.io/verilator/verilator@sha256:6d8207220a9aa51fa8bed1449641cc5b113ca0ef912aa1a76afccd728a6391c5`,
`linux/arm64`. The unchanged repository runner keeps warnings fatal, networking
disabled and initialization policy recorded; no tool lock or warning waiver
changed.

The final smoke composition also passes the unchanged pinned generic Yosys
runner, with final `check -assert` reporting zero problems. Toolchain:
Yosys0.68(`38e001a6f`), image
`ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`,
`linux/amd64`. This includes the actual UART/control and host memory, but omits
the vendor-specific physical startup wrapper. Generic mapped cells do not
establish RAMB/DSP inference, FPGA fit or routed timing. No new formal theorem
or completed Phase6/7 gate is claimed.

## Native and recipe validation

Interface generation, selected package/script formatting and strict native
checking pass. The full native suite passes **1060/1060**, including the new
board, codec, aperture, held-response/reset and typed-mutation cases. The native
log finishes at13:37:12 China time; process completion is confirmed at13:37:27.

The build runner's valid-inventory case and four refusal cases pass (existing
path, changed bytes, duplicate inventory entries and incomplete input set).
The actual generated Tcl runs under Tcl test doubles: nominal sequencing plus
seven refusal cases pass (release, BRAM, synchronizer, coverage, setup, hold and
DRC). These are syntax/control-flow tests, not vendor execution, a routed
checkpoint or a real bitstream. Test-double output files explicitly identify
themselves and stay under their test-case directories.

The legacy `scripts/check-boundaries.sh` fails locally on vendored MoonBit
dependency sources in pre-existing nested `scripts/_build/.../.mooncakes`
caches. That failure is retained. No cache is removed and the validator is not
weakened. All new first-party `.mbt` files are below500 lines; source and import
checks find no forbidden product dependency. This checkpoint does not claim a
complete phase-gate-script pass.

## Retained attempts and claim limits

An initial compile fails because a private shell port's encoded identifier
exceeds Verilator's C++ name limit. Shortening the shell prefix from`core_` to
`c_` fixes that boundary; a native regression enforces the limit. The first
build-directory preflight refusal, failed compile and earlier synthesis pass
remain recorded. A first Tcl test-double attempt lacked a stub command and
fails honestly; its corrected separately named run passes. Retention-helper
preflight failures also remain in the campaign. None is relabeled as success.

Vivado is absent on the development Mac. No vendor installation, board
programming, physical measurement, model serving, FPGA execution, physical
BRAM mapping or timing closure was performed. Phase6 stays in progress;
Phase7 has target preparation, not a completed physical gate.

At13:30 China time the final PRX100 synthesis container exited and Docker was
empty. The shared validation VM is released to the separately authorized
Phase6 measurements; no further PRX100 containers are started. Host native
tests may continue independently. The shared VM is deliberately left running
for that handoff; only each runner's own containers/volumes are cleaned up.

## Final checkpoint and retention

The final array8 export retains the historical core digest above. Final smoke
core/shell IR and structural wrapper compare byte-identical to the inputs of
the accepted final synthesis. The named RTL streams have these SHA256 values:

| Artifact | SHA256 |
| --- | --- |
| Byte-interface expected and actual TSV | `45e8273b7647b09456d49e4f05ee7c6b51a495b6f793ca9faf922a39cc0dc084` |
| UART expected and actual TSV | `0eab35da6de0029f5469a399f59c41da391850397b791eeef309f9bf272721fe` |

The qualified archive is
`/Users/kq/Workspace/lunachip/artifacts/prx100-20261015`.
Its inventory SHA256 is
`d60c82bf57b089e30afadb968688c27147d4f492372f64a3fed50089e87228fa`;
its seal SHA256 is
`6753f4ee4744db785611338f17a7fe3e5da2ee571bdb6b9c3674aab2c8400e21`.
All retained inventory checksums verify. Source inputs, emitted RTL, both
successful and unsuccessful attempts, traces, operation receipts, tool locks,
tool versions and native logs are retained. Large synthesis models are stored
with deterministic gzip; decompression was byte-compared to the exact originals.

The redundant owned temporary tree
`/private/tmp/lunachip-prx100-validation-20261015` (also accessible through its
`/tmp` alias) was removed **only after** complete directory byte comparison,
unchanged-source inventory and verification of every retained hash. Its exact
recovery location is the archive above; `RETENTION_MAP.json` and
`tool-result-recovery.json` record the paths. A first retention attempt's path
flattening error, its exact driver and error log remain retained; the corrected
driver reuses only byte-identical partial source copies before the full comparison.

Compiler and Verilator caches remain outside the sealed archive at the existing
repository `_build` and `/private/tmp/lunachip-prx100-work-20261015`.
Do not compile in the sealed archive. Restore historical inputs to their mapped
working path or export new inputs to a fresh working directory before rerunning.
The pre-existing sealed archives and 2026-10-08 cleanup map were not modified.

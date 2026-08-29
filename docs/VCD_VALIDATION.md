# VCD viewer validation evidence

## Evidence boundary

LunaWave's deterministic golden VCD was loaded on 2026-08-29 by Surfer, an
independent common waveform viewer. This is parser/load evidence for the exact
golden artifact, including its unknown `x` value and stable `s0`/`s1` signal
identifiers. It is not a claim about downstream RTL, synthesis, or timing.

## Pinned viewer

The viewer was the ARM64 Homebrew bottle of Surfer 0.7.0:

| Item | Value |
|---|---|
| Formula | `surfer` 0.7.0 |
| Bottle platform | `arm64_tahoe` |
| Bottle SHA-256 | `c3ccd3b8def9247442b19ec02afd47579ed36daf5e21aa1602a24748af77c254` |
| Executable format | Mach-O 64-bit arm64 |
| Runtime header | `x-surfer-version: 0.7.0` |
| Wave parser header | `x-wellen-version: 0.20.5` |

The bottle was downloaded to `/private/tmp`, its SHA-256 was verified before
extraction, and it was not installed into the host. An older GTKWave 3.3.107
archive was also SHA-verified against Homebrew metadata but rejected before use
because its executable was x86-64 and Rosetta was unavailable. It is not part
of the passing evidence.

## Load procedure

The checked-in `wave/trace/fixtures/golden.vcd` is the same byte sequence
asserted by the LunaWave VCD golden test. The independent load used Surfer's
headless server mode:

```sh
surfer server \
  --bind-address 127.0.0.1 \
  --port 45678 \
  --token lunachip-vcd-smoke \
  --file wave/trace/fixtures/golden.vcd
```

The server stayed live after loading and answered a localhost request with
`server: Surfer`, `x-surfer-version: 0.7.0`, and
`x-wellen-version: 0.20.5`. It was then terminated. A malformed or unsupported
waveform would fail before the server became available; LunaWave's own strict
golden and malformed tests remain the primary byte-level contract.

## Revalidation

Any change to VCD bytes, identifiers, declarations, timestamps, unknown-value
spelling, or source-map linkage must:

1. update the reviewed golden test and checked-in fixture together;
2. pass the native LunaWave trace tests;
3. repeat the pinned independent viewer load (or record an intentionally
   upgraded viewer version and digest here);
4. verify that each VCD identifier resolves through the canonical trace source
   map to its semantic path and optional source span.

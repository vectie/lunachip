# LunaWave performance evidence

## Scope and claim

This document closes the measurement requirement in the Phase 1 gate. It does
not claim that prepared settlement is allocation-free. Direct measurement
proves the opposite: the current reference interpreter allocates **629 blocks
and 20,116 requested bytes per prepared `settle()` call** for the representative
workload below. The allocation sources are identified and corrective work is
scheduled here rather than hidden behind an aggregate timing result.

The benchmark and probe live under `benchmarks/` and `cmd/sim-bench/`. They are
engineering evidence, not stable LunaWire or LunaWave APIs.

## Representative workload

`lunawave_prepared_combinational_v1` constructs one 16-bit, 724-node canonical
module. Its 48 dependent stages each exercise fixed-width addition,
subtraction, low multiply, bitwise operations, logical shifts, slicing,
concatenation, explicit reinterpretation, unsigned comparison, and mux. The
long dependency chain prevents a stage from becoming dead output logic.

Before measurement, the harness:

1. prepares a `Simulator` exactly once;
2. drives two fixed known inputs;
3. performs 2,000 warmup settlements;
4. compares the settled result with an independent `UInt64` oracle;
5. measures 20,000 further settlements without input mutation, output
   formatting, trace collection, or simulator preparation inside the loop;
6. checks the oracle again after the loop.

The reviewed result is `18424`. Black-box tests also check a smaller workload
against the oracle and verify that 100 repeated settlements remain identical.

## Measurement environment

Recorded on 2026-08-29:

| Item | Value |
|---|---|
| Host | Apple iMac `Mac16,3` |
| Processor | Apple M4, 10 cores (4 performance, 6 efficiency) |
| Memory | 24 GB |
| Operating system | macOS 26.2, build 25C56, arm64 |
| Moon | 0.1.20260803, commit `c19f78e`, 2026-08-03 |
| Moon compiler | 0.10.6, commit `62c2592d1`, 2026-07-31 |
| Apple Clang | 17.0.0 (`clang-1700.6.4.2`) |
| Baseline Git commit | `fd09792d9101ec43d98ffc165da3977ac2da9f47` plus the Phase 2 working changes under test |

Release artifacts from the recorded run:

| Artifact | SHA-256 |
|---|---|
| Shipping-allocator benchmark executable | `6ecfb1fdce6cc6fe0272de7f643deb166e5b1a28f08ad318278bf58dfcde4fb9` |
| Allocation-profile executable | `a02e75c2c74f4a600d13f7027cde8080d618e33993985b1c1b0bec26171a99a3` |
| Moon-generated release C | `e728e86053f4b6bd43d6cc3c6cdfd38cc600580976e30722185167e8dcc4c173` |
| Allocation interposer source | `5c8bbbb91d4a56e2b32da54d390b155f730d46c49a5de2ec82fe278cd6baa991` |

The Git identifier is not presented as a clean-tree digest: the measurement
intentionally covered the integrated, uncommitted Phase 2 changes. The artifact
hashes identify the exact generated and executable evidence.

## Commands

Targeted correctness and interface checks:

```sh
moon fmt benchmarks/combinational cmd/sim-bench
moon info benchmarks/combinational cmd/sim-bench --target native
moon check benchmarks/combinational cmd/sim-bench \
  --target native --deny-warn --warn-list +73
moon test benchmarks/combinational --target native --deny-warn
```

Shipping native release timing, using MoonBit's bundled allocator:

```sh
moon run --target native --release cmd/sim-bench
```

macOS allocation-site measurement:

```sh
MOON_BIN="$HOME/.moon/bin/moon" benchmarks/run-prepared-macos.sh
```

The allocation script first asks Moon to emit the ordinary optimized native C
and runtime archive. It then relinks that same generated release C without
MoonBit's statically embedded mimalloc object, so an injected macOS allocator
interposer can observe every `malloc`, `calloc`, and `realloc` call. This link
substitution is used only for allocation counting; timing results below come
from the ordinary shipping executable. The harness refuses to trust the probe
until a deliberately allocated 1,024-element MoonBit array is observed. That
self-check recorded its expected two blocks (4,104 and 24 requested bytes).

The preferred MoonBit sampling command was also attempted:

```sh
moon run --profile --target native --release cmd/sim-bench
```

It was unavailable because this host has the Xcode command-line tools but not
the full Xcode `xcrun xctrace` utility. The allocator interposer therefore
records exact call counts, requested sizes, and return-address symbols instead
of substituting RSS or elapsed time as an allocation proxy.

## Allocation result

Across 20,000 prepared settlements:

| Metric | Total | Per settlement |
|---|---:|---:|
| Allocation calls | 12,580,000 | 629 |
| Requested bytes | 402,320,000 | 20,116 |
| `malloc` calls | 12,580,000 | 629 |
| `calloc` calls | 0 | 0 |
| `realloc` calls | 0 | 0 |

Return-address aggregation identified every measured call:

| Source | Calls per settlement | Bytes per settlement | Explanation |
|---|---:|---:|---|
| `FixedArray::iter[ir.Node]` (three sites) | 3 | 84 | Iterator objects created by the module-node loop |
| `Simulator::evaluate_node` | 2 | 64 | Two constant `LogicValue` results |
| `LogicValue::binary_arithmetic` | 96 | 3,072 | One add and one subtract per stage |
| `LogicValue::bit_xor` | 96 | 3,072 | Two XOR results per stage |
| `LogicValue::mul_low` | 48 | 1,536 | One low multiply per stage |
| `LogicValue::bit_and` | 48 | 1,536 | One AND result per stage |
| `LogicValue::bit_or` | 48 | 1,536 | One OR result per stage |
| `LogicValue::shift_left` | 48 | 1,536 | One left-shift result per stage |
| `LogicValue::logical_shift_right` | 48 | 1,536 | One right-shift result per stage |
| `LogicValue::slice` | 96 | 3,072 | Two slice results per stage |
| `LogicValue::concat` | 48 | 1,536 | One concatenation result per stage |
| `LogicValue::less_than_unsigned` (two return sites) | 48 | 1,536 | One comparison result per stage |
| **Total** | **629** | **20,116** | Exact match to the counter totals |

Each operation result requests 32 bytes. Known-select mux and reinterpret nodes
reuse an existing value and did not allocate in this fixture. This distinction
is useful for diagnosis but does not weaken the gate: the prepared loop is not
allocation-free.

## Release timing

Ten ordinary release runs used the shipping MoonBit allocator, each with the
same 2,000 warmups and 20,000 measured settlements:

| Statistic | Nanoseconds |
|---|---:|
| Mean | 273,527,012 |
| Sample standard deviation | 14,868,356 |
| Minimum | 254,281,875 |
| Maximum | 302,017,583 |

Individual elapsed times were:

```text
302017583 282156625 291250292 267784375 277208792
260359958 263102792 254281875 264031375 273076458
```

The mean is approximately 73,119 settlements per second, or 52.79 million
evaluated non-input nodes per second for this fixture. These are local baseline
numbers, not a product performance promise; CPU placement, thermal state, and
other host load were not controlled.

## Scheduled removal of steady-state allocations

The evidence points to two bounded changes, not a general optimization rewrite:

1. Replace the node `FixedArray` iterator in the hot loop with an index-based
   traversal over a prepared flat schedule. This removes three iterator
   allocations per settlement and makes schedule ownership explicit.
2. Introduce module-internal scalar semantic kernels operating on
   `(width, value_bits, known_mask)` and store prepared values in parallel
   preallocated arrays. Public `LogicValue` methods and the simulator must both
   delegate to those kernels so there is still one semantic implementation.
   Observation APIs may box a `LogicValue` after settlement; the prepared loop
   must not.
3. Add this benchmark as a permanent release-mode gate. Its allocator probe
   self-check must pass, followed by exactly zero allocation calls for at least
   20,000 settlements. Keep the existing exhaustive and seeded conformance
   suites as the semantic guard during the representation change.
4. Re-run `moon run --profile` when full Xcode is available. Sampling is useful
   for CPU attribution, but it is supplementary to the exact zero-allocation
   counter.

Until those items pass, Phase 1 satisfies the plan's alternative gate wording:
the remaining allocations are directly measured, precisely identified, and
scheduled. The repository must not describe prepared settlement as
allocation-free.

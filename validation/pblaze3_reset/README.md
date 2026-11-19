# PBlaze3 reset-supervisor verification

This package checks the canonical `Pblaze3ResetHold` module independently of
the vendor reset synchronizer and physical board wrapper. Its host oracle
counts actual rising edges: asynchronous reset clears immediately, release
occurs after exactly 128 healthy edges, and the released state saturates.
Elapsed simulated time without a clock edge cannot advance the count.

The atomic replay includes 14,784 observations: 11,767 rising-edge events and
3,017 input-only events. Directed cases exercise startup, 127/128 boundaries,
2,048 extra edges after release, fault retrigger at counts 0/1/63/127/128,
reset coincident with the would-be release edge, and million-tick stopped
clock intervals before and after release. Another 12,000 seeded events vary
faults, active clock edges and elapsed time. Every observation is checked
against the independent oracle and exported for byte-exact Verilator replay.

The separate formal wrapper uses a 9-bit reference count and an initial-reset
assumption, followed by unconstrained reset. The 260-step BMC checks sampled
rising-edge safety and saturation. Its negative control demands release at
127 and must fail with a retained counterexample. `async2sync` is explicitly
limited to sampled-edge semantics; between-edge behavior comes from the
atomic replay. Neither test proves analog metastability, XPM behavior,
routed timing, PCIe reset fanout, or physical board operation.

From the repository root:

```sh
moon test validation/pblaze3_reset --target native --deny-warn --warn-list +73
moon run scripts/pblaze3-reset-verify.mbtx run /absolute/new/evidence /absolute/new/compiler-work
```

The runner uses the existing digest-pinned Verilator/Yosys container
infrastructure, keeps compiler caches outside evidence, checks deterministic
re-elaboration and transitive source identities, and seals a successful run.
An incomplete attempt has no passing `receipt.json`; retain its logs.

The first run, `artifacts/pblaze3-reset-offline-20261026-a1`, passed the replay
but exposed a pre-existing asynchronous-reset emission synthesis defect:
Yosys rejected a ternary-only reset assignment in a process with two edge
events. That failed attempt is sealed and must remain immutable.

After the asynchronous-reset emitter correction, the sealed run
`artifacts/pblaze3-reset-offline-20261026-a2` passed all 14,784 replay
observations, strict Verilator 5.050 checks, Yosys 0.68 synthesis and the
260-step SBY/Bitwuzla safety check. The deliberately incorrect 127-edge
requirement failed at solver step 129 and retained its counterexample.
The archive contains 157 checksummed files; compiler caches are outside it.

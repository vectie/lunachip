This fixture checks the standard SystemVerilog emitter's asynchronous-register
reset branch using the installed Vivado 2026.1 XSim simulator. The two DUT
registers come from canonical LunaChip IR, with active-high reset to `0xa5` and
active-low reset to `0x3c`, shared data and enable inputs. The testbench drives
the emitted identifiers from the emitter's name manifest.

The corrected emitter and reconstructed pre-fix form both pass 30 acceptance
events, each checking both registers. These cover binary asynchronous assertion
and release, enabled updates, disabled holds, X/Z reset at clock edges, and X/Z
transitions between edges while enable is zero. LunaWave generates the expected
acceptance trace. Z is mapped to unknown at the LunaWave boundary, whose internal
logic values represent known bits and X.

Two separate expected-failure events document an existing semantic difference.
After loading `0x5a` with reset deasserted, the bench sets reset to X or Z,
enable to one, and next data to `0xc3` between clock edges. LunaWave merges the
reset constant with the retained state. Both emitted forms execute on the reset
assertion edge and merge the reset constant with the enabled next value:

| Reset polarity | LunaWave | Pre-fix and corrected XSim |
| --- | --- | --- |
| Active high, reset `0xa5` | `xxxxxxxx` | `1xx00xx1` |
| Active low, reset `0x3c` | `0xx11xx0` | `xxxxxxxx` |

These are zero-based events 27 and 30 in the retained traces. The testbench
requires the exact divergence for both polarities, and then verifies binary
reset recovery. This regression establishes the stated event coverage and
preservation of the existing emitted behavior; it does not claim universal
four-state equivalence of asynchronous events. The physical PBlaze3 reset
qualifiers are binary. This fixture does not simulate MIG, XDMA, board timing,
or the separate vendor XPM reset wrapper.

The baseline DUT is a checked inverse of the two outer reset branches in the
canonical emitted DUT. It preserves each existing reset ternary exactly. The
runner also recovers the pre-fix emitter source and requires SHA-256
`3017a0e8d5cda5322722f536e6652fc746550b2db4d312618f29ddea45ac47c4`, the
identity recorded by the earlier sealed reset and integration runs. It does
not invoke an independently compiled old emitter. The corrected DUT is emitted
directly by the active standard emitter.

The completed run is retained at
`artifacts/pblaze3-reset4state-xsim-20261026-a1`. Its 42-file checksum inventory
and inventory seal verify successfully. It contains the canonical IR, both DUT
forms, recovered emitter source, generated testbench, LunaWave and XSim expected
traces, both actual traces and VCDs, and actual installed-tool identities/logs.
Compiled simulation projects remain outside evidence at
`/work/builds/pblaze3-reset4state-20261026-a1/{fixed,baseline}` on the Linux VM.

Reproduce from the repository root, selecting fresh bundle, evidence, and run
names. The runner uses the existing documented relay to the Linux build VM:

~~~sh
moon check --target native --deny-warn --warn-list +73 validation/pblaze3_reset4state cmd/pblaze3_reset4state
moon test --target native --deny-warn --warn-list +73 validation/pblaze3_reset4state
moon run --target native --deny-warn --warn-list +73 cmd/pblaze3_reset4state -- export /tmp/reset4state-new
moon run scripts/pblaze3-reset4state-xsim.mbtx /tmp/reset4state-new /ABSOLUTE/FRESH/EVIDENCE NEW-RUN-ID
~~~

For local deterministic verification against the sealed vendor traces:

~~~sh
moon run --target native cmd/pblaze3_reset4state -- verify artifacts/pblaze3-reset4state-xsim-20261026-a1 artifacts/pblaze3-reset4state-xsim-20261026-a1/fixed-actual.tsv
moon run --target native cmd/pblaze3_reset4state -- verify artifacts/pblaze3-reset4state-xsim-20261026-a1 artifacts/pblaze3-reset4state-xsim-20261026-a1/baseline-actual.tsv
~~~

The runner refuses existing output directories and guest work paths. Every
completed attempt, including simulation failures, retains its logs and gets a
checksum inventory. Existing sealed evidence is never rewritten.

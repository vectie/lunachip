# PRX100 resident BF16/FP32 layer execution

This host-only mode runs the unchanged qualified MoonBit-constructed four-lane
BF16/FP32 Qwen3-0.6B layer 0 image. Intermediate tensors remain in board DDR3,
and KV remains in on-board scratch memory. The integer core, floating-point
operators, descriptor bytes, bitstream and 25/100 MHz clocks are unchanged.

An optional explicit qualification argument between the build and new-root
arguments selects the separately qualified eight-lane throughput profile at
a 30 ns core period. The same pinned template, workload, IO and timing policy
are retained; only its bitstream-path value is substituted. Before any
hardware action, the runner checks the selected bit, source hashes, nominal
clock, queues and JTAG rate. Its `33333333` Hz label denotes the exact 30 ns
period. Invalid bit/clock/source qualifications must fail before creating a
board directory.

The resident auditor accepts optional qualified exported inputs before its
new-output argument and checks every selected source hash against them.
Without those inputs it requires the original 25 MHz qualification. The
paired throughput auditor compares fresh profiles with identical host policy
and also requires the eight-lane/unchanged-integer qualification. Hardware
changes are qualified under the throughput contract rather than inherited
from this original host-only profile.

`scripts/prx100-layer-resident-board.mbtx` takes a qualified previous board
directory, qualified Vivado build and a new board directory. It requires the
exact preceding generated Tcl identity, source-bound qualification and pinned
Vivado version. It reuses the qualified connection, programming, identity,
calibration, codec, queue and launch/error/counter procedures. Programming is
volatile. It uploads only original checkpoint assets and reads them all back
before and after the campaign. No CPU operator intermediates are uploaded.

The timed series comprises five full four-token launches, one three-token
prefill and five repeated cached position-3 decode launches. Every timed launch
includes program-count write/read, START, polling, fresh status/error and eight
counters, final hidden-state readback and CPU comparison. Only the final
1024 FP32 hidden-state words per token leave the board as tensor results.
There are no intermediate/KV tensor writes or reads inside these samples.
The same fixed token IDs and weights are repeated; this is not a stream of
different generated tokens or a demonstration of full-model inference.

Programs are uploaded and physically checked before their respective series.
Prefill/decode program switching is separately timed; it is excluded from the
program-resident launch measurement. The two setup times must be reported
alongside resident latency. Weight upload, complete input-integrity reads,
poisoning and full diagnostic snapshots are validation/setup work outside
resident samples. These exclusions define a changed execution policy, not a
hardware compute speedup or a like-for-like diagnostic harness optimization.

Three full stage/KV snapshots independently validate all operators: before
resident execution, after the five full launches and after cached decoding.
Outputs and all KV storage are poisoned before the initial full validation.
KV is poisoned again once before the resident prefill. After that prefill
starts, the host may publish the decode program and access controls, but must
not write intermediate/KV memory. The final diagnostic snapshot checks all
four tokens' intermediate tensors and K/V entries against the CPU and the
separate ordered FP32 operation model. Repeated decode overwrites position 3
and retains prefill positions 0 through 2; context remains four, capacity eight.

`prx100-layer-resident-test.mbtx` executes the actual emitted campaign with an
independent Tcl mock. It checks eleven launches, all 28 final tensors, three
diagnostic snapshots, both deliberate KV clears and retained prefill KV.
`prx100-layer-resident-audit.mbtx` independently derives every diagnostic and
final result job/burst from the fixture, checks all actual binary words against
the CPU and operation model, reconciles counters and Tcl comparison logs,
accounts for every physical transaction and rejects tensor/program transfers
inside resident sample windows. It additionally rejects any KV/intermediate
host write between prefill and the last decode. CPU tolerance remains
`1e-4 + 1e-4*abs(reference)`; all result bits must match the operation model.

Reproduce using the pinned Ubuntu/Vivado/MoonBit environment and qualified
build `/work/builds/prx100-layer-vivado-20261019-batch-phys-a2`. The source Tcl
comes from `/work/builds/prx100-layer-board-20261019-readbatch-candidate-a1`;
recover its exact files through the preceding sealed readbatch archive if
needed. Run the resident board driver with a fresh `/work/builds/prx100-layer-board-`
root, close only its identified server with `prx100-layer-close.mbtx`, and run
the independent auditor with the qualified CPU fixture, inherited operation
model and previous readbatch candidate directory. New host scripts require
native deny-warning and format checks. Native module, RTL, formal and CAD gates
are inherited only through unchanged complete source/DUT/bit identities;
compiler and CAD caches stay outside evidence archives.

# Execute the FluxTile simulation demos

## Fetched host ring path

Run from the repository root:

```sh
moon run --target native --deny-warn cmd/lunachip -- ring-demo
```

This demo uses `ring_tile(rows=2, columns=3, max_reduction=3,
host_bytes=1024, ring_depth=8, queue_depth=3)`. Host software encodes five
32-byte descriptors with the pure draft codec, writes them at aligned byte
512, configures the ring, and publishes producer count 5. Hardware fetches the
descriptors, atomically queues them, and executes LoadA/LoadB/MatMul/StoreC/Fence
through one shared host-memory port. The matrix inputs and padded addresses
are the same as in the portable example below.

The existing byte-memory environment answers observed requests with stalls
and delayed responses. It checks globally sequenced tags and stable payloads;
it contains no ring controller or matrix implementation. Each completion is
held for three clocks while the environment continues servicing descriptor
fetches into available queue capacity. Completions must arrive in order with
the expected ID, success status, and transferred-byte count.

Expected output:

```text
LunaWave FluxTile ring demo: fetched LoadA -> LoadB -> MatMul -> StoreC -> Fence
host C=[-44, 12, 66; -2005, 2328, 715] oracle=match
5 ordered successful completions; producer=5 consumer=5; descriptors fetched from host bytes
requests=181 read_bytes=175 write_bytes=24; descriptor/input/output padding preserved
modeled compute cycles=7 active=6 capture=6; shared transport backpressure and delayed responses exercised
Simulation only; provisional fetched ring and draft device ABI.
```

The 175 read bytes comprise 160 descriptor bytes and 15 operand bytes. Six
acknowledged INT32 stores account for 24 written bytes and six transactions;
the whole workload therefore uses 181 transactions. The final check compares
host result words with the independent matrix oracle and verifies every one
of the 1024 host bytes against the seeded image plus expected stores, including
descriptors and untouched padding. No internal memory is seeded or patched.
Bounded waits fail with checked errors rather than reporting unchecked success.

The counters measure the same compute-only interval as the portable example,
not total transport time or physical performance. Slot scoreboarding,
decoupled engines, ABI freeze, and complete independent-tool gates remain
later work. See [the host-ring contract](PHASE6_HOST_RING.md).

## Portable host-memory path

Run from the repository root:

```sh
moon run --target native --deny-warn cmd/lunachip -- portable-demo
```

The portable demo exercises all five serial commands in actual
`portable_tile(rows=2, columns=3, max_reduction=3, host_bytes=1024)` hardware:
LoadA, LoadB, MatMul, StoreC, and Fence. The matrices shown below are seeded
into a separate 1024-byte host-memory array. A starts at byte 32, B at byte
128, and both have eight-byte row strides. StoreC writes six little-endian
INT32 words beginning at byte 256 with a sixteen-byte result row stride.

The host environment only answers observed memory requests; it does not
calculate device results, reach into device banks/SRAM, or alter simulator
state. Request-ready is asserted on every fourth host clock. Each accepted
request gets a success response delayed by one, two, or three clocks in a
repeating pattern; its payload remains held until response acceptance. The
environment checks tags, sizes, masks, aperture bounds, one-outstanding
transaction discipline, and request stability under backpressure. Each of
the five completions is held for two further clocks before acknowledgement.

Expected output:

```text
LunaWave FluxTile portable demo: LoadA -> LoadB -> MatMul -> StoreC -> Fence
host C=[-44, 12, 66; -2005, 2328, 715] oracle=match
5 successful completions; requests=21 read_bytes=15 write_bytes=24; padding preserved
modeled compute cycles=7 active=6 capture=6; transport backpressure and delayed responses exercised
Simulation only; provisional serial transport, not a frozen device ABI.
```

The independent matrix oracle is called only after StoreC and Fence complete.
The check reads the host words, not accumulator outputs, and compares all
1024 host bytes against the seeded inputs plus expected result words. This
also detects unintended writes and changes to row padding. Successful output
requires exact completion identities/status/progress, 21 acknowledged
transactions, 15 operand bytes read, 24 result bytes written, actual injected
request stalls and response delays, and no pending work at completion. A
bounded wait raises a checked error if any command fails to complete.

The seven compute cycles exclude load/store transport, command frontend,
completion backpressure, and six separate result-capture edges. Six active
Run edges include fill and drain; they do not claim full array utilization.
These are modeled clocks, not host wall-clock or physical throughput.
See [the portable transport contract](PHASE6_PORTABLE.md) for the exact
provisional faults, reset barrier, and evidence limits.

## Standalone execute path

Run from the repository root:

```sh
moon run --target native --deny-warn cmd/lunachip -- matmul-demo
```

The demo elaborates `execute_tile(rows=2, columns=3, max_reduction=3)` and
simulates the canonical hardware IR in LunaWave. It resets the controller,
loads signed INT8 operands through the standalone bank-write handshakes,
submits matrix command 42, inserts two Run stalls, verifies the held
completion, and acknowledges it to return the controller to Idle.

The input matrices are row-major:

```text
A = [   1, -2,   3 ]    B = [   5, -6,   7 ]
    [ -128,  4, 127 ]        [   8,  9, -10 ]
                            [ -11, 12,  13 ]
```

Expected output:

```text
LunaWave FluxTile execute demo: signed INT8 M=2 N=3 K=3
C=[-44, 12, 66; -2005, 2328, 715]
completion id=42 fault=0 oracle=match
modeled execution cycles=9 active=6 stalls=2; completion held for 2 cycles
Simulation only; provisional execute slice, not a complete device ABI.
```

The hardware owns synchronous reads, wavefront addressing, state transitions,
signed multiplication, and INT32 accumulation. The host only supplies input
stimulus and independently checks the final results with `matmul_int8_oracle`.
The demo fails with a checked error on a wrong handshake, status, counter, or
result instead of printing success for an unchecked run.

Six accepted Run advances include array fill and drain; they are not six
fully utilized multiplication cycles. The nine modeled execution cycles are
one Clear edge, six accepted Run edges, and two Run stalls. Reset, operand
loading, command acceptance, and two held-completion edges are excluded from
that per-command elapsed counter. These are deterministic simulation counts,
not measured wall-clock performance or a physical-frequency claim.

This makes the provisional execute slice usable, but does not implement a
command ring, DMA, store controller, descriptor ABI, or dependency scoreboard.
It provides no independent Verilator, synthesis, formal, FPGA, or silicon
evidence. See [the standalone execute contract](PHASE6_EXECUTE.md) and
[the Phase 6 implementation slices](PHASE6_IMPLEMENTATION.md) for the remaining
device work.

The default invocation and `counter` still print the original bootstrap smoke
output. `help`, `-h`, and `--help` list the supported commands. The CLI's
white-box tests cover command dispatch and run the complete hardware demo;
the hardware package's black-box tests independently cover its public API.

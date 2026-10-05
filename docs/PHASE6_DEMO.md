# Execute the FluxTile simulation demos

## Fetched concurrent host path

Run from the repository root:

```sh
moon run --target native --deny-warn cmd/lunachip -- ring-concurrent-demo
```

This uses `ring_concurrent_tile(rows=8, columns=8, max_reduction=16,
host_bytes=1024, ring_depth=4, queue_depth=8)`. Host software encodes actual
draft-0.2 descriptors into host bytes. Hardware fetches them, queues them and
dispatches the existing concurrent engines through one three-client bus.
The four physical ring slots are reused only after observed consumer
advancement, not after command retirement.

The demo establishes A1/B1 and C0, then publishes an unrelated A0 reload,
C0 store, A1/B1-to-C1 MatMul, C1 store and Fence. All eight commands use caller
ID 42. Accepted operand reads and result writes must coincide with advancing
compute or capture; descriptor-read overlap is counted separately. The oldest
completion is held for 24 clocks while the host continues servicing traffic.

Expected output:

```text
LunaWave FluxTile fetched concurrent demo: real draft 0.2 host descriptors
C0=8x8 C1=8x8 signed INT8 K=16 oracle=match
8 ordered successful completions with duplicate caller ID=42; producer=8 consumer=8
accepted DMA during advancing compute/capture: operand_read_edges=4 store_write_edges=5 descriptor_read_edges=5
requests=768 read_bytes=640 write_bytes=512; all 1024 host bytes checked, padding preserved
oldest completion held for 24 cycles; ring slots reused only after consumer advancement
Simulation only; provisional fetched concurrent device, not hardware performance.
```

Both 8x8 results are checked against the independent signed INT8 K=16 oracle.
Every one of the 1024 host bytes is checked against the seeded image, actual
descriptor publications and expected stores, including untouched padding.
Output reports acknowledged transport totals and observed overlap, not
physical performance. No internal device memory or state is seeded or patched.
The draft ABI and independent RTL/synthesis/formal gates remain unfinished.
See [the fetched concurrent contract](PHASE6_RING_CONCURRENT.md).

## Queued concurrent packet path

Run from the repository root:

```sh
moon run --target native --deny-warn cmd/lunachip -- concurrent-demo
```

This uses `queued_concurrent_tile(rows=8, columns=8, max_reduction=8,
host_bytes=1024, queue_depth=8)` with the separate draft-0.2 slotted codec.
It first establishes C0 and complete A1/B1 loads, then queues an unrelated A0
reload, C0 store and A1/B1-to-C1 MatMul, followed by C1 store and Fence. All ten
commands use caller ID 42; internal tickets keep ordered retirement distinct.
The same byte-memory environment supplies actual stalls/delayed responses.

Expected output:

```text
LunaWave FluxTile concurrent demo: draft 0.2 packets with bounded ordered retirement
C0=[-44, 12, 66; -2005, 2328, 715]; C1=8x8 oracle=match
10 ordered successful completions with duplicate caller ID=42
observed DMA/compute overlap: read_edges=7 write_edges=5
oldest completion held for 24 cycles; later stores committed 12 bytes during hold
requests=277 read_bytes=207 write_bytes=280; all 1024 host bytes checked, padding preserved
modeled compute cycles=23 active=22 capture=64; transport backpressure and delayed responses exercised
Simulation only; provisional queued concurrent engine, not hardware performance.
```

Overlap counts require an accepted external request and an advancing Run or
capture counter on the same clock edge; they are not inferred from busy flags.
All result words are compared with the independent oracle, and all 1024 host
bytes are checked against inputs plus expected stores, including padding.
The observer excludes counter reset from advancement. Bounds and held payloads
fail with checked errors. This packet demo does not fetch descriptors from a
host ring or claim frequency, bandwidth, physical throughput or ABI freeze.
See [the queued concurrent contract](PHASE6_QUEUED_CONCURRENT.md).

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
not total transport time or physical performance. This legacy fetched-ring
path remains serial/single-slot; use `ring-concurrent-demo` for the separate
concurrent device. ABI freeze and complete independent-tool gates remain later
work. See
[the host-ring contract](PHASE6_HOST_RING.md).

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

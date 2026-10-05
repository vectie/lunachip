# Execute the FluxTile simulation demo

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

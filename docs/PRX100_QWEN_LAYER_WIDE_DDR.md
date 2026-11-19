# PRX100 complete-layer native-width DDR transport

This opt-in profile carries four ordered 32-bit words per weight response from
the DDR bridge through the target controller into the four-lane BF16/FP32
layer machine. `export-wide` selects all three matching generators. The prior
`export-transfer` profile and the integer accelerator remain unchanged.

The matching public generators are
`@qwen_layer.wide_layer_machine()`, `@prx100_layer.wide_controller()` and
`@prx100_layer_ddr.wide_bridge()`. The evidence-only
`@prx100_layer_ddr.wide_bridge_evidence()` returns the same ordinary bridge and
references to existing control nodes. To emit a complete matching target, run:

```sh
moon run --target native cmd/prx100_layer -- export-wide /absolute/new-inputs
```

## Transport and storage

An aligned 128-byte weight request carries `request_wide=1` in addition to the
existing read/line/burst flags. It returns eight packets, each containing four
32-bit words, one shared fault field and LAST on packet seven. Unmarked bursts
retain 32 single-word responses. Host reads, writes, full-line writes and scalar
fallback retain their existing formats. The controller latches ownership and
the width flag before forwarding the request and checks the corresponding
physical packet count. Only the overlap loader issues marked requests.

The native MIG interface and its eight-command reservation remain unchanged.
Thirty-two reserved word registers absorb all eight unstallable 128-bit native
returns. The emitter advances by four words for a marked request. Faulted
suffixes drain with zero data and a shared nonzero fault; previously queued
packets remain stable. Loss of calibration poisons the bridge until coordinated
reset. A job reset does not independently reset CDC endpoints.

The canonical asynchronous FIFO primitive supports payloads up to 64 bits.
This target therefore uses four checked response FIFOs with coordinated reset.
A registered reservation verifies space in every source FIFO before publishing
a shared write pulse. Another reservation verifies a readable entry in every
destination FIFO before publishing a held response. There is no independent
writer or reader that can spend those reservations. All four transfers advance
together, including under backpressure. These reservations permit one packet
per two core edges, a theoretical 200 MB/s payload ceiling at 25 MHz; this is
not a measured native-DDR bandwidth claim. The UI side admits at most one packet
per two UI edges. CDC Gray-pointer synchronizers retain explicit physical
ASYNC_REG/SHREG_EXTRACT annotations for all 22 stage vectors.

Each ping-pong weight stripe has four subword memories per output lane. One
packet writes all four banks on the same edge. Computation reads the bank
selected by the low packed-word index; the selector is delayed with the
one-cycle synchronous ReadOld/HoldLast read. BF16 half selection and the
three-stage FP32 multiplier are unchanged. Accumulation preserves the original
per-row K order and separate round-to-nearest-even multiply/add operations.
Only a complete stripe becomes active; delayed arithmetic tokens cannot revive
a terminal fault. `ddr_beats` continues counting logical 32-bit words, including
the existing store acknowledgements, rather than physical wide packets.

## Validation boundary

Native tests exercise distinct packet words, multiple stripes and row groups,
scalar fallback, repeated starts, reset prefixes, stalled source/destination,
native return gaps, eight outstanding commands, malformed LAST and transport
faults. Independent RTL replays cover the exact emitted core and bridge.
Pinned synthesis checks the complete generated digital composition for cycles.
Bounded formal tasks retain exact production identities, assumptions, depths,
observation-only views and sensitivity counterexamples. These are digital
prefix checks, not unbounded, analog CDC or full-job proofs.

Physical qualification requires strict routed setup/hold/pulsewidth closure,
the same 25 MHz core/100 MHz UI/6 MHz JTAG clocks and a fresh baseline/candidate
campaign. The workload, CPU reference, host driver and all raw stage/KV
readbacks retain the prior complete-layer benchmark boundaries. Measurements
and final qualification status belong in the task evidence report.

Physical qualification and the fresh CPU-verified complete-layer A/B campaign pass; see [the measured evidence](evidence/prx100-layer-wide-20261019.md).

# PBlaze3 AXI memory bridge

`bridge()` constructs a LunaWire module for a **2GiB byte-addressed aperture**.
It retains the Qwen request semantics while replacing PRX100's native MIG port
with an AXI4 master. It is a single-clock implementation. The board shell must
provide an AXI clock converter between its core clock and the vendor MIG port.

```mbt check
///|
test {
  assert_eq(@pblaze3_axi.bridge().name(), "Pblaze3AxiBridge")
}
```

## Request and response contract

Requests use ready/valid. The bridge latches the complete request on acceptance
and owns it until the last response is accepted. There is no second outstanding
source request. Responses hold every payload bit, fault, wide and last marker
under backpressure.

| Request | Alignment | Response |
|---|---:|---|
| Scalar read/write | 4 bytes | One word/one write acknowledgement |
| `line=1` read/write | 16 bytes | Four serial words/one write acknowledgement |
| `line=burst=1` read | 128 bytes | 32 serial words |
| `line=burst=wide=1` read | 128 bytes | Four eight-word responses |
| Above plus `data[31]=1` | 128 bytes | 16 rows, each128 bytes;64 eight-word responses |

For sixteen-row reads, `data[30:0]` is a nonzero,128-byte-aligned byte stride.
The complete inclusive extent `address + 15*stride +127` is checked in36 bits
against `0x80000000` before any AXI request. Scalar/line/burst alignment ensures
their complete extent fits whenever the base address is inside the aperture.
Malformed shapes, unaligned requests and out-of-range addresses issue no bus
traffic and return the response count implied by the canonical read flags.

`request_address` is32 bits. Input write data is `request_data` and
`request_data1..3`. Output read data is `response_data` and
`response_data1..7`; only lane0 is meaningful for serial replies. The other
lanes are zero. Write acknowledgements and faulted replies return zero in all
eight lanes. `response_last` ends the request. `response_wide` distinguishes
eight-word delivery from a serial reply.

With `store_bursts=true` on the 1024-bit target, a write with
`line=burst=1, wide=0` consumes 64 FP32 words. Present them on
`request_fill_data` with `request_fill_valid` and consecutive
`request_fill_index` values 0 through 63 while the bridge is idle.
The accepted request consumes the buffered group. It requires a
256-byte-aligned base inside the 2 GiB aperture. The bridge issues
one INCR address, two full-strobe 128-byte data beats, and one response
after the AXI B handshake. Missing words or malformed addresses return
fault 1. Independent AW and W stalls preserve the address and data.

## Qwen streaming interface

The 256-bit image uses `bridge(streaming=true)`. The 512-bit image uses
`bridge(streaming=true, wide512=true)`. Both use a 40 MHz compute clock,
a 200 MHz MIG user clock and a 64-bit DDR3-1600 bus on this board.

A wide read describes one 128-byte row or sixteen strided rows.
Each row needs four AXI beats at 256 bits or two at 512 bits. The bridge
uses the same ID for these INCR bursts and can
issue sixteen row addresses before data returns. Each row starts on a
128-byte boundary and fits inside one 4 KiB page. The original aperture and
stride checks run before the first address is published. An elastic register
returns eight or sixteen little-endian words per accepted core beat and holds each
packet stable under backpressure. Scalar and line operations use an aligned
32- or 64-byte transfer with word selection or byte write strobes. Descriptor layout,
FP32 accumulation order and the controller's result ABI are shared by both
targets.

The routed PBlaze3 crossbar accepts eight reads from the accelerator and can
issue eight to MIG. A limit of sixteen in the bridge lets the same RTL tolerate
a deeper downstream queue. At one accepted beat on every compute edge, the
two ports carry 1.28 and 2.56 GB/s respectively. At the MIG clock the same
widths give 6.4 and 12.8 GB/s. The configured DDR pin rate is 12.8 GB/s
in both images. See [the board measurements](../../docs/PBLAZE3_WEIGHT_CLOCK.md).

On a read or framing fault the bridge poisons the transport, retains a held
AXI address until accepted and drains the source's remaining replies as
faults. A successful reply already held under backpressure stays stable.
Coordinated reset clears the transport and its outstanding transactions.

## Legacy 128-bit AXI boundary

The master issues one aligned16-byte beat per AXI transaction:
`AxLEN=0`, `AxSIZE=4`, `AxBURST=INCR`, `WLAST=1`. Single-beat transactions cannot
cross4KiB boundaries. AW and W are independently held until accepted; the bridge
waits for B before acknowledging a write. A scalar write uses one of the four
32-bit-lane strobe masks, preserving the remaining12 bytes. A line write uses
all16 byte strobes. Reads wait for R before issuing the next transaction.

The128-bit data bus is split into four32-bit ports to fit LunaChip's current
simulation value representation. The board wrapper connects
`m_axi_rword0..3` and `m_axi_wword0..3` to AXI lanes `[31:0]` through `[127:96]`.
The wrapper supplies ID zero, normal nonexclusive access and fixed attributes;
the adapter has one outstanding transaction and requires that its own responses
are routed back to it by the AXI interconnect. AXI-Lite control is separate.

This implementation prioritizes correct board bring-up. It has eight words of
read buffering, serial AXI issue and no cache. It does not promise the former
PRX100 bridge's read-ahead throughput or peak MIG bandwidth.

## Reset and faults

`reset` is active-high synchronous in `clock`. **Reset must coordinate the
adapter, AXI converter/interconnect and MIG transaction state.** A compute-job
reset must not independently reset this bridge while an AXI operation is live.
Clearing only the bridge can discard an AW or W half and associate a later
response with the wrong request. The source must also forget its old owner on
the same transport reset. Reset does not undo writes already committed to DDR.

| Fault | Meaning | Recovery |
|---|---|---|
| 0 | Successful transfer | Continue |
| 1 | Malformed request or address extent | Next request may proceed |
| 2 | Calibration unavailable, lost, or bridge poisoned | Initial calibration may complete; a poisoned bridge requires coordinated reset |
| 3 | Non-OKAY R/B response or missing single-beat RLAST | Coordinated reset |

Calibration loss after calibration was observed, and AXI response faults,
set sticky `bridge_poisoned`. `memory_healthy` requires calibration and no poison.
Faulted stream replies drain the remaining source response count as zeros.
Earlier accepted replies retain their earlier successful status.

Calibration loss never withdraws already-presented AXI AW/W/ARVALID. If the
transaction completes, its response reports fault2; if the MIG stops responding,
the host must time out and perform coordinated transport reset. No wall-clock
timeout is embedded in the hardware. A malformed RLAST poisons the link; recovery
requires resetting the responder too, since no additional read beat is expected
for this single-beat protocol. The bridge does not guess ownership of unsolicited
R/B responses and holds READY low outside its matching owned transaction.

## Validation

`validation/pblaze3_axi` provides native simulation tests, a deterministic
100000-edge independent-RTL replay and a40-edge bounded safety harness. Safety
properties cover ownership, address range/alignment, single outstanding AXI
transactions, independent channel hold, response hold, write strobes and poison.
The negative harness deliberately imposes an incorrect256MiB aperture.
The tests include high-address aliases, the last2GiB word/row, large row strides,
malformed requests, independent AW/W stalls, read/write errors, calibration loss
and reset during partial transactions. These artifacts do not establish physical
DDR stability, clock-domain correctness, board pin correctness or routed timing.

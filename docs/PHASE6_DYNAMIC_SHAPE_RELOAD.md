# Dynamic shape reload on the 8 by 8 device

This fixed workload checks useful subarray computation, a non-power-of-two
reduction capacity and exact-shape reloads on the existing 8x8 accelerator.
It reuses the canonical device, fetched ring, replay exporter and pinned
Verilator comparison. It adds no hardware port, command encoding, simulator
semantic, runner, planner or receipt format. The workload is supporting
Phase 6 evidence; it cannot close the remaining formal obligations.

## Device and command sequence

Use rows 8, columns 8, maximum reduction 17, host memory 4096 bytes, ring depth
4 and queue depth 3. The ring starts at byte 3072 and wraps while ten commands
execute. Caller IDs are 501 through 510 in public retirement order.

| Commands | Shape and slots | Host layout |
| --- | --- | --- |
| LoadA, LoadB | A1 is 3x17; B0 is 17x5 | A base 512, stride 23; B base 768, stride 11 |
| MatMul, Fence | 3x5/K17, A1/B0 to C0 | no host data transfer |
| LoadA, LoadB | reload A1 as 8x1; reload B0 as 1x8 | A base 1152, stride 5; B base 1280, stride 16 |
| MatMul | 8x8/K1, A1/B0 to C1 | no host data transfer |
| StoreC, StoreC, Fence | C0 remains 3x5; C1 is 8x8 | C0 base 1536, stride 28; C1 base 2048, stride 44 |

The first Fence orders operand reloads after the original computation. The
second computation must not destroy C0: both result slots are stored only
after it. Exact stored shapes remain distinct from the physical array size.
Mixed A/B selectors and a changed C selector exercise existing slot routing.

## Independent acceptance criteria

Initialize every host byte to a sentinel, then populate only declared operand
rectangles and published ring slots. Operands include signed int8 extrema,
zero, positive and negative values. Compute expected results with the existing
pure row-major signed oracle, independently of simulator or RTL internal state.
Audit all 4096 host bytes, including operand and output padding, ring contents
and untouched regions. The two stores contain 15 and 64 int32 words, little
endian. Verify all 79 words, not a checksum or selected subset.

Require all ten public completions in order, with fault and fault address zero.
Expected completed byte counts are 51, 85, 0, 0, 8, 8, 0, 60, 256 and 0.
Expected request and acknowledgement counts are 551: 320 descriptor bytes,
152 operand bytes and 79 word writes. This is 472 read bytes and 316 write
bytes. Reject reads outside descriptor/operand ranges and writes into padding
or outside exact output word starts.

For the 3x5/K17 compute, require 23 accepted steps, 23 active cycles, 24 elapsed
cycles, zero stalls and 15 capture cycles. The 8x8/K1 compute requires 15,
15, 16, zero and 64 respectively. These are expectations derived from the
existing controller schedule, not measured performance claims.

## Execution and claim boundary

Add only an additive validation fixture and its existing CLI selector. Run
focused native generation and oracle tests, then export a deterministic replay
and compare every cycle of all 30 public outputs through the unchanged pinned
Verilator path. Keep all older replay artifacts byte-identical. Serialize
compilation, tests and external engines; agents may author and review isolated
source concurrently. Retain original failures as well as successful retries.

Native generation and its self-audit are not independent RTL agreement.
Acceptance requires actual pinned lint, build, execution and typed replay
audit. Even successful finite agreement does not prove general shape safety,
engine ownership, whole-Store leases, arbitration, public fairness or eventual
completion, and does not replace any unchanged Phase 6 formal gate.

The [completed checkpoint](evidence/phase6-shape-reload-20261006.md) passes
15 affected native tests on clean `aad4b60`, preserves all 121 older replay
artifacts and matches all 117510 public observations through the unchanged
pinned RTL path. The 530-file support inventory retains the native, export
and actual RTL evidence. This fixed-workload acceptance does not close the
remaining full-device formal gates.

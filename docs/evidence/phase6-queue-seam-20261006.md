# Direct queue observation seam

The direct 1x1/K2/host1024/queue-depth-three FluxTile device now exposes 115
typed construction references for supporting queue-conservation checks.
Checkpoint `58ed2d80ef890d86489386617e5b9929f4a107f8` passes all 832 native
tests, including three focused seam tests and its checked public example.
The ordinary hardware and separate 48-reference dependency view are unchanged.
These are native construction and simulation results, not a formal proof.

## Existing hardware references

The [observation contract](../PHASE6_QUEUE_CONSERVATION.md) names 36 FIFO,
16 head, nine retirement, 39 entry and fifteen engine references. Every role
resolves uniquely to an existing canonical node with the exact ground type,
including signedness and width. Register and synchronous memory-read kinds
are checked where required. Different roles may intentionally reference one
node; emitted names resolve through the backend manifest rather than guessed
ordinals or hierarchy.

The fixed observed fixture and ordinary constructor produce equal complete
modules, canonical IR and emitted SystemVerilog. Repeated construction is
deterministic. All ten memories and the public output roster remain intact;
the old dependency inventory stays exactly 48. Existing pre-queue and pre-ring
canonical digest tests also pass in the full native suite. Metadata adds no
hardware node, register, memory or ABI port. It therefore adds no modeled
device cycle or hardware state; host elaboration cost was not benchmarked.

## Actual ownership transitions

A bounded LunaWave replay admits six real packets with the same caller ID 73:
LoadA, LoadB, MatMul, StoreC, an unused-field Fence rejection and a valid Fence.
Independent admission order and actual tickets zero through five distinguish
the commands. All four lane pushes, pops, synchronous responses and captured
head lanes agree with their admitted packets. Reservation, entry allocation,
engine acceptance, matching collectors, pointer/count updates and ordered
acknowledgements are checked before and after actual clock edges.

With the oldest successful `(73,0,2,0)` completion held, all first three entries
become terminal, the retirement table remains full, the fourth packet waits
unreserved in the head and two packets remain in the FIFO. Sixteen consecutive
quiet edges preserve that state and payload without new host requests. Drainage
then retires all six obligations in ticket order, with engine collector counts
`[2,1,1]` and two local terminals. Five genuine host requests load `[2,3]` and
`[5,7]` and store the independent result 31. Final queue and retirement
occupancies are zero, with no pending host response or shared halt.

## Native evidence and remaining gates

The focused tests pass 3/3. Interface generation, formatting, strict native
checking including warning 73, all 832 native tests, default CLI smoke and
dependency/source-size boundaries pass. Targeted logs are at
`/private/tmp/lunachip-queue-seam-evidence-20261006.rP91TT`.
One successful targeted child run was accompanied by a wrapper source-context
failure because its design documentation changed during execution; that
attempt is retained as `queue-tests-consecutive-source-drift`. The subsequent
same tests pass with unchanged recorded source context.

The full native result is the completed first stage of the fresh aggregate at
`/private/tmp/lunachip-phase5-aggregate-20261006.mGNRt3`: its native stdout
records `Total tests: 832, passed: 832, failed: 0.` and its aggregate log records
`EXIT native 0`. The aggregate's source HEAD and complete input manifest bind
the clean checkpoint above. Its nine independent child gates are still a
separate pending result; a native stage does not complete Phase 5.

The next [structural supporting tasks](../PHASE6_QUEUE_CONSERVATION.md#first-supporting-task-scope)
check actual-DUT lane/population/retirement relations with a full/refill cover
and comparison-only sensitivity control. Packet identity, engine ownership,
immutable terminal payloads, leases, fairness and the original production
safety tasks remain separate obligations. No fetched-device, 8x8 formal,
complete Phase 6, physical RAM, timing, power or silicon claim follows.

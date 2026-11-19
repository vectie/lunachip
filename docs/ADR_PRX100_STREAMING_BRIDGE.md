# ADR: keep the streaming response seam in the existing DDR bridge builder

Status: accepted for the PRX100 streaming experiment, 2026-10-19.

The existing DDR bridge is one deterministic MoonBit hardware builder. Its
native command, source ownership, fault drainage and CDC state share many
signals. The streaming profile changes only the response-FIFO construction;
it leaves the arithmetic core, controller and legacy bridge generators intact.

Keep that builder in `targets/prx100_layer_ddr/bridge.mbt`, currently 836 lines.
This is an explicit exception to the 800-line limit. Most of the small increase
is an observation-only walk over the finished module's FIFO metadata. Keeping
that walk next to the existing observations makes both banks of four FIFO
identities reviewable alongside the exact instantiated design. The actual
response-path implementation remains in the focused `wide.mbt` file.

Do not add unrelated features to this builder. A future structural refactor
should extract cohesive construction stages and demonstrate byte-identical IR
and RTL for every legacy profile before changing this exception.

## Bounded read-ahead continuation, 2026-10-20

Extend this exception for the related opt-in four-row read-ahead profile.
Counter geometry, emission limits and native address selection belong beside
the existing shared owner/fault state. Balanced buffer selection and offset
advancement live in focused `read_ahead.mbt`; replay tests and formal additions
remain separate. Avoid a simultaneous structural refactor of the qualified
legacy FSM. Require byte-identical legacy IR/RTL, exact unchanged core/controller
sources, and the [read-ahead gates](PRX100_QWEN_LAYER_READ_AHEAD.md). The exception
does not authorize unrelated additions or altered clock/reset semantics.

## Eight-row continuation, 2026-10-20

Extend the same exception for the related fixed eight-row target. Elaboration
selects wider counters, a 256-word reserved return buffer, the eight-row extent
check and the corresponding LAST limit in the existing shared state machine.
The [eight-row contract](PRX100_QWEN_LAYER_EIGHT_ROW.md) requires its matching
core/controller and fresh digital/physical gates. Existing profiles retain
their exact graphs. This exception does not cover arithmetic changes or a
general transport redesign.

## Aligned extent continuation, 2026-10-20

The opt-in aligned eight-row profile adds only a Boolean specialization seam
to the existing builder. Its focused address helper explicitly removes seven
alignment bits from the extent arithmetic while retaining complete packet
shape, alignment, reserved-bit and zero-stride rejection. No packet encoding,
clock/reset, owner state, FIFO geometry or cycle contract changes. Extend the
exception for this seam; require exact legacy graphs, an actual canonical-IR
full-header equivalence miter with a boundary negative, fresh bridge replay and
formal checks, and a new physically qualified image. The helper and miter stay
in the focused address files rather than increasing the shared state machine.

## Sixteen-row continuation, 2026-10-21

Extend the exception for the related fixed sixteen-row owner, reserving 128
native returns in the existing state machine. Counter widths, buffer capacity
and terminal counts stay adjacent to their existing ownership and fault logic;
the aligned extent helper and property specialization remain in focused files.
The [sixteen-row contract](PRX100_QWEN_LAYER_SIXTEEN_ROW.md) requires matched
core/controller selection, exact legacy exports and all fresh digital/physical
gates. No unrelated feature, timing exception or clock/reset change is covered.

## Eight-word response continuation, 2026-10-22

Extend the exception for the matched feedback/delivery profile. The existing
sixteen-row owner still reserves 128 native lines. Only its response width
changes: two returned native lines form one eight-word core packet, and the
available-data predicate must cover both lines before publication. Each of two
CDC banks now joins eight independently checked FIFO flags. Packet counters
continue to count logical words; bounds and native memory traffic are unchanged.
Keep these width-dependent conditions beside the existing owner/fault state,
with FIFO construction in `streaming.mbt`. Require fresh ordering, backpressure,
reset, fault, differential and formal gates and byte-identical legacy exports.
The [feedback contract](PRX100_QWEN_LAYER_FEEDBACK.md) defines this experiment.
The aligned eight-word buffer selector stays in focused `delivery.mbt`; the
builder selects it only for the delivery profile and retains the scalar path.
The proof bundle adds the alignment invariant without removing prior checks.

# Packet composition: original storage and native correspondence

This is a finite construction/correspondence checkpoint, not a packet safety
theorem, solver witness or Phase 6 pass. The clean native source is
`8739f77d94c954b5dcac7d93cb0880b96ec78b3a`.

## Exact scope

The ordinary direct 1x1/K2/host1024/q3 hardware remains unchanged, with
canonical source digest
`35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc`.
The private projection retains 54 original registers (876 bits), four actual
depth-three Bits64 arrays (12 cells, 768 bits), and four actual held registered
read results (256 bits): 1,900 storage bits. It does not initialize SRAM to
zero. Its 101 shared raw cuts are twelve original public inputs and 89 foreign
register outputs. No derived readiness, transfer, memory-read result or
retirement record is cut.

Raw foreign producer values are arbitrary. Consequently, this boundary can
support packet/control safety but does not establish physical Store/DMA data,
numerical matrix correctness or full-device execution.

The reviewed candidate inventory is
`01275b9792d9f2bd9bbb9b026a8de861931b0821dc9634f4439fa9f1c391e7b2`.
At this checkpoint the complete 200-output projection report is
`87d925d7869f46a370e9333ceb64d52765ef3486eeabe3013b0d867317b8b4fd`,
and its projected IR is
`237579372143194a2c7002e5f887a70dedf54c9be71e8eec9000bbb4fed6455f`.
These last two pins describe this checkpoint, not the subsequent formal-input
repair described below.

## Actual comparison

The existing real records and storage workloads gained surgical private
correspondence hooks. At each PRE, they copy the complete raw `LogicValue`
planes into the projection; the original advances exactly once, and the
projection advances using its own saved PRE cuts. No retained register or
memory cell is forced from the original after advancement.

Every PRE and POST compares all 101 cuts, 54 registers, four held reads, twelve
cells, 115 observations and all 23 ordinary public outputs.

| Workload | Actual PRE/POST pairs | Retained exercised behavior |
| --- | ---: | --- |
| Retirement records | 109 / 109 | Eight admissions/captures/reservations, engine acceptance and collection counts [2,1,1], four local terminals, seven retirements, 36 held edges, two full refills, eight admissions with caller ID 73, two resets and a fresh admission/reservation/retirement |
| FIFO wrap/reset | 100 / 100 | 26 admissions, 23 captures, 22 reservations, 22 local terminals, 19 retirements, 21 held edges, 17 changed full refills, read wraps [7,7,7,7], write wraps [8,8,8,8], two resets retaining all twelve cells and a fresh fence |

Each workload observes startup unknowns in all 54 roots and 89 foreign cuts,
with twenty unknown read samples and sixty unknown cell samples. The original
workload assertions and counters remain in place.

## Validation and preserved history

The actual working and clean checkpoints pass the required strict native check
and all three targeted tests. Clean `moon info` and `moon fmt` also pass;
working and clean test stdout are byte-identical. This is targeted validation,
not a fresh full-module matrix.

The support retains the original 100-cut drafts, the final 101-cut source
report, and unsuccessful command history. An optional extra warning-73 check
found two existing unnecessary qualifiers; it is not the repository's required
strict gate. Two initial filename-as-filter invocations ran zero tests and
are explicitly excluded from acceptance.

The complete 333-file support is retained at
`/private/tmp/lunachip-packet-composition-native-20261007.SbjZUc` and mirrored
under `.phase6-packet-composition-native-evidence-20261007`. Both seals verify,
and the complete directory comparison is identical. The top-level manifest
digest is `c29bc72dfe47547d21666e37eef88dbc0d0b25598dd5f5ae3c0f772ff100aec4`.

## Subsequent formal-input reachability repair

At `ffa5dbd`, RTL export exposed an unused selected original response-data
input. The private projection now aliases that existing Bits32 cut as the
formal-only output `public_input_memory_response_data`. This makes the
original host-response stability premise bindable without changing ordinary
hardware, nodes, state, cuts, memories or source maps. It increases private
outputs from 200 to 201; the two projection pins above are superseded for
later formal inputs.

The repaired projection and seven-property proof-input sources pass fourteen
targeted tests at clean `c77e159`. The committed eight-artifact exporter passes
its actual one-test collector at clean `ad22f65`, with preview and clean bytes
identical. Its current projected IR is
`7995da5bc996c05c08f1ba44eeaf5ccf6ba99573c5025f1aeb2d6fb7c785747d`,
and complete report digest is
`02b394e9b7f93b66303d3c8a32cd5485dce9fe5afb5bf4bbd942157bd9dd7375`.
These later input checks are distinct from the sealed 333-file native
checkpoint. Solver execution and prepared-model/trace qualification are
recorded separately; construction, export and native agreement cannot stand
in for them.

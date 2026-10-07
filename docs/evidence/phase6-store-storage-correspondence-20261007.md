# Exact Store storage and finite PRE/POST correspondence

The Store projection retains original control and complete reached storage,
abstracting only four shared arithmetic production values. Structural tests and
a real native overlap/reset workload pass from clean committed source. This
checkpoint is not a preservation theorem or completed Phase 6 gate.

## Source and actual boundary

Projection source: `b3907c0ed3547e13f8ebac41b22cc2202fc66f62`.
Correspondence source: `eb3cb93d7f07910ab15d43c9a30069b225cb8680`.
Both pass strict native check; four structural tests and one correspondence
test pass. Clean and preview report/workload stdout are byte-identical.

The original ordinary direct 2x2/K2/host1024/q3 IR digest remains
`69b9a4a97b7ee2b050ad46d93ffe1786a54e09a932c431db30afc9255aa09f4a`.
Projection digest:
`874d37ad994ddff3aa3f70a68e9d0423e4c0ba5da0b9dce97f3c927fdacd5582`.
Complete 10,668-line report digest:
`5dc7bace2583d1bb5e6d357f4207564cf824237010fd0e3aa5f788c9768c5e25`.

Measured projection: 2,349 nodes, 16 inputs, 162 registers / 2,427 bits,
six memories / 1,024 cell bits, six read states / 320 bits, 274 outputs and one
clock domain. The memories contain **20 cells**: eight C cells and twelve
packet FIFO cells. The four arithmetic cuts total 128 bits. No foreign control,
event, progress or memory-read payload becomes a free input.

The full fixed point follows register next/reset/enable and every reached
memory's complete read/write ports, masks and clocks. All 48 essential Store
roots, eleven original DMA-arbiter roots, 83 observations and ordinary public
outputs remain. Independent structural tests compare exact remapped operations,
register controls, complete memory specifications, source-order mappings,
startup unknown storage and same-count adversarial source/plan drift.

## Actual workload

At every sample, mirror only ordinary selected public inputs and the four raw
production arithmetic `LogicValue`s, including unknown masks. Compare all
retained registers, SRAM cells, read states, observations, public outputs and
clock/time identity. Both simulators commit using unchanged PRE values; refresh
arithmetic cuts only after both commits.

The run records 426 PRE and 426 POST comparisons, two reset edges, eleven public
admissions and ten retirements. A real delayed Loader transaction owns the bus
while C0's indexed read is pending. Opposite-C1 computation then performs one
inner admission and all four captures, including final capture, before Store
grant. C0's old response remains unchanged. Pending-read protection is
same-C-slot only; no impossible all-slot stall is assumed.

After the actual Loader ACK, the first public Store offer stalls for three
edges. Seventeen byte-read ACKs and eight four-byte write ACKs pair with actual
accepted host requests. Both complete output matrices and the entire host byte
image match the independent signed oracle:
old C0 `[53,73,93,129]`, fresh C1 `[38,48,13,-55]`.
All caller IDs repeat as 73; request addresses, masks, tags and row strides are
checked individually.

Later reset occurs during a genuine unaccepted Store Offer, with Store still
in Request(2), not Wait(3). All twenty SRAM cells and six held read states retain
their exact data/masks; control and result validity clear. A fresh Fence admits
and retires afterward. Unknown comparison samples include 162 register, four
arithmetic, 1,102 read and 2,740 cell samples; startup storage is not zeroed.

## Sealed evidence and limits

Projection support `/private/tmp/lunachip-store-projection-native-20261007.MYRGE4`
mirrors `.phase6-store-projection-evidence-20261007/`: 200 files, manifest digest
`bdfd32b6bae5d53219a6e683189d079da91f32171761c56771a18fda1d9592ae`.
Correspondence support
`/private/tmp/lunachip-store-correspondence-native-20261007.FrOKme` mirrors
`.phase6-store-correspondence-evidence-20261007/`: 143 files, manifest digest
`df6edc94eeb59d7fa2dda9758fcd8f6819967a0cc3cff30de0de6e2db575f5d8`.
Both support/mirror inventories verify and compare exactly. Failed draft
checks, repaired source, complete reports and actual command records remain.

Independent source review accepts the structural boundary and finite workload.
No solver, universal preservation/lease-release result, numerical MatMul proof,
independent RTL replay or completion deadline result is supplied by this slice.
The supporting Store theorem and remaining Phase 6 composition still follow.

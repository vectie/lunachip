# Original two-client DMA arbiter discovery checkpoint

Design commit `5a0efbd` and implementation commit
`aa9425a1209c38270b1b22abc0a4f3c7c68a0f0f` complete private discovery for the
[original DMA arbiter design](../PHASE6_DMA_ARBITER_LEMMA.md). Clean targeted
tests pass 155/155 and all 190 preceding exported artifacts remain byte-identical.
This accepts an inspected discovery inventory, not sequential materialization,
simulation correspondence, proof inputs or an arbiter theorem.

## Exact original inventory

The fixed direct 1x1/K2/host1024/q3 accelerator retains production IR SHA-256
`35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc`.
Discovery follows original public drivers and register-next equations rather
than ordinal selection or a replacement controller. Public interfaces and
production hardware remain unchanged.

Eleven original registers/172 bits retain state, owner, preference, next and
expected global tags, saved local tag, write, address, byte count, mask and data.
Each complete original specification records rising clock node 0/domain 0,
synchronous active-high zero reset node 1, next expression, absent enable and
absent initial value. Seventeen distinct derived events retain grant, selection,
request/response acceptance, routing, malformed checking and poison equations.
Duplicate-but-equivalent original Wait and malformed nodes are not merged.

Twenty-two semantic boundary records contain fifteen nonconstant candidates
and seven original constants. Raw client request fields/tag/readiness and public
bus peers are component boundaries; internal grant or acceptance is not a cut.
The seven constants retain distinct original identities inside the 81-node
combinational closure, rather than becoming symbolic freedoms. An independent
reviewer reconstructs the complete closure and compares it with original LCIR;
every operand belongs to the cone, eleven roots or fifteen candidates.

The retained extracted inventory has 54 lines/7,218 bytes and SHA-256
`cc867599656fda1bc3897b42d971feb75736de72e22112a6ef1d0364af32d138`.
Full test stdout includes the trailing test summary and has a different SHA-256,
`42c7764c5b5c3100f260c1cf37eeaad8c4fc7a530a148a48d9316f4e7fc87ea7`;
the initial and clean full stdout are byte-identical. Root and independent review
accept discovery only. The report still labels its cuts unreviewed candidates;
no accepted projection or premise is emitted.

## Source-bound native validation

The clean detached checkout is
`/private/tmp/lunachip-queue-control-composition-native-20261007.pnlu45`, at the
exact implementation commit above. Interface generation, formatting, strict
native checking with warning 73 enabled, 155 targeted tests, report inspection,
native exporter build and artifact comparison all exit zero. Every clean command
records unchanged full HEAD and empty source status before/after. Four new tests
cover inventory, structural rejection and independently reconstructed source
identity/closure; report reruns are not additional unique tests. The full native
module matrix is not rerun and no external HDL compiler or formal engine runs.

Fresh exports preserve all 190 preceding artifact bytes and hashes without
normalization: 153 ordinary artifacts, 13 generation inputs, six compute inputs,
six queue-control inputs, six monitor inputs and six ownership inputs. Exact
membership is checked without relying on directory enumeration order. The
existing exporter and public package interfaces do not change.

The support retains the initial native check failure (reserved `local`, exit
255), its four initial sources and successful `saved_local` correction. A pure
helper split produces the final five focused files without semantic changes.
The initial report collector fails compilation (iterator/array mismatch, exit
1); its source/logs are retained and the corrected read-only extraction exits
zero without rerunning tests or exports. The disposable coordinator emits two
deprecation warnings in the outer interactive console, not product checks; its
exact used source is retained, but that console is not a raw retained log.
No unsuccessful check is relabeled successful.

## Retained evidence and next scope

Fresh support root:
`/private/tmp/lunachip-dma-arbiter-native-20261007.cvqihx`.
Repo-local retained copy: `.phase6-dma-arbiter-native-evidence-20261007`.
Both inventories verify all 540 files, with manifest SHA-256
`3524b2690302b5dc1bf8eb6b401e971bdc283f34402e78eba7f880dc852ee6fa`.
Recursive comparison is exact excluding disposable `_build`/`.mooncakes` caches.
The support contains initial/final sources, complete child command logs,
comparison inventories, report, work attempts and independent review summary.
Preceding sealed evidence is unchanged; the user's untracked codec test remains
unchanged.

Next implement exact sequential materialization, original-device PRE/POST
correspondence, then reviewed observer conclusions and proof-input export.
Local induction and comparison-only stalled-payload sensitivity remain pending.
This checkpoint does not discharge Store leases, DMA cursor/address bounds,
storage/provenance/generation composition, nested memory, fetched transport,
fairness or the full 8x8 formal gate. It makes no performance, FPGA, fabrication
or silicon claim.

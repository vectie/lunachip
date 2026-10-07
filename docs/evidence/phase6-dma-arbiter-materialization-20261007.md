# Original two client DMA arbiter sequential materialization

Implementation commit `ae84d152a15c4960a1b08e26146642e5fe6306fc` materializes
the [reviewed original arbiter inventory](phase6-dma-arbiter-native-20261007.md).
Clean targeted tests pass 157/157 and all 190 preceding artifacts remain
byte-identical. This accepts exact sequential materialization and startup-state
tests, not actual-device correspondence or an arbiter theorem.

## Exact checked module

The private checked module has 108 nodes: eleven original registers/172 bits,
one original clock input, fifteen reviewed nonconstant named inputs and all 81
original combinational nodes. Twenty-eight outputs alias the eleven original
state roots and seventeen derived events. Seven distinct original constant
boundaries remain operations rather than symbolic freedoms. There is one rising
clock domain, no memory or CDC primitive, and no added observer, controller,
assertion or premise.

Before copying, the materializer pins the complete reviewed report SHA-256
`cc867599656fda1bc3897b42d971feb75736de72e22112a6ef1d0364af32d138`
without newline normalization, checks original register/interface/cone identities
and recomputes closure. Source-order mapping is fully allocated before copying
forward register-next references. Original signal types, clock edges, synchronous
reset specifications, enables, initial values and derived operations are preserved
through the explicit original-to-local ID map. Only the fifteen reviewed raw
boundaries become `cut_n<original ordinal>` inputs.

An independent test remaps every actual cone operation without invoking the
implementation's shared kind-remapping helper. It compares every original node's
membership, type and mapping, full register specifications, constants and aliases.
Repeated serialization is deterministic and original production hardware is
unchanged. A second test confirms all retained registers remain fully unknown
before sampled reset, with no implicit initialization. Production IR SHA-256
remains `35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc`.
Root and independent review accept this exact sequential component.

## Committed source validation

The clean detached checkout
`/private/tmp/lunachip-queue-control-composition-native-20261007.pnlu45` is at the
complete implementation commit above. Interface generation, formatting, strict
native checking with warning 73 enabled, all 157 targeted formal/CLI tests,
native exporter build, exact comparison of 190 prior artifact bytes and source
hashing each exit zero. All fourteen clean before/after status records are empty
and all fourteen HEAD records match the exact commit. Both new focused tests pass;
they are included in, not additional to, the 157-test total. The full native
module matrix is not rerun.

Compatibility includes the unchanged ordinary, generation, compute, queue-control,
monitor and ownership inputs. There is no new exporter, public interface, proof
input or production hardware change. No external HDL compiler or formal engine
runs in this checkpoint.

The initial strict check exits 255 with one Array/ReadOnlyArray comparison type
error (4014). Root corrects only the comparison to use two ReadOnlyArrays with
exact equality; the corrected check exits zero. Initial/final sources and all
command logs are retained. Formatting makes no semantic change. No failed run is
relabeled successful and no collector or engine rerun is needed.

## Retained evidence and next scope

Fresh support root:
`/private/tmp/lunachip-dma-arbiter-materialization-native-20261007.SMXb8o`.
Repo-local copy: `.phase6-dma-arbiter-materialization-evidence-20261007`.
Both verify all 479 retained files, with manifest SHA-256
`3c53a4373101a8a6bce784483a512369f68dc4073a97d910176118995d8df7ca`.
Recursive comparison is exact excluding disposable build caches. Previous
sealed evidence and the user's untracked codec test remain unchanged.

Next compare all eleven roots and seventeen events at actual PRE/POST edges,
mirroring all fifteen foreign LogicValues while preserving startup unknowns.
Finite public-stimulus transcripts must reach real contention, stalled Offer,
response consumption, poison and reset recovery without forcing internal state.
Only then add reviewed observer conclusions, export inputs and run local
induction plus comparison-only sensitivity. Larger DMA/memory, Store, storage,
provenance/generation composition, fetched transport, fairness and full 8x8
obligations remain open; no performance or physical implementation claim follows.

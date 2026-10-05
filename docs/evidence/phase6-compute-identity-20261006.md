# Exact compute identity checkpoint

Implementation commit: `5d53a55`, parent `ee99121`. The native commands ran
against the parent with the exact checkpoint changes recorded in their
before/after Git status; source-context guards passed. The changes were then
committed without intervening edits. This is extraction and native behavior
evidence, not an authorization or full-device formal proof.

## Implemented boundary

The private materializer retains nine original compute registers, 80 state
bits, one original clock domain, no memories and 15 observation outputs.
There are 31 nonstate cuts totaling 606 bits, plus the clock input. Register
next expressions, synchronous resets, enables and arbitrary initial values
are copied exactly. Actual admission, Issue/Done and saved terminal ticket
remain derived; no free ComputeAccept or completion-ready input is introduced.

The source and tests follow [the compute identity design](../PHASE6_COMPUTE_IDENTITY.md).
The isolated tests intentionally vary generation, preflight and core boundary
inputs. They check held Issue identity, wrong-ticket/core-fault handling,
preflight failure, reset priority and discovery corruption. Three full-device
regressions separately check genuine accepted identity through retirement,
a younger writer's generation change, preflight failure and reset interruption.
They do not claim that stalled inner ready or wrong-ID core completion is
reachable in the unchanged full fixture.

## Validation

Interface generation and formatting completed. Strict native checking passed,
including warning73. The formal package passed 84/84 tests and the complete
native suite passed 808/808. Default CLI smoke and dependency/source-size
boundaries passed. Independent source review found no blocker in admission,
identity capture/hold, FSM/fault priority or exact register copying.

Fresh exports compare byte-for-byte and by SHA256 with the retained
[generation bridge checkpoint](phase6-generation-bridge-20261006.md): thirteen
generation artifacts plus 46 artifacts across the four ordinary dependency
bundles. The shared register-copy refactor therefore leaves the earlier proof
inputs and ordinary emitted bundles unchanged. No solver or formal engine ran
at this checkpoint; unchanged inputs are not a new proof result.

Comparison inventory SHA256:
`ad5bcd83ad8a88c4cdb3c25ab47d7c63d955424ca899864f423c3b881671da73`.

## Retained evidence

Original evidence directory:
`/private/tmp/lunachip-compute-identity-20261006.ooRjNs`.

Verified byte-identical workspace copy:
`/Users/kq/Workspace/lunachip/.phase6-compute-identity-evidence-20261006`.

The copy contains 162 inventoried files: command logs and source-context
records, the nine committed checkpoint sources, source review, fresh export
artifacts, comparison records and MoonBit retention scripts. Build caches and
unverified staged composition work are excluded. The aggregate inventory is
`outputs.sha256`, with SHA256:
`d3bfdf4ae34f1b3c9d8dfc347a35ac9d3119bce9b51b34094293d6f2fc64d57f`.
The source/copy inventories, every retained byte/digest and the 59-artifact
comparison inventory were verified after copying.

## Remaining work

Generation inputs are still free in this isolated controller. Joint retention
of the original generation and compute registers, independent saved owner/
authorization reference and actual induction are required before claiming
saved authorization. Load/store owners, core/SRAM, arithmetic, FIFO,
retirement, leases, ticket wrap, fairness and full safety remain outside this
checkpoint. No public API, CLI, fixture task, receipt, runner or normative
phase gate changed.

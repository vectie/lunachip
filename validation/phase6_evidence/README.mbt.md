# Phase 6 evidence reconciliation

This package represents the validated fetched Store existential cover without
promoting it to universal safety, an SBY execution receipt or a Phase6 pass.
The original cover task remains byte-identical at1024 global steps. A derived
bounded-cover task records the actual Bitwuzla0.9.1 basis retrieval and concrete
original-model validation through global839, retaining the original source-set,
eight assumptions, selected property and timing contract.

`FetchedStoreArchives::checked` and `FetchedStoreWitnessReceipt::checked` are
pure identity checks against exact reviewed artifacts, not filesystem checks.
The collector verifies every file in all three pinned directories, rejects
extra files and links, and rechecks after reading the receipt inputs. Its new
output directory contains the original task, derived task, typed formal cover
result, receipt, partial aggregate and complete output inventory.

~~~sh
moon run scripts/phase6-fetched-receipt.mbtx --target native --deny-warn --target-dir /Users/kq/Workspace/lunachip/_build/automation -- collect /Users/kq/Workspace/lunachip /absolute/new/output
~~~

The underlying `cmd/phase6-evidence encode-fetched-store` command only encodes
content-bound records. It does not verify complete archives by itself; use the
collector above for published acceptance evidence.

Exit0 means collection succeeded, not that Phase6 passed. The aggregate lists
four open obligation groups; these are not an estimate of remaining tasks.
It does not recollect the separately accepted Store and packet safety proofs
or claim a same-snapshot full regression. Historical failed retrievals and BMC
timeouts remain unchanged in their original archives.

The witness manifest refers to all concrete basis fields and all840 complete
state definitions plus pinned original-model and native/causal validations.
Unknown initial memory, undefined high address bits, free tail inputs and
native known masks are preserved; no equation, assumption or hardware changes.

PBlaze3 host/campaign rehearsal, 2026-10-28

29 host scenarios and 14 campaign scenarios passed against the retained source snapshot. No physical device was accessed. The unchanged full-layer fixture passes offline preflight with 27 assets, 80 traces and 2025 descriptors.

The campaign now uploads and byte-verifies quiet-NaN poison (0x7fc00000) in every output trace before START, and rejects overlap with immutable assets. CPU references must be finite; comparison tolerances remain 1e-4 absolute plus 1e-4 relative. Missing and partial STORE cases start from exactly correct stale DDR, accept START and complete, then fail specifically NonfiniteFloat. The partial case verifies its first three stored words and remaining NaN word. A dropped poison upload fails byte readback before START. Positive mock results are written only after accepted START.

Launch cases include two busy observations before delayed DONE; one torn sequence retried; persistently torn status rejected; accepted-launch fault, health loss, reset sequence and wrong completed count rejected. Negative cases require specific diagnostics and absent success markers. Timeout retains emitted native stderr and TimeoutError. The independent async-stdio logging fixture additionally checks both unterminated streams; native println may remain buffered inside a killed child.

Portable campaign dispatch accepts paired absolute PBLAZE3_HOST_RUNNER_WASM/PBLAZE3_MOONRUN paths. Missing pairs and relative paths fail before board access; successful portable relocation is a separate host-agent gate.

Full result traces, per-command logs, expected-error receipts, and mock state are retained here. Regenerable executable symlinks are omitted; source and executable identities are recorded. Existing sealed archives were not modified. Earlier unsealed rehearsal paths remain in place: a1/a2 strengthened diagnostics found generic subprocess errors, a3 overlapped a host-script edit, a4 exposed native stdout buffering, a5 passed before a context-only qualifier cleanup; a6 is the exact final passing run.

These are software transport/orchestration checks. Physical DDR geometry, PCIe/JTAG and accelerator execution still require the board.

# ADR: retain the PRX100 layer command dispatcher during qualification

The PRX100 layer CLI in `cmd/prx100_layer/main.mbt` currently has 830 lines.
This is a limited exception to the 800-line guide. It exposes versioned export,
replay, reference and formal commands whose historical invocations are retained
in sealed board evidence. The contiguous-weight experiment adds an explicit
profile rather than changing the meaning of an existing command.

Keep this dispatcher stable during the measured hardware comparison. Arithmetic,
core construction, replay generation, formal harnesses and reference execution
remain in their owning files and packages. A later mechanical extraction should
separate export helpers from dispatch and prove byte-identical outputs for every
retained profile. Do not add unrelated features under this exception.

The 2026-10-22 feedback experiment adds only selection seams to the existing
export helper. New experiment command routing stays in `feedback_commands.mbt`,
and the standalone arithmetic timing export stays in `feedback_unit.mbt`.
Every historical command must retain its previous emitted identity.

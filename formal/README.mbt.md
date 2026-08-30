# LunaChip formal artifacts

This package owns the deterministic boundary between LunaChip properties and
external formal tools. It does not invoke Yosys, SymbiYosys, an SMT solver, or
an engine; orchestration supplies a content-addressed RTL artifact and records
the exact external tool result through these checked types.

Property export consumes the existing `wave/property` identities. Every
property has an explicit rising-edge pre-state clock domain and an explicit
disable behavior. The emitted conservative SVA uses case equality: a predicate
passes or covers only when known one, and an asynchronous disable suppresses a
property only when known one. Signal names come exclusively from checked
bindings to the SystemVerilog emitter; the formal package never guesses them.

Bounded and unbounded evidence use different task and result types. In
particular, `BoundedProofOutcome` has no `Proved` constructor and the bounded
serializer has no `proved` code path:

```mbt check
///|
test "bounded evidence cannot become an unbounded proof claim" {
  let artifact = @formal.ArtifactRef::checked(
    "rtl/top.sv", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  let tool = @formal.FormalTool::checked("sby", "0.60.0")
  let task = @formal.BoundedProofTask::checked(
    "fifo safety",
    artifact,
    tool,
    "smtbmc boolector",
    BoundedSafety,
    @formal.ProofBound::checked(32),
    ["lc_p0_b617373756d65"],
    ["lc_p1_b73616665"],
  )
  let result = @formal.BoundedProofResult::checked(task, BoundedPass)
  assert_true(result.to_canonical_text().contains("RESULT bounded-pass\n"))
  assert_false(result.to_canonical_text().contains("RESULT proved\n"))
}
```

Both task and result parsers are strict: accepted input must reserialize to the
same bytes. Result manifests repeat the human-readable task fields and bind
them to the SHA-256 of the standalone task manifest. A safety counterexample
or cover witness cannot be represented without its own checked artifact name
and SHA-256.

See `FORMAT.md` for the versioned wire formats. Untimed tasks and all current
proof results remain schema 1; explicit multi-clock task timing uses schema 2.

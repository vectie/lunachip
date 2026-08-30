///|
test "IR failures map to stable diagnostic codes and semantic paths" {
  let invalid_width = @diagnostic.from_ir_error(InvalidWidth(0))
  inspect(invalid_width.code().stable_id(), content="LC0001")
  assert_true(invalid_width.semantic_path().is_root())
  let cycle = @diagnostic.from_ir_error(CombinationalCycle([3, 4, 3]))
  inspect(cycle.code().stable_id(), content="LC0005")
  debug_inspect(
    cycle.semantic_path().segments(),
    content=(
      #|<ReadOnlyArray: [Node(3)]>
    ),
  )
}

///|
test "IR diagnostic adapters preserve caller source spans" {
  let start = @diagnostics.SourcePosition::new(2, 4, 8)
  let end = @diagnostics.SourcePosition::new(2, 9, 13)
  let span = @diagnostics.SourceSpan::new("generator.mbt", start, end)
  let diagnostic = @diagnostic.from_ir_error(
    UnknownNodeId(9),
    primary_span=span,
  )
  inspect(diagnostic.code().stable_id(), content="LC0002")
  inspect(
    diagnostic.primary_span().unwrap().source_id(),
    content="generator.mbt",
  )
}

///|
test "toggle handshake domain failures use a domain-role path" {
  let diagnostic = @diagnostic.from_ir_error(
    UnknownToggleHandshakeDomain(
      primitive=2,
      role="destination_domain",
      domain=99,
    ),
  )
  inspect(diagnostic.code().stable_id(), content="LC0002")
  debug_inspect(
    diagnostic.semantic_path().segments(),
    content=(
      #|<ReadOnlyArray:
      #|  [Operation("toggle_handshake"), Field("destination_domain")]>
    ),
  )
}

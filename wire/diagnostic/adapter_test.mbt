///|
test "wire driver failures map to stable codes and paths" {
  let duplicate = @diagnostic.from_wire_error(DuplicateDriver("result"))
  inspect(duplicate.code().stable_id(), content="LC0003")
  debug_inspect(
    duplicate.semantic_path().segments(),
    content=(
      #|<ReadOnlyArray: [Port("result")]>
    ),
  )
  let missing = @diagnostic.from_wire_error(UndrivenRegister(4))
  inspect(missing.code().stable_id(), content="LC0004")
}

///|
test "foreign references and builder lifecycle have distinct stable codes" {
  inspect(
    @diagnostic.from_wire_error(ForeignSignal).code().stable_id(),
    content="LC0002",
  )
  inspect(
    @diagnostic.from_wire_error(BuilderFinished).code().stable_id(),
    content="LC0017",
  )
}

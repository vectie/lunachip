# Formal negative fixtures

The black-box tests in `formal_test.mbt` construct a valid canonical artifact
first and then make one controlled mutation. This keeps each negative fixture
bound to the current schema instead of allowing stale hand-written examples to
pass for the wrong reason.

Covered negative fixtures include a bounded result relabeled `proved`, a
missing mandatory counterexample artifact, a mismatched task-manifest digest,
uppercase SHA-256, path traversal, trailing records, duplicate property/signal
identities, unresolved bindings, and result/task-mode mismatches.

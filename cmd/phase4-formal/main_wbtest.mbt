///|
test "output digest parser binds an exact safe path and digest" {
  let hash = "a".repeat(64)
  let records = parse_output_digests(
    "\{hash}  task-work/status\n\{"b".repeat(64)}  tool-versions.txt\n",
  )
  assert_eq(records.length(), 2)
  require_output_digest(records, "task-work/status", hash)
  try require_output_digest(records, "other/status", hash) catch {
    _ => ()
  } noraise {
    _ => fail("substring or absent path must not satisfy an exact binding")
  }
}

///|
test "output digest parser rejects unsafe and noncanonical records" {
  let hash = "a".repeat(64)
  for
    malformed in [
      "\{hash} ../status\n",
      "\{hash}  ../status\n",
      "\{"A".repeat(64)}  status\n",
      "\{hash}  status",
      "\{hash}  status\n\{hash}  status\n",
    ] {
    try parse_output_digests(malformed) catch {
      _ => ()
    } noraise {
      _ => fail("malformed output digest record must be rejected")
    }
  }
}

///|
test "source set fixture identity is typed" {
  let artifacts = @gate.regenerate_formal_artifacts(
    "LUNACHIP-PHASE4-FORMAL-SOURCE-SET 1\nFIXTURE broken-bounds\nEND\n",
  )
  assert_true(artifacts.any(artifact => artifact.path() == "job.json"))
  try
    @gate.regenerate_formal_artifacts(
      "LUNACHIP-PHASE4-FORMAL-SOURCE-SET 1\nFIXTURE forged\nEND\n",
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("unknown fixture identity must be rejected")
  }
}

///|
fn references() -> Array[@formal.ArtifactRef] raise {
  [
    @formal.ArtifactRef::checked(
      "phase6-fetched-basis-certificate-20261015/files.sha256", "ec86792f2a6bb02030d823f7816fad6f5abd16ef62579a37a42366a1009d237e",
    ),
    @formal.ArtifactRef::checked(
      "phase6-fetched-useful-20261013/files.sha256", "29f55cce2e8fec214d02e801e1950143be5bd7d22315f3d9212451278d98b516",
    ),
    @formal.ArtifactRef::checked(
      "phase6-fetched-packed-retrieval-20261015/files.sha256", "e7db5c1d23b9b00d9b782162a5327458165c85c73117abfba0600a3154416755",
    ),
  ]
}

///|
fn archives() -> @phase6_evidence.FetchedStoreArchives raise {
  let refs = references()
  @phase6_evidence.FetchedStoreArchives::checked(refs[0], refs[1], refs[2])
}

///|
fn original() -> String raise {
  @fs.read_file_to_string(
    "validation/phase6_evidence/fixtures/original-cover.lcft",
  )
}

///|
fn summary() -> String raise {
  // The JSON fixture is newline-terminated for source control. The immutable
  // acceptance artifact was emitted by stringify without a final newline.
  @fs.read_file_to_string(
    "validation/phase6_evidence/fixtures/validated-witness.json",
  )
  .strip_suffix("\n")
  .unwrap()
  .to_owned()
}

///|
fn receipt() -> @phase6_evidence.FetchedStoreWitnessReceipt raise {
  @phase6_evidence.FetchedStoreWitnessReceipt::checked(
    archives(),
    original(),
    summary(),
  )
}

///|
test "validated cover has its actual method and bound without changing original task" {
  let receipt = receipt()
  let original = receipt.original_task()
  let result = receipt.result()
  let derived = result.task()
  assert_eq(original.bound().cycles(), 1024)
  assert_eq(original.engine(), "smtbmc-bitwuzla")
  assert_eq(derived.bound().cycles(), 840)
  assert_eq(derived.mode(), BoundedCover)
  assert_eq(derived.tool().name(), "Bitwuzla")
  assert_eq(derived.tool().version(), "0.9.1")
  assert_eq(
    derived.engine(),
    "independent-field-basis-and-concrete-original-model-validation",
  )
  assert_eq(derived.artifact(), original.artifact())
  assert_eq(derived.assumptions(), original.assumptions())
  assert_eq(derived.properties(), original.properties())
  assert_eq(derived.timing_contract(), original.timing_contract())
  guard result.outcome() is CoverWitness(witness) else { fail("cover only") }
  assert_eq(
    witness.sha256(),
    "ec86792f2a6bb02030d823f7816fad6f5abd16ef62579a37a42366a1009d237e",
  )
  assert_eq(
    @formal.parse_proof_result(result.to_canonical_text()),
    BoundedResult(result),
  )
  assert_false(result.to_canonical_text().contains("RESULT proved"))
  assert_true(receipt.to_canonical_text().contains("unknown-bits517-unpinned"))
}

///|
test "changed scope assumptions mode or bounds cannot become an accepted receipt" {
  let task = original()
  for
    changed in [
      task.replace(old="BOUND 1024", new="BOUND 840"),
      task.replace(old="MODE bounded-cover", new="MODE bounded-safety"),
      task.replace(old="ASSUMPTIONS 8", new="ASSUMPTIONS 7"),
      task + "PASS\n",
      "",
    ] {
    try
      @phase6_evidence.FetchedStoreWitnessReceipt::checked(
        archives(),
        changed,
        summary(),
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("altered task accepted")
    }
  }
}

///|
test "altered witness summary cannot change unknown or address semantics" {
  let summary = summary()
  for
    changed in [
      summary.replace(
        old="\"native_unknown_bits_unpinned\": 517",
        new="\"native_unknown_bits_unpinned\": 0",
      ),
      summary.replace(old="\"store_address\": 768", new="\"store_address\": 0"),
      summary.replace(
        old="\"original_state_count\": 840",
        new="\"original_state_count\": 839",
      ),
      summary.replace(old="\"phase6_pass\": false", new="\"phase6_pass\": true"),
      summary + "\n",
    ] {
    assert_not_eq(changed, summary)
    try
      @phase6_evidence.FetchedStoreWitnessReceipt::checked(
        archives(),
        original(),
        changed,
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("altered summary accepted")
    }
  }
}

///|
test "archive role and digest substitution fail closed" {
  for index in 0..<3 {
    let refs = references()
    let correct = refs[index]
    for
      wrong in [
        @formal.ArtifactRef::checked("other/files.sha256", correct.sha256()),
        @formal.ArtifactRef::checked(
          correct.name(),
          "0000000000000000000000000000000000000000000000000000000000000000",
        ),
      ] {
      refs[index] = wrong
      try
        @phase6_evidence.FetchedStoreArchives::checked(
          refs[0],
          refs[1],
          refs[2],
        )
      catch {
        @phase6_evidence.IdentityMismatch(_) => ()
      } noraise {
        _ => fail("archive substitution accepted")
      }
    }
  }
}

///|
test "partial aggregate cannot promote a cover to universal safety or phase completion" {
  let aggregate = @phase6_evidence.Phase6EvidenceAggregate::with_fetched_store(
    receipt(),
  )
  assert_false(aggregate.phase6_passed())
  assert_eq(@phase6_evidence.remaining_gates(), [
    FetchedSymbolicSafetyAddressAndDependency,
    ExplicitFairness8x8Completion,
    RemainingWorkloadFaultAndSynthesisMatrix,
    SameSnapshotFinalNativeAndToolAggregate,
  ])
  let text = aggregate.to_canonical_text()
  assert_true(text.contains("STATE incomplete\n"))
  assert_true(text.contains("PHASE6-PASS false\n"))
  assert_true(
    text.contains("prior-failures-and-timeouts-retained-not-replaced"),
  )
  assert_false(text.contains("STATE passed"))
}

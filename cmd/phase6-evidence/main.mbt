///|
fn hash(text : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text)))
}

///|
// Identity encoder only. The .mbtx collector verifies complete directories;
// this command deliberately does not claim filesystem or execution validation.
fn records(repository : String) -> Array[(String, String)] raise {
  guard repository.has_prefix("/") else { fail("absolute repository required") }
  let names = [
    "phase6-fetched-basis-certificate-20261015", "phase6-fetched-useful-20261013",
    "phase6-fetched-packed-retrieval-20261015",
  ]
  let refs = names.map(name => {
    @formal.ArtifactRef::checked(
      name + "/files.sha256",
      hash(
        @fs.read_file_to_string(
          repository + "/artifacts/" + name + "/files.sha256",
        ),
      ),
    )
  })
  let archives = @phase6_evidence.FetchedStoreArchives::checked(
    refs[0],
    refs[1],
    refs[2],
  )
  let original = @fs.read_file_to_string(
    repository +
    "/artifacts/" +
    names[1] +
    "/bundle/phase6-flux-tile-fetched-useful-store-r1-h1-c1-cover-write-ack-retirement.lcft",
  )
  let summary = @fs.read_file_to_string(
    repository + "/artifacts/" + names[0] + "/validated-witness.json",
  )
  let receipt = @phase6_evidence.FetchedStoreWitnessReceipt::checked(
    archives, original, summary,
  )
  let result = receipt.result()
  assert_eq(
    @formal.parse_proof_result(result.to_canonical_text()),
    BoundedResult(result),
  )
  let aggregate = @phase6_evidence.Phase6EvidenceAggregate::with_fetched_store(
    receipt,
  )
  assert_false(aggregate.phase6_passed())
  [
    ("original-task.lcft", original),
    ("validation-task.lcft", result.task().to_canonical_text()),
    ("cover-result.lcfr", result.to_canonical_text()),
    ("receipt.lcwr", receipt.to_canonical_text()),
    ("aggregate.lcpa", aggregate.to_canonical_text()),
  ]
}

///|
fn encode(repository : String, destination : String) -> Unit raise {
  guard destination.has_prefix("/") else {
    fail("absolute new output required")
  }
  guard !@fs.path_exists(destination) else { fail("output already exists") }
  let files = records(repository)
  @fs.create_dir(destination)
  for (name, content) in files {
    @fs.write_string_to_file(destination + "/" + name, content)
  }
  println(
    "IDENTITY-ENCODED fetched-Store-cover; full archive verification requires the .mbtx collector; PHASE6 incomplete",
  )
}

///|
// Consume the saved typed result, then reconcile the saved receipt and
// aggregate against the exact expected records. No solver status is inferred.
fn read_back(repository : String, directory : String) -> Unit raise {
  let actual = @formal.parse_proof_result(
    @fs.read_file_to_string(directory + "/cover-result.lcfr"),
  )
  guard actual is BoundedResult(result) && result.outcome() is CoverWitness(_) else {
    fail("saved bounded cover result required")
  }
  for (name, expected) in records(repository) {
    guard @fs.read_file_to_string(directory + "/" + name) == expected else {
      fail("saved record mismatch: " + name)
    }
  }
  println(
    "RECORDS-RECONCILED typed-cover-receipt-and-partial-aggregate; PHASE6 incomplete",
  )
}

///|
fn main raise {
  match @env.args() {
    [_, "encode-fetched-store", repository, destination] =>
      encode(repository, destination)
    [_, "verify-fetched-store-records", repository, directory] =>
      read_back(repository, directory)
    _ =>
      fail(
        "usage: phase6-evidence encode-fetched-store REPOSITORY NEW_OUTPUT | verify-fetched-store-records REPOSITORY RECORD_DIRECTORY; use scripts/phase6-fetched-receipt.mbtx for complete archive verification",
      )
  }
}

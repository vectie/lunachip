///|
pub suberror WitnessReceiptError {
  IdentityMismatch(String)
}

///|
fn digest(text : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text)))
}

///|
fn require_identity(
  actual : String,
  expected : String,
  role : String,
) -> Unit raise WitnessReceiptError {
  if actual != expected {
    raise IdentityMismatch(role)
  }
}

///|
/// Exact reviewed archive identities. File contents must be verified against
/// these inventories by the collector; this pure constructor performs no I/O.
pub struct FetchedStoreArchives {
  basis : @formal.ArtifactRef
  native : @formal.ArtifactRef
  packed : @formal.ArtifactRef
}

///|
pub fn FetchedStoreArchives::checked(
  basis : @formal.ArtifactRef,
  native : @formal.ArtifactRef,
  packed : @formal.ArtifactRef,
) -> FetchedStoreArchives raise WitnessReceiptError {
  for
    (actual, name, pin) in [
      (
        basis, "phase6-fetched-basis-certificate-20261015/files.sha256", "ec86792f2a6bb02030d823f7816fad6f5abd16ef62579a37a42366a1009d237e",
      ),
      (
        native, "phase6-fetched-useful-20261013/files.sha256", "29f55cce2e8fec214d02e801e1950143be5bd7d22315f3d9212451278d98b516",
      ),
      (
        packed, "phase6-fetched-packed-retrieval-20261015/files.sha256", "e7db5c1d23b9b00d9b782162a5327458165c85c73117abfba0600a3154416755",
      ),
    ] {
    require_identity(actual.name(), name, "archive name")
    require_identity(actual.sha256(), pin, name)
  }
  { basis, native, packed, }
}

///|
/// A later receipt for the validated compressed existential witness, not an
/// SBY receipt. All original search and historical runner results stay intact.
pub struct FetchedStoreWitnessReceipt {
  archives : FetchedStoreArchives
  original : @formal.BoundedProofTask
  result : @formal.BoundedProofResult
}

///|
/// Bind the exact archived task and acceptance summary to reviewed inventories.
/// This constructor checks identity and result taxonomy, not filesystem state.
/// Use the collector to verify all archive bytes before publishing the receipt.
pub fn FetchedStoreWitnessReceipt::checked(
  archives : FetchedStoreArchives,
  original_task : String,
  validated_summary : String,
) -> FetchedStoreWitnessReceipt raise {
  require_identity(
    digest(original_task),
    "69038350695dc9f2672fbcfad427bec6b3cb9b72f125c13e11eaeff9f7727f63",
    "original cover task",
  )
  require_identity(
    digest(validated_summary),
    "37b8aa4694a6bf607995b47b484d213848106688924b4372273e9ecca5efe52a",
    "validated witness summary",
  )
  guard @formal.parse_proof_task(original_task) is Bounded(original) else {
    raise IdentityMismatch("bounded original task required")
  }
  guard original.mode() == BoundedCover &&
    original.bound().cycles() == 1024 &&
    original.assumptions().length() == 8 &&
    original.properties().length() == 1 &&
    original.timing_contract() is Some(timing) else {
    raise IdentityMismatch("original cover scope")
  }
  let validation = @formal.BoundedProofTask::checked(
    original.name() + "-validated-basis",
    original.artifact(),
    @formal.FormalTool::checked("Bitwuzla", "0.9.1"),
    "independent-field-basis-and-concrete-original-model-validation",
    BoundedCover,
    @formal.ProofBound::checked(840),
    original.assumptions(),
    original.properties(),
  ).with_timing_contract(timing)
  let result = @formal.BoundedProofResult::checked(
    validation,
    CoverWitness(archives.basis),
  )
  { archives, original, result, }
}

///|
pub fn FetchedStoreWitnessReceipt::original_task(
  self : FetchedStoreWitnessReceipt,
) -> @formal.BoundedProofTask {
  self.original
}

///|
pub fn FetchedStoreWitnessReceipt::result(
  self : FetchedStoreWitnessReceipt,
) -> @formal.BoundedProofResult {
  self.result
}

///|
pub fn FetchedStoreWitnessReceipt::to_canonical_text(
  self : FetchedStoreWitnessReceipt,
) -> String {
  let out = StringBuilder()
  out.write_string("LUNACHIP-PHASE6-FETCHED-STORE-WITNESS-RECEIPT 1\n")
  out.write_string("SCOPE fetched1x1-K2-host1024-ring4-q2-directed-R1-H1-C1\n")
  out.write_string("METHOD validated-compressed-existential-cover-not-SBY\n")
  out.write_string(
    "ORIGINAL-TASK sha256 \{digest(self.original.to_canonical_text())}\n",
  )
  out.write_string("RESULT sha256 \{digest(self.result.to_canonical_text())}\n")
  for
    (role, archive) in [
      ("BASIS", self.archives.basis),
      ("NATIVE", self.archives.native),
      ("PACKED-PREDECESSOR", self.archives.packed),
    ] {
    out.write_string("\{role} \{archive.name()} sha256 \{archive.sha256()}\n")
  }
  out.write_string(
    "MODEL sha256 50cbbb2cb91dcaecc970ef5c4bc9994a329b2bb1715728d6df30669d43c81177\n",
  )
  out.write_string(
    "BASIS fields15342 bits467801\nTRACE states840 transitions839 cover-global839\n",
  )
  out.write_string(
    "NATIVE known-bits234542 unknown-bits517-unpinned PRE-frames419\n",
  )
  out.write_string(
    "SEMANTICS original-initialization-unknown-memory-full-addresses-unchanged\n",
  )
  out.write_string(
    "ORIGINAL-SBY-RESULT unchanged-no-PASS-created\nPHASE6 incomplete\nEND\n",
  )
  out.to_string()
}

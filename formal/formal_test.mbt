///|
fn signal(name : String) -> @property.PropertySignal raise {
  @property.PropertySignal::named("top", name)
}

///|
fn binding(
  property_signal : @property.PropertySignal,
  identifier : String,
) -> @formal.FormalSignalBinding raise {
  @formal.FormalSignalBinding::checked(property_signal, identifier)
}

///|
fn digest(symbol : String) -> String {
  symbol.repeat(64)
}

///|
fn target_artifact() -> @formal.ArtifactRef raise {
  @formal.ArtifactRef::checked("rtl/top.sv", digest("a"))
}

///|
fn tool() -> @formal.FormalTool raise {
  @formal.FormalTool::checked("sby", "0.60.0")
}

///|
fn bounded_task(
  mode? : @formal.BoundedMode = BoundedSafety,
) -> @formal.BoundedProofTask raise {
  @formal.BoundedProofTask::checked(
    "fifo safety depth 32",
    target_artifact(),
    tool(),
    "smtbmc boolector",
    mode,
    @formal.ProofBound::checked(32),
    ["lc_p1_b617373756d65", "lc_p0_b7265736574"],
    ["lc_p9_b6f766572666c6f77", "lc_p3_b756e646572666c6f77"],
  )
}

///|
fn unbounded_task() -> @formal.UnboundedProofTask raise {
  @formal.UnboundedProofTask::checked(
    "fifo safety induction",
    target_artifact(),
    tool(),
    "abc pdr",
    PropertyDirectedReachability,
    ["lc_p1_b617373756d65"],
    ["lc_p9_b6f766572666c6f77"],
  )
}

///|
test "assertion assumption and cover export is explicit and deterministic" {
  let clock = signal("clock")
  let reset = signal("reset")
  let safe = signal("safe")
  let legal = signal("legal")
  let reached = signal("reached")
  let domain = @formal.ObservationDomain::rising_pre_edge(clock)
  assert_eq(domain.point(), PreEdge)
  let disabled = @formal.DisableBehavior::when_known_high_asynchronous(reset)
  let assertion = @property.PropertySpec::checked(
    @property.PropertyId::new(7),
    "queue_safe",
    Assertion,
    safe,
  )
  let cover = @property.PropertySpec::checked(
    @property.PropertyId::new(9),
    "queue_full_seen",
    Cover,
    reached,
  )
  let plan = @formal.FormalPropertyPlan::checked([
    @formal.FormalProperty::from_wave(cover, domain, NeverDisabled),
    @formal.FormalProperty::from_wave(assertion, domain, disabled),
    @formal.FormalProperty::assumption(
      @property.PropertyId::new(2),
      "input_legal",
      legal,
      domain,
      disabled,
    ),
  ])
  let bindings = [
    binding(reached, "lc_n9"),
    binding(clock, "lc_i0_b636c6f636b"),
    binding(legal, "lc_n4"),
    binding(reset, "lc_i1_b7265736574"),
    binding(safe, "lc_n8"),
  ]
  let first = @formal.export_properties(plan, bindings)
  let second = @formal.export_properties(plan, bindings.rev())
  assert_eq(first, second)
  assert_eq(
    first.source(),
    (
      #|`ifdef FORMAL
      #|  // LunaChip formal semantics: rising-pre-edge; known-high asynchronous disable.
      #|  lc_p2_b696e7075745f6c6567616c: assume property (@(posedge lc_i0_b636c6f636b) disable iff ((lc_i1_b7265736574) === 1'b1) ((lc_n4) === 1'b1));
      #|  lc_p7_b71756575655f73616665: assert property (@(posedge lc_i0_b636c6f636b) disable iff ((lc_i1_b7265736574) === 1'b1) ((lc_n8) === 1'b1));
      #|  lc_p9_b71756575655f66756c6c5f7365656e: cover property (@(posedge lc_i0_b636c6f636b) ((lc_n9) === 1'b1));
      #|`endif
      #|
    ),
  )
  assert_eq(first.properties().length(), 3)
  assert_eq(first.properties()[0].id().ordinal(), 2)
  assert_eq(first.properties()[0].kind(), Assumption)
  assert_eq(first.properties()[1].kind(), Assertion)
  assert_eq(first.properties()[2].kind(), Cover)
  assert_true(first.source().contains("assume property (@(posedge lc_i0"))
  assert_true(first.source().contains("assert property (@(posedge lc_i0"))
  assert_true(first.source().contains("cover property (@(posedge lc_i0"))
  assert_true(
    first.source().contains("disable iff ((lc_i1_b7265736574) === 1'b1)"),
  )
  assert_true(first.source().contains("((lc_n8) === 1'b1)"))
  assert_false(first.source().contains("__"))
  assert_true(first.manifest().has_prefix("LUNACHIP-FORMAL-PROPERTIES 1\n"))
  assert_true(first.manifest().contains("rising-pre-edge"))
  assert_true(first.manifest().contains("known-high-asynchronous"))
  let parsed = @formal.parse_formal_property_manifest(first.manifest())
  assert_eq(parsed, first.property_manifest())
  assert_eq(parsed.to_canonical_text(), first.manifest())
}

///|
test "formal export rejects unresolved and ambiguous signal bindings" {
  let clock = signal("clock")
  let predicate = signal("predicate")
  let domain = @formal.ObservationDomain::rising_pre_edge(clock)
  let spec = @formal.FormalProperty::checked(
    @property.PropertyId::new(0),
    "p",
    Assertion,
    predicate,
    domain,
    NeverDisabled,
  )
  let plan = @formal.FormalPropertyPlan::checked([spec])
  try @formal.export_properties(plan, [binding(clock, "lc_i0")]) catch {
    @formal.FormalError::MissingSignalBinding(actual) =>
      assert_eq(actual, predicate)
    _ => fail("expected missing predicate binding")
  } noraise {
    _ => fail("expected missing predicate binding")
  }
  try
    @formal.export_properties(plan, [
      binding(clock, "lc_i0"),
      binding(predicate, "lc_n1"),
      binding(predicate, "lc_n2"),
    ])
  catch {
    @formal.FormalError::DuplicateSignalBinding(actual) =>
      assert_eq(actual, predicate)
    _ => fail("expected duplicate signal binding")
  } noraise {
    _ => fail("expected duplicate signal binding")
  }
}

///|
test "formal property and binding construction fail closed" {
  let valid = signal("valid")
  try
    @formal.ObservationDomain::rising_pre_edge(Named(path="", name="clock"))
  catch {
    InvalidPropertySignal(_) => ()
    _ => fail("expected invalid signal rejection")
  } noraise {
    _ => fail("expected invalid signal rejection")
  }
  try @formal.FormalSignalBinding::checked(valid, "logic") catch {
    InvalidSystemVerilogIdentifier("logic") => ()
    _ => fail("expected conservative identifier rejection")
  } noraise {
    _ => fail("expected conservative identifier rejection")
  }
  let domain = @formal.ObservationDomain::rising_pre_edge(signal("clock"))
  let property = @formal.FormalProperty::checked(
    @property.PropertyId::new(1),
    "same",
    Assertion,
    valid,
    domain,
    NeverDisabled,
  )
  try @formal.FormalPropertyPlan::checked([property, property]) catch {
    DuplicatePropertyId(1) => ()
    _ => fail("expected duplicate property ID rejection")
  } noraise {
    _ => fail("expected duplicate property ID rejection")
  }
}

///|
test "negative property manifest fixtures reject forged names and ordering" {
  let clock = signal("clock")
  let predicate = signal("predicate")
  let domain = @formal.ObservationDomain::rising_pre_edge(clock)
  let plan = @formal.FormalPropertyPlan::checked([
    @formal.FormalProperty::checked(
      @property.PropertyId::new(3),
      "second",
      Assertion,
      predicate,
      domain,
      NeverDisabled,
    ),
    @formal.FormalProperty::checked(
      @property.PropertyId::new(1),
      "first",
      Assertion,
      predicate,
      domain,
      NeverDisabled,
    ),
  ])
  let manifest = @formal.export_properties(plan, [
    binding(clock, "lc_i0"),
    binding(predicate, "lc_n1"),
  ]).manifest()
  let forged = manifest.replace(
    old="lc_p1_b6669727374",
    new="lc_p1_b666f72676564",
  )
  try @formal.parse_formal_property_manifest(forged) catch {
    StablePropertyNameMismatch(..) => ()
    _ => fail("expected stable property-name mismatch")
  } noraise {
    _ => fail("expected stable property-name mismatch")
  }
  let reordered = manifest.replace(old="F 0 1 ", new="F 9 1 ")
  try @formal.parse_formal_property_manifest(reordered) catch {
    InvalidCanonicalLine(..) => ()
    _ => fail("expected ordinal mismatch")
  } noraise {
    _ => fail("expected ordinal mismatch")
  }
}

///|
test "bounded task manifest is canonical and retains a finite evidence class" {
  let task = bounded_task()
  let encoded = task.to_canonical_text()
  assert_true(encoded.contains("CLASS bounded\n"))
  assert_true(encoded.contains("MODE bmc-safety\n"))
  assert_true(encoded.contains("BOUND 32\n"))
  assert_true(encoded.contains("ARTIFACT 72746c2f746f702e7376 sha256"))
  assert_false(encoded.contains("proved"))
  let decoded = @formal.parse_proof_task(encoded)
  assert_eq(decoded, Bounded(task))
  assert_eq(decoded.to_canonical_text(), encoded)
  match decoded {
    Bounded(actual) => {
      assert_eq(actual.assumptions()[0], "lc_p0_b7265736574")
      assert_eq(actual.properties()[0], "lc_p3_b756e646572666c6f77")
    }
    _ => fail("expected bounded task")
  }
}

///|
test "unbounded task manifest records an explicit induction method" {
  let task = unbounded_task()
  let encoded = task.to_canonical_text()
  assert_true(encoded.contains("CLASS unbounded\n"))
  assert_true(encoded.contains("MODE prove-safety\n"))
  assert_true(encoded.contains("INDUCTION pdr\n"))
  assert_eq(@formal.parse_proof_task(encoded), Unbounded(task))
  let k_task = @formal.UnboundedProofTask::checked(
    "kinduction",
    target_artifact(),
    tool(),
    "smtbmc",
    @formal.InductionMethod::k_induction(4),
    [],
    ["lc_p0_b73616665"],
  )
  assert_true(k_task.to_canonical_text().contains("INDUCTION k-induction 4"))
}

///|
test "bounded pass and unbounded proof have disjoint result types and tokens" {
  let bounded = @formal.BoundedProofResult::checked(bounded_task(), BoundedPass)
  let bounded_text = bounded.to_canonical_text()
  assert_true(bounded_text.contains("RESULT bounded-pass\n"))
  assert_false(bounded_text.contains("RESULT proved\n"))
  assert_eq(@formal.parse_proof_result(bounded_text), BoundedResult(bounded))
  let unbounded = @formal.UnboundedProofResult::checked(
    unbounded_task(),
    Proved,
  )
  let unbounded_text = unbounded.to_canonical_text()
  assert_true(unbounded_text.contains("RESULT proved\n"))
  assert_eq(
    @formal.parse_proof_result(unbounded_text),
    UnboundedResult(unbounded),
  )
}

///|
test "counterexample and cover witness artifacts are mandatory and digested" {
  let counterexample = @formal.ArtifactRef::checked(
    "counterexamples/fifo.vcd",
    digest("c"),
    role=CounterexampleArtifact,
  )
  let failed = @formal.BoundedProofResult::checked(
    bounded_task(),
    SafetyCounterexample(counterexample),
  )
  let failed_text = failed.to_canonical_text()
  assert_true(failed_text.contains("COUNTEREXAMPLE artifact"))
  assert_eq(@formal.parse_proof_result(failed_text), BoundedResult(failed))
  let cover = @formal.BoundedProofResult::checked(
    bounded_task(mode=BoundedCover),
    CoverWitness(counterexample),
  )
  assert_true(cover.to_canonical_text().contains("WITNESS artifact"))
  assert_eq(
    @formal.parse_proof_result(cover.to_canonical_text()),
    BoundedResult(cover),
  )
}

///|
test "negative fixture rejects proved token in a bounded result" {
  let valid = @formal.BoundedProofResult::checked(bounded_task(), BoundedPass).to_canonical_text()
  let invalid = valid.replace(
    old="RESULT bounded-pass\n",
    new="RESULT proved\n",
  )
  try @formal.parse_proof_result(invalid) catch {
    ResultModeMismatch(mode="bmc-safety", result="proved") => ()
    _ => fail("expected bounded/proved rejection")
  } noraise {
    _ => fail("expected bounded/proved rejection")
  }
}

///|
test "negative fixtures reject missing counterexamples and wrong task digests" {
  let counterexample = @formal.ArtifactRef::checked(
    "counterexamples/fail.vcd",
    digest("d"),
    role=CounterexampleArtifact,
  )
  let valid = @formal.BoundedProofResult::checked(
    bounded_task(),
    SafetyCounterexample(counterexample),
  ).to_canonical_text()
  let missing = valid.replace(
    old="COUNTEREXAMPLE artifact 636f756e7465726578616d706c65732f6661696c2e766364 sha256 \{digest("d")}\n",
    new="COUNTEREXAMPLE none\n",
  )
  try @formal.parse_proof_result(missing) catch {
    MissingResultArtifact("COUNTEREXAMPLE") => ()
    _ => fail("expected missing counterexample rejection")
  } noraise {
    _ => fail("expected missing counterexample rejection")
  }
  let original_digest = @formal.BoundedProofResult::checked(
    bounded_task(),
    SafetyCounterexample(counterexample),
  ).task_sha256()
  let wrong_digest = valid.replace(
    old="TASK-MANIFEST sha256 \{original_digest}",
    new="TASK-MANIFEST sha256 \{digest("0")}",
  )
  try @formal.parse_proof_result(wrong_digest) catch {
    TaskDigestMismatch(expected~, ..) => assert_eq(expected, digest("0"))
    _ => fail("expected task digest rejection")
  } noraise {
    _ => fail("expected task digest rejection")
  }
}

///|
test "negative task fixtures reject malformed identity and noncanonical bytes" {
  try
    @formal.ArtifactRef::checked(
      "rtl/top.sv", "Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    )
  catch {
    InvalidDigestSymbol(role=TargetArtifact, index=0, ..) => ()
    _ => fail("expected lowercase digest rejection")
  } noraise {
    _ => fail("expected lowercase digest rejection")
  }
  try @formal.ArtifactRef::checked("../escape.sv", digest("a")) catch {
    InvalidArtifactName("../escape.sv") => ()
    _ => fail("expected traversal rejection")
  } noraise {
    _ => fail("expected traversal rejection")
  }
  try @formal.ArtifactRef::checked("C:\\escape.sv", digest("a")) catch {
    InvalidArtifactName("C:\\escape.sv") => ()
    _ => fail("expected platform-path rejection")
  } noraise {
    _ => fail("expected platform-path rejection")
  }
  let extra = bounded_task()
    .to_canonical_text()
    .replace(old="END\n", new="EXTRA\nEND\n")
  try @formal.parse_proof_task(extra) catch {
    InvalidCanonicalLine(..) => ()
    NonCanonicalArtifact => ()
    _ => fail("expected trailing record rejection")
  } noraise {
    _ => fail("expected trailing record rejection")
  }
}

///|
test "negative fixture rejects noncanonical property name order" {
  let canonical = bounded_task().to_canonical_text()
  let noncanonical = canonical.replace(
    old=(
      #|P 0 6c635f70335f62373536653634363537323636366336663737
      #|P 1 6c635f70395f6236663736363537323636366336663737
      #|
    ),
    new=(
      #|P 0 6c635f70395f6236663736363537323636366336663737
      #|P 1 6c635f70335f62373536653634363537323636366336663737
      #|
    ),
  )
  try @formal.parse_proof_task(noncanonical) catch {
    NonCanonicalArtifact => ()
    _ => fail("expected noncanonical ordering rejection")
  } noraise {
    _ => fail("expected noncanonical ordering rejection")
  }
}

///|
test "result constructors enforce task mode" {
  try
    @formal.BoundedProofResult::checked(
      bounded_task(mode=BoundedCover),
      BoundedPass,
    )
  catch {
    @formal.FormalError::ResultModeMismatch(
      mode="bounded-cover",
      result="bounded-pass"
    ) => ()
    _ => fail("expected cover/safety result mismatch")
  } noraise {
    _ => fail("expected cover/safety result mismatch")
  }
  try @formal.ProofBound::checked(0) catch {
    InvalidBound(0) => ()
    _ => fail("expected zero bound rejection")
  } noraise {
    _ => fail("expected zero bound rejection")
  }
}

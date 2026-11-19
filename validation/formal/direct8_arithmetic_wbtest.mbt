///|
test "qualified arithmetic profiles preserve old inputs and isolate bounds history from dynamic potential" {
  let id = Direct8ServicePart::AgePotential.id()
  let parent : Direct8CompletionBundle = {
    artifacts: direct8_progress_artifacts_from_id(id).unwrap(),
  }
  for
    (path, digest) in [
      (
        "formal-dut.sv", "32d748acc410a4743dd2765dd23444df10d3a12869f06ea8bbcba70c81e08752",
      ),
      (
        "source-set.lcfs", "d968212092c3dd9b72526febcaf4991220c95121fd26d61bde84d27148c8c388",
      ),
      (
        "properties.lcfp", "ac97110e3c1c9340ab3b5f0c0cd8cf8d2f661f0b69ab23d932eaf55c265e0ea6",
      ),
    ] {
    assert_eq(
      sha256_hex(direct8_completion_test_artifact(parent, path)),
      digest,
    )
  }
  let fixture = direct8_arbiter_fixture()
  let source = direct8_completion_test_artifact(parent, "formal-dut.sv")
  let plans = direct8_arithmetic_helpers(fixture.hardware(), source)
  assert_eq(plans.length(), 13)
  for
    name in ["lc_fn_add_w64", "lc_fn_sub_w64", "lc_fn_add_w13", "lc_fn_sub_w13"] {
    assert_true(plans.any(plan => plan.name == name))
  }
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "QueuedConcurrentDirect8CompletionPilot",
      fixture.hardware(),
    ),
  )
  let clock = port_identifier(emitted, InputPort, "clock")
  let exported : (Direct8ServicePart) -> String raise = part => {
    direct8_arbiter_property_export(
      clock,
      engine_progress=true,
      owner_support=true,
      completed_prefix=true,
      latency=true,
      service_credit=true,
      done_core=true,
      pending_slot=true,
      service_phase=true,
      service_part=part,
    ).source()
  }
  let names = direct8_service_phase_selected(parent, id)
  guard @formal_core.parse_proof_task(
      direct8_completion_test_artifact(parent, id + "-prove.lcft"),
    )
    is Unbounded(prior) else {
    fail("original task")
  }
  for part in [Direct8ServicePart::ArithmeticStructure, ArithmeticPotential] {
    let bundle : Direct8CompletionBundle = {
      artifacts: direct8_progress_artifacts_from_id(part.id()).unwrap(),
    }
    let selected = direct8_service_phase_selected(bundle, part.id())
    assert_eq(selected.length(), part.count())
    assert_false(selected.contains("d8l_command_latency"))
    assert_eq(
      names.filter(name => !selected.contains(name)),
      if part == ArithmeticStructure {
        ["d8l_potential_step", "d8l_age_potential"]
      } else {
        []
      },
    )
    for name in selected {
      assert_true(names.contains(name))
    }
    guard @formal_core.parse_proof_task(
        direct8_completion_test_artifact(bundle, part.id() + "-prove.lcft"),
      )
      is Unbounded(task) else {
      fail("adapted task")
    }
    assert_eq(task.assumptions(), prior.assumptions())
    assert_eq(task.induction(), prior.induction())
    assert_true(
      direct8_completion_test_artifact(bundle, "job.json").contains(
        "\"timeout_seconds\": 600",
      ),
    )
    for
      path in [
        "design.lcir", "names.lcnm", "formal-harness.sv", "arbiter-bindings.lcab",
      ] {
      assert_eq(
        direct8_completion_test_artifact(bundle, path),
        direct8_completion_test_artifact(parent, path),
      )
    }
    for artifact in parent.artifacts {
      if artifact.path.has_prefix("production-") {
        assert_eq(
          direct8_completion_test_artifact(bundle, artifact.path),
          artifact.content,
        )
      }
    }
    assert_eq(
      direct8_completion_test_artifact(bundle, "arithmetic-helpers.lcah"),
      direct8_arithmetic_report(plans),
    )
    let mut restored = direct8_completion_test_artifact(bundle, "formal-dut.sv")
    for plan in plans {
      assert_eq(restored.split(plan.replacement).count(), 2)
      restored = restored.replace(old=plan.replacement, new=plan.original)
    }
    assert_eq(
      restored.replace(old=exported(part), new=exported(AgePotential)),
      source,
    )
    assert_eq(
      regenerate_formal_artifacts(
        direct8_completion_test_artifact(bundle, "source-set.lcfs"),
      ),
      bundle.artifacts,
    )
  }
  try
    direct8_arithmetic_helpers(
      fixture.hardware(),
      source.replace(old="carry = 1'b0;", new="carry = 1'b1;"),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("original helper drift must fail")
  }
}

///|
fn direct8_arithmetic_ripple(
  a : UInt64,
  b : UInt64,
  width : Int32,
  add : Bool,
) -> UInt64 {
  let mut result = 0UL
  let mut carry = 0UL
  for bit in 0..<width {
    let x = (a >> bit) & 1UL
    let y = (b >> bit) & 1UL
    result = result | ((x ^ y ^ carry) << bit)
    carry = if add {
      (x & y) | (x & carry) | (y & carry)
    } else {
      ((1UL - x) & (y | carry)) | (y & carry)
    }
  }
  result
}

///|
test "arithmetic reference covers carry borrow high address bits and modular wrap" {
  // Binary reference checks, not a substitute for pinned pointwise SAT.
  for width in [2, 3, 4, 5, 7, 8, 13, 32, 64] {
    let mask = if width == 64 {
      0xffffffffffffffffUL
    } else {
      (1UL << width) - 1UL
    }
    let operands = if width <= 5 {
      Array::makei(1 << width, i => i.to_uint64())
    } else {
      [
        0UL,
        1UL,
        mask,
        mask - 1UL,
        1UL << (width - 1),
        (1UL << (width - 1)) - 1UL,
      ]
    }
    for a in operands {
      for b in operands {
        assert_eq(direct8_arithmetic_ripple(a, b, width, true), (a + b) & mask)
        assert_eq(direct8_arithmetic_ripple(a, b, width, false), (a - b) & mask)
      }
    }
  }
}

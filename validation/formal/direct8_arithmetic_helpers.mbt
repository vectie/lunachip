///|
priv struct Direct8ArithmeticHelper {
  name : String
  width : Int
  original : String
  replacement : String
}

///|
fn direct8_arithmetic_header(name : String, width : Int) -> String {
  (
    $|  function automatic logic [\{width - 1}:0] \{name}(
    $|    input logic [\{width - 1}:0] a,
    $|    input logic [\{width - 1}:0] b
    $|  );
    $|
  )
}

///|
fn direct8_arithmetic_original(
  name : String,
  width : Int,
  add : Bool,
) -> String {
  let state = if add { "carry" } else { "borrow" }
  let update = if add {
    "(a[i] & b[i]) | (a[i] & carry) | (b[i] & carry)"
  } else {
    "(~a[i] & (b[i] | borrow)) | (b[i] & borrow)"
  }
  direct8_arithmetic_header(name, width) +
  (
    $|    logic \{state};
    $|    integer i;
    $|    begin
    $|      \{state} = 1'b0;
    $|      for (i = 0; i < \{width}; i = i + 1) begin
    $|        \{name}[i] = a[i] ^ b[i] ^ \{state};
    $|        \{state} = \{update};
    $|      end
    $|    end
    $|  endfunction
    $|
  )
}

///|
// Opt-in, all-binary proof adapter only. Production four-state helpers stay.
fn direct8_arithmetic_helpers(
  hardware : @ir.Module,
  source : String,
) -> Array[Direct8ArithmeticHelper] raise {
  let plans : Array[Direct8ArithmeticHelper] = []
  for node in hardware.nodes() {
    let add = match node.kind() {
      Add(_, _) => Some(true)
      Sub(_, _) => Some(false)
      _ => None
    }
    if add is Some(add) {
      let width = node.signal_type().width().bits()
      assert_true(width > 0 && width <= 64)
      let name = "lc_fn_\{if add { "add" } else { "sub" }}_w\{width}"
      if plans.any(plan => plan.name == name) {
        continue
      }
      let original = direct8_arithmetic_original(name, width, add)
      assert_eq(source.split(original).count(), 2)
      let replacement = direct8_arithmetic_header(name, width) +
        (
          $|    begin
          $|      \{name} = a \{if add { "+" } else { "-" }} b;
          $|    end
          $|  endfunction
          $|
        )
      plans.push({ name, width, original, replacement, })
    }
  }
  plans
}

///|
fn direct8_arithmetic_apply(
  dut : QueueFormalDut,
  plans : Array[Direct8ArithmeticHelper],
) -> QueueFormalDut raise {
  let mut source = dut.source
  for plan in plans {
    assert_eq(source.split(plan.original).count(), 2)
    source = source.replace(old=plan.original, new=plan.replacement)
  }
  let mut restored = source
  for plan in plans {
    restored = restored.replace(old=plan.replacement, new=plan.original)
  }
  assert_eq(restored, dut.source)
  { ..dut, source, }
}

///|
fn direct8_arithmetic_report(plans : Array[Direct8ArithmeticHelper]) -> String {
  let out = StringBuilder()
  out.write_string(
    "LUNACHIP-DIRECT8-ARITHMETIC 1\nSCOPE all-defined-binary-operands-same-width-modular-no-four-state-production-claim\n",
  )
  for plan in plans {
    out.write_string(
      "HELPER \{plan.name} \{plan.width} \{sha256_hex(plan.original)} \{sha256_hex(plan.replacement)}\n",
    )
  }
  out.write_string("END\n")
  out.to_string()
}

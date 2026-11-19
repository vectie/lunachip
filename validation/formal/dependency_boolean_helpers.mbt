///|
// Used by the isolated two-state dependency adapter only. The ordinary
// emitter and retained production RTL keep their four-state helper semantics.
priv struct DependencyBooleanHelperPlan {
  original : String
  replacement : String
  function_name : String
}

///|
fn dependency_boolean_helper_header(name : String, width : Int32) -> String {
  (
    $|  function automatic logic \{name}(
    $|    input logic [\{width - 1}:0] a,
    $|    input logic [\{width - 1}:0] b
    $|  );
    $|
  )
}

///|
fn dependency_boolean_original_helper(
  operation : String,
  name : String,
  width : Int32,
) -> String raise FormalGateError {
  let body = match operation {
    "eq" =>
      (
        $|    logic mismatch;
        $|    logic unknown;
        $|    integer i;
        $|    begin
        $|      mismatch = 1'b0;
        $|      unknown = 1'b0;
        $|      for (i = 0; i < \{width}; i = i + 1) begin
        $|        case ({a[i], b[i]})
        $|          2'b00, 2'b11: begin end
        $|          2'b01, 2'b10: mismatch = 1'b1;
        $|          default: unknown = 1'b1;
        $|        endcase
        $|      end
        $|      if (mismatch) \{name} = 1'b0;
        $|      else if (unknown) \{name} = 1'bx;
        $|      else \{name} = 1'b1;
        $|    end
        $|  endfunction
        $|
      )
    "lt_u" =>
      (
        $|    logic decided;
        $|    integer i;
        $|    begin
        $|      \{name} = 1'b0;
        $|      decided = 1'b0;
        $|      for (i = \{width - 1}; i >= 0; i = i - 1) begin
        $|        if (!decided) begin
        $|          case ({a[i], b[i]})
        $|            2'b01: begin \{name} = 1'b1; decided = 1'b1; end
        $|            2'b10: begin \{name} = 1'b0; decided = 1'b1; end
        $|            2'b00, 2'b11: begin end
        $|            default: begin \{name} = 1'bx; decided = 1'b1; end
        $|          endcase
        $|        end
        $|      end
        $|    end
        $|  endfunction
        $|
      )
    "lt_s" =>
      (
        $|    logic decided;
        $|    integer i;
        $|    begin
        $|      \{name} = 1'b0;
        $|      decided = 1'b0;
        $|      case ({a[\{width - 1}], b[\{width - 1}]})
        $|        2'b10: begin \{name} = 1'b1; decided = 1'b1; end
        $|        2'b01: begin \{name} = 1'b0; decided = 1'b1; end
        $|        2'b00, 2'b11: begin end
        $|        default: begin \{name} = 1'bx; decided = 1'b1; end
        $|      endcase
        $|      for (i = \{width - 2}; i >= 0; i = i - 1) begin
        $|        if (!decided) begin
        $|          case ({a[i], b[i]})
        $|            2'b01: begin \{name} = 1'b1; decided = 1'b1; end
        $|            2'b10: begin \{name} = 1'b0; decided = 1'b1; end
        $|            2'b00, 2'b11: begin end
        $|            default: begin \{name} = 1'bx; decided = 1'b1; end
        $|          endcase
        $|        end
        $|      end
        $|    end
        $|  endfunction
        $|
      )
    _ => raise InvalidFormalBundleIdentity("unknown dependency Boolean helper")
  }
  dependency_boolean_helper_header(name, width) + body
}

///|
fn dependency_boolean_extract_helper(
  source : String,
  function_name : String,
) -> String raise FormalGateError {
  let start = "  function automatic logic " + function_name + "(\n"
  guard source.split(start).to_array() is [_, tail] else {
    raise InvalidFormalBundleIdentity(
      "missing or repeated dependency Boolean helper: " + function_name,
    )
  }
  let ending = "  endfunction\n"
  guard tail.split(ending).to_array() is [body, _, ..] else {
    raise InvalidFormalBundleIdentity(
      "unterminated dependency Boolean helper: " + function_name,
    )
  }
  start + body.to_owned() + ending
}

///|
fn dependency_boolean_helper_plans(
  hardware : @ir.Module,
  source : String,
) -> ReadOnlyArray[DependencyBooleanHelperPlan] raise FormalGateError {
  let plans : Array[DependencyBooleanHelperPlan] = []
  for node in hardware.nodes() {
    let comparison = match node.kind() {
      Equal(left, _) => Some(("eq", left))
      LessThan(left, _) | LessEqual(left, _) => Some(("lt", left))
      _ => None
    }
    if comparison is Some((comparison_kind, left)) {
      guard hardware.node(left) is Some(operand) else {
        raise InvalidFormalBundleIdentity("missing typed comparison operand")
      }
      let width = operand.signal_type().width().bits()
      let signed = comparison_kind == "lt" && operand.signal_type() is SInt(_)
      let operation = if comparison_kind == "eq" {
        "eq"
      } else if signed {
        "lt_s"
      } else {
        "lt_u"
      }
      let function_name = "lc_fn_\{operation}_w\{width}"
      if !plans.any(plan => plan.function_name == function_name) {
        let original = dependency_boolean_extract_helper(source, function_name)
        if original !=
          dependency_boolean_original_helper(operation, function_name, width) {
          raise InvalidFormalBundleIdentity(
            "dependency Boolean helper shape drift: " + function_name,
          )
        }
        let expression = match operation {
          "eq" => "a == b"
          "lt_s" => "$signed(a) < $signed(b)"
          _ => "$unsigned(a) < $unsigned(b)"
        }
        let body =
          $|    begin
          $|      \{function_name} = \{expression};
          $|    end
          $|  endfunction
          $|
        plans.push({
          original,
          replacement: dependency_boolean_helper_header(function_name, width) +
          body,
          function_name,
        })
      }
    }
  }
  ReadOnlyArray::from_array(plans)
}

///|
fn dependency_apply_boolean_helper_plans(
  source : String,
  plans : ReadOnlyArray[DependencyBooleanHelperPlan],
) -> String raise FormalGateError {
  let mut replaced = source
  for plan in plans {
    if dependency_boolean_extract_helper(replaced, plan.function_name) !=
      plan.original {
      raise InvalidFormalBundleIdentity(
        "dependency Boolean helper application drift: " + plan.function_name,
      )
    }
    replaced = replaced.replace(old=plan.original, new=plan.replacement)
  }
  replaced
}

///|
fn dependency_boolean_helpers(
  hardware : @ir.Module,
  source : String,
) -> (String, ReadOnlyArray[DependencyBooleanHelperPlan]) raise FormalGateError {
  let plans = dependency_boolean_helper_plans(hardware, source)
  (dependency_apply_boolean_helper_plans(source, plans), plans)
}

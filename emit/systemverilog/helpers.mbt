///|
priv enum HelperKind {
  AddHelper
  SubHelper
  EqualHelper
  LessUnsignedHelper
  LessSignedHelper
} derive(Eq)

///|
priv struct HelperSpec {
  kind : HelperKind
  width : Int
} derive(Eq)

///|
fn helper_operation(kind : HelperKind) -> String {
  match kind {
    AddHelper => "add"
    SubHelper => "sub"
    EqualHelper => "eq"
    LessUnsignedHelper => "lt_u"
    LessSignedHelper => "lt_s"
  }
}

///|
fn HelperSpec::identifier(self : HelperSpec) -> String {
  helper_identifier(helper_operation(self.kind), self.width)
}

///|
fn add_helper(spec : HelperSpec) -> String {
  let name = spec.identifier()
  let width = spec.width
  let source =
    $|  function automatic logic [\{width - 1}:0] \{name}(
    $|    input logic [\{width - 1}:0] a,
    $|    input logic [\{width - 1}:0] b
    $|  );
    $|    logic carry;
    $|    integer i;
    $|    begin
    $|      carry = 1'b0;
    $|      for (i = 0; i < \{width}; i = i + 1) begin
    $|        \{name}[i] = a[i] ^ b[i] ^ carry;
    $|        carry = (a[i] & b[i]) | (a[i] & carry) | (b[i] & carry);
    $|      end
    $|    end
    $|  endfunction
    $|
  source
}

///|
fn sub_helper(spec : HelperSpec) -> String {
  let name = spec.identifier()
  let width = spec.width
  let source =
    $|  function automatic logic [\{width - 1}:0] \{name}(
    $|    input logic [\{width - 1}:0] a,
    $|    input logic [\{width - 1}:0] b
    $|  );
    $|    logic borrow;
    $|    integer i;
    $|    begin
    $|      borrow = 1'b0;
    $|      for (i = 0; i < \{width}; i = i + 1) begin
    $|        \{name}[i] = a[i] ^ b[i] ^ borrow;
    $|        borrow = (~a[i] & (b[i] | borrow)) | (b[i] & borrow);
    $|      end
    $|    end
    $|  endfunction
    $|
  source
}

///|
fn equal_helper(spec : HelperSpec) -> String {
  let name = spec.identifier()
  let width = spec.width
  let source =
    $|  function automatic logic \{name}(
    $|    input logic [\{width - 1}:0] a,
    $|    input logic [\{width - 1}:0] b
    $|  );
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
  source
}

///|
fn less_unsigned_helper(spec : HelperSpec) -> String {
  let name = spec.identifier()
  let width = spec.width
  let source =
    $|  function automatic logic \{name}(
    $|    input logic [\{width - 1}:0] a,
    $|    input logic [\{width - 1}:0] b
    $|  );
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
  source
}

///|
fn less_signed_helper(spec : HelperSpec) -> String {
  let name = spec.identifier()
  let width = spec.width
  let source =
    $|  function automatic logic \{name}(
    $|    input logic [\{width - 1}:0] a,
    $|    input logic [\{width - 1}:0] b
    $|  );
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
  source
}

///|
fn emit_helper(spec : HelperSpec) -> String {
  match spec.kind {
    AddHelper => add_helper(spec)
    SubHelper => sub_helper(spec)
    EqualHelper => equal_helper(spec)
    LessUnsignedHelper => less_unsigned_helper(spec)
    LessSignedHelper => less_signed_helper(spec)
  }
}

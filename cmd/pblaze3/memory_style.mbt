///|
priv struct MemoryLeaf {
  source : String
  module_name : String
  ports : Map[String, String]
}

///|
// Generate a preserved memory leaf with the same synchronous ReadOld/HoldLast
// behavior as the canonical top-level memories. No handwritten RAM semantics.
fn memory_leaf(depth : Int32, distributed~ : Bool = false) -> MemoryLeaf raise {
  let b = @wire.ModuleBuilder::new("prx100_qwen_bram_" + depth.to_string())
  let clk = b.input("clock", @wire.clock())
  let d = b.rising_edge(clk)
  let ports : Map[String, @wire.Signal] = Map([])
  let width = if depth == 32768 {
    15
  } else if depth == 4096 {
    12
  } else if depth == 2048 {
    11
  } else if depth == 512 {
    9
  } else if depth == 256 {
    8
  } else if depth == 8 {
    3
  } else if depth == 64 {
    6
  } else {
    5
  }
  for
    (name, bits) in [
      ("read_enable", 1),
      ("read_address", width),
      ("write_enable", 1),
      ("write_address", width),
      ("write_data", 32),
    ] {
    let x = b.input(
      name,
      if bits == 1 {
        @wire.bits(1)
      } else {
        @wire.uint(bits)
      },
    )
    b.input_timing(x, SampledIn(d.id()))
    ports[name] = x
  }
  let mem = b.synchronous_memory(
    "storage",
    @wire.uint(32),
    depth,
    d,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
  )
  b.memory_write(
    mem,
    "write",
    ports["write_address"],
    ports["write_data"],
    enable=ports["write_enable"],
  )
  let value = b.memory_read(
    mem,
    "read",
    ports["read_address"],
    enable=ports["read_enable"],
    enable_behavior=HoldLast,
  )
  let output = b.output("read_data", @wire.uint(32))
  b.output_timing(output, ProducedIn(d.id()))
  b.connect(output, value)
  let e = @sv.emit_design(@ir.Design::single("prx100-qwen-bram/v1", b.finish()))
  let names : Map[String, String] = Map([])
  for
    name in [
      "clock", "read_enable", "read_address", "write_enable", "write_address", "write_data",
    ] {
    names[name] = mapped(e, name, InputPort)
  }
  names["read_data"] = mapped(e, "read_data", OutputPort)
  let lines : Array[String] = []
  let mut arrays = 0
  for line in normalize(optimized(e.source())).split("\n") {
    if line.has_prefix("  logic [31:0] lc_a") && line.contains(" [0:") {
      lines.push(
        "  (* ram_style = \"" +
        (if distributed { "distributed" } else { "block" }) +
        "\" *)" +
        line[1:].to_owned(),
      )
      arrays += 1
    } else {
      lines.push(line.to_owned())
    }
  }
  assert_eq(arrays, 1)
  {
    source: lines.join("\n"),
    module_name: e.modules()[0].identifier(),
    ports: names,
  }
}

///|
fn memory_address(line : String, array : String) -> String raise {
  let p = line.split(array + "[").to_array()
  assert_true(p.length() >= 2)
  let s = p[1].split("]").to_array()
  assert_true(s.length() >= 2)
  s[0].to_owned()
}

///|
fn memory_style(source : String) -> String raise {
  // The streaming designs have 256 or 1,024 small independently addressed
  // weight banks. Use distributed RAM for those banks and block RAM for
  // the large arrays. The canonical ReadOld/HoldLast behavior is shared.
  let memory_count = source
    .split("\n")
    .filter(line => {
      line.has_prefix("  logic [31:0] lc_a") && line.contains(" [0:")
    })
    .count()
  let distributed = memory_count == 259 ||
    memory_count == 1027 ||
    memory_count == 2051
  let big = memory_leaf(32768)
  let small = memory_leaf(32, distributed~)
  let banked = if source.contains(" [0:4095];") {
    Some(memory_leaf(4096))
  } else if source.contains(" [0:2047];") {
    Some(memory_leaf(2048))
  } else if source.contains(" [0:511];") {
    Some(memory_leaf(512))
  } else if source.contains(" [0:255];") {
    Some(memory_leaf(256))
  } else if source.contains(" [0:63];") {
    Some(memory_leaf(64))
  } else {
    None
  }
  let slots = if source.contains(" [0:7];") {
    Some(memory_leaf(8, distributed=true))
  } else {
    None
  }
  let input = source.split("\n").to_array()
  let result : Array[String] = []
  let arrays : Array[(String, Int32)] = []
  let mut functions = 0
  let mut blocks = 0
  for i = 0; i < input.length(); {
    let line = input[i]
    if line.has_prefix("  logic [31:0] lc_a") && line.contains(" [0:") {
      let fields = line.trim().split(" ").to_array()
      assert_eq(fields.length(), 4)
      let depth = if fields[3] == "[0:32767];" {
        32768
      } else if fields[3] == "[0:4095];" {
        4096
      } else if fields[3] == "[0:2047];" {
        2048
      } else if fields[3] == "[0:511];" {
        512
      } else if fields[3] == "[0:255];" {
        256
      } else if fields[3] == "[0:7];" {
        8
      } else if fields[3] == "[0:63];" {
        64
      } else {
        assert_eq(fields[3], "[0:31];")
        32
      }
      arrays.push((fields[2].to_owned(), depth))
      continue i + 1
    }
    if line.has_prefix("  function automatic logic lc_ak") {
      let mut end = i + 1
      while end < input.length() && input[end] != "  endfunction" {
        end += 1
      }
      assert_true(end < input.length())
      functions += 1
      continue end + 1
    }
    if line.has_prefix("  always_ff @") &&
      i + 8 < input.length() &&
      input[i + 1].contains(" <= ") &&
      input[i + 8].has_prefix("    if (lc_ak") {
      assert_eq(input[i + 9], "  end")
      assert_true(blocks < arrays.length())
      let (array, depth) = arrays[blocks]
      let leaf = if depth == 32768 {
        big
      } else if depth == 8 {
        slots.unwrap()
      } else if [64, 256, 512, 2048, 4096].contains(depth) {
        banked.unwrap()
      } else {
        small
      }
      let read = input[i + 1]
      let write = input[i + 8]
      let ra = memory_address(read.to_owned(), array)
      let wa = memory_address(write.to_owned(), array)
      let rd = read.trim().split(" <= ").to_array()[0].to_owned()
      let ren = read.split(" <= ").to_array()[1].split(" ? ").to_array()[0].to_owned()
      let rhs = write.split(" <= ").to_array()
      assert_eq(rhs.length(), 2)
      let enabled = rhs[1].split(" ? (").to_array()
      assert_eq(enabled.length(), 2)
      let data = enabled[1].split(") : ").to_array()
      assert_eq(data.length(), 2)
      assert_eq(data[1].to_owned(), array + "[" + wa + "];")
      let clock = line.split("@(posedge ").to_array()[1].split(")").to_array()[0].to_owned()
      let pins = [
        ("clock", clock),
        ("read_enable", ren),
        ("read_address", ra),
        ("read_data", rd),
        ("write_enable", enabled[0].to_owned()),
        ("write_address", wa),
        ("write_data", data[0].to_owned()),
      ]
      let con = pins.map(item => {
        let (name, signal) = item
        "." + leaf.ports[name] + "(" + signal + ")"
      })
      result.push(
        "  (* keep_hierarchy = \"yes\" *) " +
        leaf.module_name +
        " layer_memory_" +
        blocks.to_string() +
        "(" +
        con.join(",") +
        ");",
      )
      blocks += 1
      continue i + 10
    }
    result.push(line.to_owned())
    continue i + 1
  }
  assert_true(
    arrays.length() == 3 ||
    arrays.length() == 7 ||
    arrays.length() == 11 ||
    arrays.length() == 35 ||
    arrays.length() == 67 ||
    (
      arrays.length() == 68 &&
      arrays.filter(entry => entry.1 == 32768).length() == 3
    ) ||
    (
      arrays.length() == 132 &&
      arrays.filter(entry => entry.1 == 8).length() == 64
    ) ||
    arrays.length() == 131 ||
    arrays.length() == 259 ||
    arrays.length() == 1027 ||
    arrays.length() == 2051,
  )
  assert_eq(functions, arrays.length())
  assert_eq(blocks, arrays.length())
  result.join("\n") +
  "\n" +
  big.source +
  "\n" +
  small.source +
  (if slots is Some(mem) { "\n" + mem.source } else { "" }) +
  (if banked is Some(mem) { "\n" + mem.source } else { "" })
}

///|
fn field_json(j : Json, key : String) -> Json {
  guard j is Object(m) else { abort("expected object") }
  m[key]
}

///|
fn numbers(j : Json) -> Array[Double] {
  guard j is Array(xs) else { abort("expected numbers") }
  xs.map(x => {
    guard x is Number(n, ..) else { abort("expected number") }
    n
  })
}

///|
// Host conversion uses bit-level RNE, keeping NaNs quiet.
fn bf16(x : Double) -> UInt32 {
  let raw = Float::from_double(x).reinterpret_as_uint()
  if (raw & 0x7fffffffU) > 0x7f800000U {
    return 0x7fc0U
  }
  (raw + 0x7fffU + ((raw >> 16) & 1U)) >> 16
}

///|
fn replay(fixture : String, root : String) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh replay root required") }
  let source = @fs.read_file_to_string(fixture)
  assert_eq(
    @v.sha256_hex(source),
    "409ca5210ca8a10a2799f66590ab0ccee51f1cc501d8dc738a1334a71dfe225e",
  )
  let fixture = @json.parse(source)
  let weights = numbers(field_json(fixture, "weights_fp64_row_major"))
  guard field_json(fixture, "inputs") is Array(inputs) else {
    fail("missing inputs")
  }
  let hw = @fp.dot_product()
  let design = @ir.Design::single("bf16-fp32-dot/v1", hw)
  let e = @sv.emit_design(design)
  let ports = @v.collect_ports(hw, e.manifest())
  let sim = @sim.Simulator::prepare(hw)
  let values : Map[String, UInt64] = Map([])
  for p in @v.input_ports(ports) {
    values[p.source_name()] = 0UL
  }
  let stimulus = StringBuilder()
  stimulus.write_string(
    "cycle\t" +
    @v.input_ports(ports).map(p => p.emitted_name()).join("\t") +
    "\n",
  )
  let expected = StringBuilder()
  expected.write_string(@v.tsv_header(@v.output_ports(ports)))
  let mut cycle = 0
  fn step() -> Unit raise {
    let row : Array[String] = [cycle.to_string()]
    for p in @v.input_ports(ports) {
      let value = values[p.source_name()]
      sim.set_input(
        p.source_name(),
        @wave.LogicValue::from_uint64(width=p.width(), value~),
      )
      row.push(@v.padded_hex(value, p.width()))
    }
    stimulus.write_string(row.join("\t") + "\n")
    sim.rising_edge("clock")
    let row : Array[String] = [cycle.to_string()]
    for p in @v.output_ports(ports) {
      let v = sim.output(p.source_name())
      assert_true(v.is_fully_known())
      row.push(@v.padded_hex(v.value_bits(), p.width()))
    }
    if cycle > 0 {
      expected.write_string(row.join("\t") + "\n")
    }
    cycle += 1
  }
  values["reset"] = 1UL
  step()
  values["reset"] = 0UL
  let jobs : Array[Json] = []
  for vector, input in inputs {
    let a = numbers(field_json(input, "activation_fp64"))
    for channel in 0..<8 {
      let words : Array[UInt32] = []
      let mut cpu : Float = 0.0
      let mut original = 0.0
      for k in 0..<1024 {
        let aa = bf16(a[k])
        let ww = bf16(weights[channel * 1024 + k])
        let word = aa | (ww << 16)
        words.push(word)
        let product = Float::reinterpret_from_uint(aa << 16) *
          Float::reinterpret_from_uint(ww << 16)
        cpu = cpu + product
        original += a[k] * weights[channel * 1024 + k]
        values["load"] = 1UL
        values["write_address"] = k.to_uint64()
        values["write_data"] = word.to_uint64()
        step()
      }
      values["load"] = 0UL
      values["length"] = 1024UL
      values["start"] = 1UL
      step()
      values["start"] = 0UL
      for _ in 0..<4096 {
        step()
      }
      assert_eq(
        sim.output("result").value_bits(),
        cpu.reinterpret_as_uint().to_uint64(),
      )
      assert_eq(sim.output("done").value_bits(), 1UL)
      assert_eq(sim.output("busy").value_bits(), 0UL)
      assert_eq(sim.output("cycles").value_bits(), 4096UL)
      jobs.push({
        "vector": vector,
        "channel": channel,
        "length": 1024,
        "words": Json(words),
        "expected_bits": Json(cpu.reinterpret_as_uint()),
        "bf16_fp32_result": cpu.to_double(),
        "original_fp64_result": original,
        "absolute_error": (cpu.to_double() - original).abs(),
      })
    }
  }
  let protocol = @v.ResultProtocol::checked(
    "LUNACHIP-FP-RESULT", "1", "bf16-fp32-dot/v1",
  )
  let identity = @diff.ResultIdentity::checked(
    @diff.DesignIdentity::checked(
      protocol.semantic_version(),
      @v.sha256_hex(@codec.serialize(design)),
    ),
    @v.sha256_hex(stimulus.to_string()),
  )
  @fs.create_dir(root)
  @fs.write_string_to_file(
    root + "/" + e.modules()[0].filename(),
    vendor_source(e.source()),
  )
  @fs.write_string_to_file(root + "/dot.lcir", @codec.serialize(design))
  @fs.write_string_to_file(root + "/manifest.json", @v.harness_json(e, ports))
  @fs.write_string_to_file(
    root + "/harness.cpp",
    @v.harness_cpp(ports, identity, protocol),
  )
  @fs.write_string_to_file(root + "/stimulus.tsv", stimulus.to_string())
  @fs.write_string_to_file(
    root + "/expected.tsv",
    protocol.magic() +
    "\t1\t" +
    @v.utf8_hex(protocol.semantic_version()) +
    "\tsha256\t" +
    identity.design().design_sha256() +
    "\tsha256\t" +
    identity.stimulus_sha256() +
    "\n" +
    expected.to_string(),
  )
  @fs.write_string_to_file(
    root + "/jobs.json",
    Json(jobs).stringify(indent=2) + "\n",
  )
  @fs.write_string_to_file(root + "/cycles.txt", cycle.to_string() + "\n")
  let job : Json = {
    "schema_version": "lunachip.yosys-job/v1",
    "top_module": e.modules()[0].identifier(),
    "sources": [
      {
        "path": e.modules()[0].filename(),
        "sha256": @v.sha256_hex(vendor_source(e.source())),
      },
    ],
    "formal_tasks": [],
  }
  @fs.write_string_to_file(root + "/job.json", job.stringify() + "\n")
  println(
    "PASS 24 BF16 Qwen dot products against CPU FP32; cycles=" +
    cycle.to_string(),
  )
}

///|
fn make_fixture(source : String, root : String) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh fixture root") }
  @fs.create_dir(root)
  let w = load_weights(source)
  let p : LayerProgram = {
    words: [],
    traces: [],
    assets: [],
    weights: Map([]),
    constants: Map([]),
    out_root: root,
    trace_offset: 0x04000000U,
    constant_offset: 0x03000000U,
  }
  let mut offset = 0U
  for name in ["q", "k", "v", "o", "gate", "up", "down"] {
    let tensor = if name == "gate" || name == "up" || name == "down" {
      "mlp." + name + "_proj.weight"
    } else {
      "self_attn." + name + "_proj.weight"
    }
    let bytes = bf16_bytes(w.get(tensor))
    let file = "weight-" + name + ".bin"
    @fs.write_bytes_to_file(root + "/" + file, bytes)
    p.weights[name] = offset
    p.assets.push({
      "name": name,
      "tensor": tensor,
      "file": file,
      "address": offset,
      "bytes": bytes.length(),
      "sha256": hash(bytes),
    })
    offset += bytes.length().reinterpret_as_uint()
  }
  assert_eq(offset, 31457280U)
  for
    (name, tensor) in [
      ("input-gamma", "input_layernorm.weight"),
      ("post-gamma", "post_attention_layernorm.weight"),
      ("q-gamma", "self_attn.q_norm.weight"),
      ("k-gamma", "self_attn.k_norm.weight"),
    ] {
    p.constant(name, w.get(tensor))
  }
  let inputs : Array[Array[Float]] = []
  for position, token in [42, 100, 1000, 42] {
    let embedding = read_bf16(
      source + "/prior-embedding-token-" + token.to_string() + ".bin",
    )
    inputs.push(embedding)
    p.constant("embedding-" + position.to_string(), embedding)
    let (cos, sin) = rope_coefficients(position)
    p.constant("cos-" + position.to_string(), cos)
    p.constant("sin-" + position.to_string(), sin)
    p.constant("negative-sin-" + position.to_string(), sin.map(x => -x))
  }
  for position in 0..<4 {
    p.token(position)
  }
  p.emit(0U, 0, 0, 0)
  assert_eq(p.words.length() % 16, 0)
  assert_true(p.words.length() <= 32768)
  @fs.write_bytes_to_file(root + "/program.bin", word_bytes(p.words))
  let cpu_traces : Array[Json] = []
  let begin = @env.now()
  let output = cpu_layer(w, inputs, (name, values) => {
    let bytes = float_bytes(values)
    let file = "cpu-" + name + ".bin"
    @fs.write_bytes_to_file(root + "/" + file, bytes)
    cpu_traces.push({
      "name": name,
      "file": file,
      "words": values.length(),
      "sha256": hash(bytes),
    })
  })
  let traced_ms = @env.now() - begin
  assert_eq(output.length(), 4)
  assert_eq(cpu_traces.length(), 80)
  assert_eq(p.traces.length(), 80)
  let samples : Array[UInt64] = []
  let mut checksum = 0.0
  for _ in 0..<3 {
    let start = @env.now()
    let result = cpu_layer(w, inputs, (_, _) => ())
    samples.push(@env.now() - start)
    for row in result {
      for v in row {
        checksum += v.to_double()
      }
    }
  }
  let manifest : Json = {
    "status": "PASS",
    "model": "Qwen/Qwen3-0.6B",
    "revision": "c1899de289a04d12100db370d81485cdf75e47ca",
    "layer": 0,
    "hidden": 1024,
    "intermediate": 3072,
    "query_heads": 16,
    "kv_heads": 8,
    "head_dim": 128,
    "rms_epsilon": 0.000001,
    "rope_theta": 1000000,
    "tokens": [42, 100, 1000, 42],
    "prefill_tokens": 3,
    "decode_tokens": 1,
    "context_capacity": 8,
    "weight_bytes": offset,
    "assets": p.assets,
    "traces": p.traces,
    "cpu_traces": cpu_traces,
    "program_descriptors": p.words.length() / 16,
    "program_sha256": hash(word_bytes(p.words)),
    "cpu_four_token_samples_ms": samples,
    "cpu_traced_four_token_ms": traced_ms,
    "cpu_checksum": checksum,
    "comparison_absolute_tolerance": 0.0001,
    "comparison_relative_tolerance": 0.0001,
    "scope": "All eleven pinned layer0 BF16 weight tensors;FP32 activations and ordered separate FP32 products/sums. CPU nonlinear reference uses double-precision library sqrt/exp rounded toFP32,not hardware polynomial/Newton. All80 stage arrays retained;3-token causal prefill plus1 subsequent decode with persistent KV. Program owns all runtime tensor operations onFPGA. Timed CPU samples exclude asset loading and trace IO;native epoch-millisecond timer;no optimized BLAS.",
  }
  @fs.write_string_to_file(
    root + "/fixture.json",
    manifest.stringify(indent=2) + "\n",
  )
  println(
    "PASS complete layer fixture,80 CPU stage arrays,descriptors=" +
    (p.words.length() / 16).to_string(),
  )
}

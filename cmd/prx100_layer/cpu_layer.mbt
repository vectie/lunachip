///|
priv struct LayerWeights {
  tensors : Map[String, Array[Float]]
}

///|
fn LayerWeights::get(w : LayerWeights, name : String) -> Array[Float] {
  w.tensors[name]
}

///|
fn load_weights(source : String) -> LayerWeights raise {
  guard @json.parse(@fs.read_file_to_string(source + "/manifest.json"))
    is {
      "status": "PASS",
      "revision": "c1899de289a04d12100db370d81485cdf75e47ca",
      "slices": Array(slices),
      ..
    } &&
    slices.length() == 11 else {
    fail("pinned complete layer source")
  }
  let tensors : Map[String, Array[Float]] = Map([])
  for row in slices {
    guard row
      is {
        "name": String(name),
        "file": String(file),
        "sha256": String(digest),
        ..
      } else {
      fail("tensor metadata")
    }
    assert_false(file.contains("/"))
    assert_eq(hash(@fs.read_file_to_bytes(source + "/" + file)), digest)
    tensors[name.replace(old="model.layers.0.", new="")] = read_bf16(
      source + "/" + file,
    )
  }
  for
    (name, count) in [
      ("input_layernorm.weight", 1024),
      ("post_attention_layernorm.weight", 1024),
      ("self_attn.q_norm.weight", 128),
      ("self_attn.k_norm.weight", 128),
      ("self_attn.q_proj.weight", 2048 * 1024),
      ("self_attn.k_proj.weight", 1024 * 1024),
      ("self_attn.v_proj.weight", 1024 * 1024),
      ("self_attn.o_proj.weight", 1024 * 2048),
      ("mlp.gate_proj.weight", 3072 * 1024),
      ("mlp.up_proj.weight", 3072 * 1024),
      ("mlp.down_proj.weight", 1024 * 3072),
    ] {
    assert_eq(tensors[name].length(), count)
  }
  { tensors, }
}

///|
fn cpu_layer(
  w : LayerWeights,
  inputs : Array[Array[Float]],
  trace : (String, ArrayView[Float]) -> Unit raise,
) -> Array[Array[Float]] raise {
  let keys : Array[Array[Float]] = []
  let values : Array[Array[Float]] = []
  let outputs : Array[Array[Float]] = []
  for position, x in inputs {
    fn record(name : String, v : ArrayView[Float]) -> Unit raise {
      trace("t" + position.to_string() + "-" + name, v)
    }
    let normalized = rms(x, w.get("input_layernorm.weight"))
    record("input-norm", normalized)
    let q = gemv(w.get("self_attn.q_proj.weight"), normalized, 2048)
    let k = gemv(w.get("self_attn.k_proj.weight"), normalized, 1024)
    let v = gemv(w.get("self_attn.v_proj.weight"), normalized, 1024)
    record("q-raw", q)
    record("k-raw", k)
    record("v", v)
    let qn = Array::make(2048, (0.0 : Float))
    let kn = Array::make(1024, (0.0 : Float))
    for head in 0..<16 {
      let n = rms(
        q[head * 128:head * 128 + 128],
        w.get("self_attn.q_norm.weight"),
      )
      for i, v in n {
        qn[head * 128 + i] = v
      }
    }
    for head in 0..<8 {
      let n = rms(
        k[head * 128:head * 128 + 128],
        w.get("self_attn.k_norm.weight"),
      )
      for i, v in n {
        kn[head * 128 + i] = v
      }
    }
    record("q-norm", qn)
    record("k-norm", kn)
    let qr = rotate(qn, position)
    let kr = rotate(kn, position)
    record("q-rope", qr)
    record("k-rope", kr)
    keys.push(kr)
    values.push(v)
    let attention = Array::make(2048, (0.0 : Float))
    let scores : Array[Float] = []
    let probabilities : Array[Float] = []
    for head in 0..<16 {
      let kv = head / 2
      let logits = Array::make(position + 1, (0.0 : Float))
      for p in 0..<=position {
        let mut sum : Float = 0.0
        for i in 0..<128 {
          let product = qr[head * 128 + i] * keys[p][kv * 128 + i]
          sum = sum + product
        }
        logits[p] = sum * Float::from_double(1.0 / 128.0.sqrt())
      }
      let mut maximum = logits[0]
      for v in logits {
        if v > maximum {
          maximum = v
        }
      }
      let exps = logits.map(v => {
        Float::from_double(@math.exp((v - maximum).to_double()))
      })
      let mut total : Float = 0.0
      for v in exps {
        total = total + v
      }
      let inverse = (1.0 : Float) / total
      let probs = exps.map(v => v * inverse)
      for v in logits {
        scores.push(v)
      }
      for v in probs {
        probabilities.push(v)
      }
      for i in 0..<128 {
        let mut sum : Float = 0.0
        for p in 0..<=position {
          let product = probs[p] * values[p][kv * 128 + i]
          sum = sum + product
        }
        attention[head * 128 + i] = sum
      }
    }
    record("scores", scores)
    record("probabilities", probabilities)
    record("attention", attention)
    let projected = gemv(w.get("self_attn.o_proj.weight"), attention, 1024)
    record("o", projected)
    let residual = vector_add(x, projected)
    record("attention-residual", residual)
    let post = rms(residual, w.get("post_attention_layernorm.weight"))
    record("post-norm", post)
    let gate = gemv(w.get("mlp.gate_proj.weight"), post, 3072)
    let up = gemv(w.get("mlp.up_proj.weight"), post, 3072)
    record("gate", gate)
    record("up", up)
    let activated = gate.map(v => {
      let e = Float::from_double(@math.exp(-v.to_double().abs()))
      let denominator = (1.0 : Float) + e
      let inverse = (1.0 : Float) / denominator
      let weighted = if v < 0.0 { v * e } else { v }
      weighted * inverse
    })
    record("silu", activated)
    let gated = Array::makei(3072, i => activated[i] * up[i])
    record("gated", gated)
    let down = gemv(w.get("mlp.down_proj.weight"), gated, 1024)
    record("down", down)
    let output = vector_add(residual, down)
    record("output", output)
    outputs.push(output)
  }
  outputs
}

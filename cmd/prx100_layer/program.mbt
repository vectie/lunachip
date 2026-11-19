///|
priv struct LayerProgram {
  words : Array[UInt32]
  traces : Array[Json]
  assets : Array[Json]
  weights : Map[String, UInt32]
  constants : Map[String, UInt32]
  out_root : String
  mut trace_offset : UInt32
  mut constant_offset : UInt32
}

///|
fn LayerProgram::emit(
  p : LayerProgram,
  op : UInt32,
  dst : Int32,
  a : Int32,
  n : Int32,
  b~ : Int32 = 0,
  k~ : Int32 = 0,
  bs~ : Int32 = 1,
  br~ : Int32 = 0,
  ddr~ : UInt32 = 0U,
  imm~ : Float = 0.0,
  flags~ : UInt32 = 0U,
) -> Unit {
  for
    value in [
      op,
      dst.reinterpret_as_uint(),
      a.reinterpret_as_uint(),
      b.reinterpret_as_uint(),
      n.reinterpret_as_uint(),
      k.reinterpret_as_uint(),
      bs.reinterpret_as_uint(),
      br.reinterpret_as_uint(),
      ddr,
      imm.reinterpret_as_uint(),
      flags,
      0U,
      0U,
      0U,
      0U,
      0U,
    ] {
    p.words.push(value)
  }
}

///|
fn LayerProgram::constant(
  p : LayerProgram,
  name : String,
  values : ArrayView[Float],
) -> Unit raise {
  let bytes = float_bytes(values)
  let file = "constant-" + name + ".bin"
  @fs.write_bytes_to_file(p.out_root + "/" + file, bytes)
  p.constants[name] = p.constant_offset
  p.assets.push({
    "name": name,
    "file": file,
    "address": p.constant_offset,
    "bytes": bytes.length(),
    "sha256": hash(bytes),
  })
  p.constant_offset += (bytes.length().reinterpret_as_uint() + 127U) &
    0xffffff80U
}

///|
fn LayerProgram::load(
  p : LayerProgram,
  name : String,
  dst : Int32,
  n : Int32,
) -> Unit {
  p.emit(14U, dst, 0, n, ddr=p.constants[name])
}

///|
fn LayerProgram::matrix(
  p : LayerProgram,
  name : String,
  dst : Int32,
  a : Int32,
  n : Int32,
  k : Int32,
) -> Unit {
  p.emit(4U, dst, a, n, k~, ddr=p.weights[name])
}

///|
fn LayerProgram::dump(
  p : LayerProgram,
  name : String,
  src : Int32,
  n : Int32,
) -> Unit {
  p.emit(15U, 0, src, n, ddr=p.trace_offset)
  p.traces.push({
    "name": name,
    "address": p.trace_offset,
    "words": n,
    "scratch": src,
    "reference_file": "cpu-" + name + ".bin",
  })
  p.trace_offset += (n.reinterpret_as_uint() * 4U + 127U) & 0xffffff80U
}

///|
fn LayerProgram::norm(
  p : LayerProgram,
  dst : Int32,
  a : Int32,
  gamma : Int32,
  n : Int32,
) -> Unit {
  p.emit(7U, 11904, a, n)
  p.emit(
    3U,
    11904,
    11904,
    1,
    imm=Float::from_double(1.0 / n.to_double()),
    flags=2U,
  )
  p.emit(2U, 11904, 11904, 1, imm=0.000001, flags=2U)
  p.emit(10U, 11904, 11904, 1)
  p.emit(3U, dst, a, n, b=11904, flags=1U)
  p.emit(3U, dst, dst, n, b=gamma)
}

///|
fn LayerProgram::rotate(p : LayerProgram, base : Int32, heads : Int32) -> Unit {
  for h in 0..<heads {
    let a = base + h * 128
    p.emit(3U, 11712, a, 64, b=11520)
    p.emit(3U, 11776, a + 64, 64, b=11648)
    p.emit(3U, 11840, a, 64, b=11584)
    p.emit(3U, a + 64, a + 64, 64, b=11520)
    p.emit(2U, a + 64, a + 64, 64, b=11840)
    p.emit(2U, a, 11712, 64, b=11776)
  }
}

///|
fn LayerProgram::token(p : LayerProgram, position : Int32) -> Unit {
  let prefix = "t" + position.to_string() + "-"
  let context = position + 1
  p.load("embedding-" + position.to_string(), 0, 1024)
  p.load("input-gamma", 10240, 1024)
  p.norm(1024, 0, 10240, 1024)
  p.dump(prefix + "input-norm", 1024, 1024)
  for
    (name, dst, n) in [("q", 2048, 2048), ("k", 4096, 1024), ("v", 5120, 1024)] {
    p.matrix(name, dst, 1024, n, 1024)
    p.dump(prefix + (if name == "v" { "v" } else { name + "-raw" }), dst, n)
  }
  p.load("q-gamma", 11264, 128)
  p.load("k-gamma", 11392, 128)
  for h in 0..<16 {
    p.norm(2048 + h * 128, 2048 + h * 128, 11264, 128)
  }
  for h in 0..<8 {
    p.norm(4096 + h * 128, 4096 + h * 128, 11392, 128)
  }
  p.dump(prefix + "q-norm", 2048, 2048)
  p.dump(prefix + "k-norm", 4096, 1024)
  for (name, dst) in [("cos", 11520), ("sin", 11584), ("negative-sin", 11648)] {
    p.load(name + "-" + position.to_string(), dst, 64)
  }
  p.rotate(2048, 16)
  p.rotate(4096, 8)
  p.dump(prefix + "q-rope", 2048, 2048)
  p.dump(prefix + "k-rope", 4096, 1024)
  p.emit(1U, 16384 + position * 1024, 4096, 1024)
  p.emit(1U, 24576 + position * 1024, 5120, 1024)
  for h in 0..<16 {
    let score = 12032 + h * context
    let probability = 12160 + h * context
    let kv = h / 2
    p.emit(
      5U,
      score,
      2048 + h * 128,
      context,
      b=16384 + kv * 128,
      k=128,
      bs=1,
      br=1024,
    )
    p.emit(
      3U,
      score,
      score,
      context,
      imm=Float::from_double(1.0 / 128.0.sqrt()),
      flags=2U,
    )
    p.emit(8U, 11904, score, context)
    p.emit(3U, 11904, 11904, 1, imm=-1.0, flags=2U)
    p.emit(2U, probability, score, context, b=11904, flags=1U)
    p.emit(11U, probability, probability, context)
    p.emit(6U, 11904, probability, context)
    p.emit(9U, 11904, 11904, 1)
    p.emit(3U, probability, probability, context, b=11904, flags=1U)
    p.emit(
      5U,
      6144 + h * 128,
      probability,
      128,
      b=24576 + kv * 128,
      k=context,
      bs=1024,
      br=1,
    )
  }
  p.dump(prefix + "scores", 12032, 16 * context)
  p.dump(prefix + "probabilities", 12160, 16 * context)
  p.dump(prefix + "attention", 6144, 2048)
  p.matrix("o", 1024, 6144, 1024, 2048)
  p.dump(prefix + "o", 1024, 1024)
  p.emit(2U, 8192, 0, 1024, b=1024)
  p.dump(prefix + "attention-residual", 8192, 1024)
  p.load("post-gamma", 10240, 1024)
  p.norm(9216, 8192, 10240, 1024)
  p.dump(prefix + "post-norm", 9216, 1024)
  p.matrix("gate", 10240, 9216, 3072, 1024)
  p.dump(prefix + "gate", 10240, 3072)
  p.matrix("up", 13312, 9216, 3072, 1024)
  p.dump(prefix + "up", 13312, 3072)
  p.emit(12U, 1024, 10240, 3072)
  p.emit(11U, 1024, 1024, 3072)
  p.emit(2U, 4096, 1024, 3072, imm=1.0, flags=2U)
  p.emit(9U, 4096, 4096, 3072)
  p.emit(13U, 1024, 10240, 3072, b=1024)
  p.emit(3U, 1024, 1024, 3072, b=4096)
  p.dump(prefix + "silu", 1024, 3072)
  p.emit(3U, 10240, 1024, 3072, b=13312)
  p.dump(prefix + "gated", 10240, 3072)
  p.matrix("down", 9216, 10240, 1024, 3072)
  p.dump(prefix + "down", 9216, 1024)
  p.emit(2U, 0, 8192, 1024, b=9216)
  p.dump(prefix + "output", 0, 1024)
}

///|
fn decode_word(bytes : Bytes, i : Int32) -> UInt32 {
  let a = i * 4
  bytes[a].to_uint() |
  (bytes[a + 1].to_uint() << 8) |
  (bytes[a + 2].to_uint() << 16) |
  (bytes[a + 3].to_uint() << 24)
}

///|
fn approximate_unary(op : UInt32, x : Float) -> Float {
  if op == 11U {
    if x < -32.0 {
      return 0.0
    }
    if x > 32.0 {
      return Float::reinterpret_from_uint(0x7f800000U)
    }
    let reduced = x * (1.0 / 64.0 : Float)
    let mut y = Float::from_double(1.0 / 40320.0)
    for
      c in [
        1.0 / 5040.0,
        1.0 / 720.0,
        1.0 / 120.0,
        1.0 / 24.0,
        1.0 / 6.0,
        0.5,
        1.0,
        1.0,
      ] {
      let product = y * reduced
      y = product + Float::from_double(c)
    }
    for _ in 0..<6 {
      y = y * y
    }
    y
  } else if op == 9U {
    let mut y = Float::reinterpret_from_uint(
      0x7ef311c3U - x.reinterpret_as_uint(),
    )
    for _ in 0..<4 {
      let product = x * y
      let difference = (2.0 : Float) - product
      y = y * difference
    }
    y
  } else {
    let mut y = Float::reinterpret_from_uint(
      0x5f375a86U - (x.reinterpret_as_uint() >> 1),
    )
    let half = x * (0.5 : Float)
    for _ in 0..<4 {
      let squared = y * y
      let product = half * squared
      let difference = (1.5 : Float) - product
      y = y * difference
    }
    y
  }
}

///|
fn emulate_fixture(root : String, out : String) -> Unit raise {
  guard !@fs.path_exists(out) else { fail("fresh emulation output") }
  @fs.create_dir(out)
  guard @json.parse(@fs.read_file_to_string(root + "/fixture.json"))
    is {
      "assets": Array(assets),
      "traces": Array(traces),
      "program_sha256": String(pin),
      ..
    } else {
    fail("fixture")
  }
  let program = @fs.read_file_to_bytes(root + "/program.bin")
  assert_eq(hash(program), pin)
  assert_eq(program.length() % 64, 0)
  let blobs : Map[UInt32, Bytes] = Map([])
  for asset in assets {
    guard asset
      is {
        "address": Number(address, ..),
        "file": String(file),
        "sha256": String(pin),
        ..
      } else {
      fail("asset")
    }
    let bytes = @fs.read_file_to_bytes(root + "/" + file)
    assert_eq(hash(bytes), pin)
    blobs[address.to_uint()] = bytes
  }
  let scratch = Array::make(32768, Float::reinterpret_from_uint(0x7fc00000U))
  let checks : Array[Json] = []
  fn read(i : Int32) -> Float raise {
    assert_true(i >= 0 && i < 32768)
    let v = scratch[i]
    assert_true(
      (v.reinterpret_as_uint() & 0x7f800000U) != 0x7f800000U,
      msg="uninitialized/nonfinite scratch " + i.to_string(),
    )
    v
  }
  let mut halted = false
  for pc in 0..<(program.length() / 64) {
    assert_false(halted)
    let row = Array::makei(16, j => decode_word(program, pc * 16 + j))
    let op = row[0]
    let dst = row[1].reinterpret_as_int()
    let a = row[2].reinterpret_as_int()
    let b = row[3].reinterpret_as_int()
    let n = row[4].reinterpret_as_int()
    let k = row[5].reinterpret_as_int()
    let bs = row[6].reinterpret_as_int()
    let br = row[7].reinterpret_as_int()
    let address = row[8]
    let immediate = Float::reinterpret_from_uint(row[9])
    let flags = row[10]
    match op {
      0U => halted = true
      4U | 5U =>
        for r in 0..<n {
          let mut sum : Float = 0.0
          for i in 0..<k {
            let x = read(a + i)
            let y = if op == 4U {
              let blob = blobs[address]
              let j = (r * k + i) * 2
              Float::reinterpret_from_uint(
                (blob[j].to_uint() | (blob[j + 1].to_uint() << 8)) << 16,
              )
            } else {
              read(b + r * br + i * bs)
            }
            let product = x * y
            sum = sum + product
          }
          scratch[dst + r] = sum
        }
      6U | 7U | 8U => {
        let mut sum : Float = if op == 8U {
          Float::reinterpret_from_uint(0xff800000U)
        } else {
          0.0
        }
        for i in 0..<n {
          let x = read(a + i)
          if op == 8U {
            if x > sum {
              sum = x
            }
          } else {
            let value = if op == 7U { x * x } else { x }
            sum = sum + value
          }
        }
        scratch[dst] = sum
      }
      14U => {
        let bytes = blobs[address]
        assert_eq(bytes.length(), n * 4)
        for i in 0..<n {
          scratch[dst + i] = Float::reinterpret_from_uint(decode_word(bytes, i))
        }
      }
      15U => {
        let trace = traces
          .iter()
          .find_first(t => {
            match t {
              { "address": Number(v, ..), .. } => v.to_uint() == address
              _ => false
            }
          })
          .unwrap()
        guard trace
          is {
            "name": String(name),
            "words": Number(words, ..),
            "reference_file": String(file),
            ..
          } else {
          fail("trace")
        }
        assert_eq(words.to_int(), n)
        let expected = @fs.read_file_to_bytes(root + "/" + file)
        let actual = Array::makei(n, i => read(a + i))
        let mut max_abs = 0.0
        let mut max_rel = 0.0
        let mut exact = 0
        for i, v in actual {
          let reference = Float::reinterpret_from_uint(decode_word(expected, i))
          let error = (v.to_double() - reference.to_double()).abs()
          max_abs = max_abs.max(error)
          max_rel = max_rel.max(
            error / reference.to_double().abs().max(0.000001),
          )
          if v.reinterpret_as_uint() == reference.reinterpret_as_uint() {
            exact += 1
          }
          assert_true(
            error <= 0.0001 + 0.0001 * reference.to_double().abs(),
            msg=name + "[" + i.to_string() + "] error=" + error.to_string(),
          )
        }
        @fs.write_bytes_to_file(out + "/" + name + ".bin", float_bytes(actual))
        checks.push({
          "name": name,
          "words": n,
          "bit_exact_words": exact,
          "max_absolute_error": max_abs,
          "max_relative_error_above_floor": max_rel,
          "sha256": hash(float_bytes(actual)),
        })
      }
      _ => {
        assert_true([1U, 2U, 3U, 9U, 10U, 11U, 12U, 13U].contains(op))
        for i in 0..<n {
          let x = read(a + i)
          let y = if flags == 2U {
            immediate
          } else if flags == 1U {
            read(b)
          } else if [2U, 3U, 13U].contains(op) {
            read(b + i)
          } else {
            0.0
          }
          scratch[dst + i] = match op {
            1U => x
            2U => x + y
            3U => x * y
            9U | 10U | 11U => approximate_unary(op, x)
            12U =>
              Float::reinterpret_from_uint(
                x.reinterpret_as_uint() | 0x80000000U,
              )
            13U =>
              x *
              (if (x.reinterpret_as_uint() & 0x80000000U) != 0U {
                y
              } else {
                1.0
              })
            _ => abort("opcode")
          }
        }
      }
    }
  }
  assert_true(halted)
  assert_eq(checks.length(), 80)
  @fs.write_string_to_file(
    out + "/emulation.json",
    (
      {
        "status": "PASS",
        "stages": checks,
        "program_sha256": pin,
        "scope": "Independent scalar execution of actual2025-descriptor program with poisoned scratch and chosen FP32 Newton/polynomial operations;all80 full-shape stages checked against high-level CPU layer using library nonlinear functions at predeclared1e-4+1e-4*abs tolerance. This is program/numerical validation,not RTL or physical execution.",
      } : Json).stringify(indent=2) +
    "\n",
  )
  println(
    "PASS complete program schedule and80 nonlinear CPU-reference stage comparisons",
  )
}

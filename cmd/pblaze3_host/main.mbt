///|
fn number(text : String) -> UInt64 raise {
  @string.parse_uint64(text, base=0)
}

///|
fn size(text : String) -> Int32 raise {
  let value = number(text)
  guard value <= 1048576 else { fail("chunk length exceeds 1MiB") }
  value.to_int()
}

///|
fn new_file(path : String, bytes : Bytes) -> Unit raise {
  guard !@fs.path_exists(path) else { fail("output already exists: " + path) }
  @fs.write_bytes_to_file(path, bytes)
}

///|
fn run() -> Unit raise {
  let m = @host.default_manifest()
  match @env.args()[1:] {
    ["prepare-smoke", bundle, root] => prepare_smoke(bundle, root)
    ["manifest"] => println(m.to_json().stringify(indent=2))
    ["plan"] => {
      println(m.to_json().stringify(indent=2))
      println("Build: moon build --target native cmd/pblaze3_host")
      println("DDR-only image: ddr-smoke-probe -> ddr-smoke-memtest smoke/full")
      println(
        "Accelerator image: probe -> status -> memtest -> fixture campaign",
      )
      println(
        "Hardware commands require XDMA tools, device prefix and a new evidence directory.",
      )
    }
    ["validate-manifest", path] => {
      let manifest : @host.Manifest = @json.from_json(
        @json.parse(@fs.read_file_to_string(path)),
      )
      manifest.validate()
      println("manifest accepted: pblaze3-2gib")
    }
    ["range", address, length] => {
      m.check_range(number(address), number(length))
      println("range accepted")
    }
    ["pattern", address, length, seed, path] => {
      new_file(path, @host.pattern(number(address), size(length), number(seed)))
      println("pattern written")
    }
    ["verify", address, seed, path] => {
      let actual = @fs.read_file_to_bytes(path)
      let address = number(address)
      @host.compare(
        address,
        @host.pattern(address, actual.length(), number(seed)),
        actual,
      )
      println("pattern verified")
    }
    ["compare", address, expected, actual] => {
      @host.compare(
        number(address),
        @fs.read_file_to_bytes(expected),
        @fs.read_file_to_bytes(actual),
      )
      println("bytes verified")
    }
    ["compare-fp32", expected, actual] =>
      println(
        @host.compare_fp32(
          @fs.read_file_to_bytes(expected),
          @fs.read_file_to_bytes(actual),
        )
        .to_json()
        .stringify(),
      )
    ["dma-read", device, address, length, file] =>
      println(
        @host.dma_command(
          m,
          write=false,
          device,
          number(address),
          size(length),
          file,
        )
        .to_json()
        .stringify(),
      )
    ["dma-write", device, address, length, file] =>
      println(
        @host.dma_command(
          m,
          write=true,
          device,
          number(address),
          size(length),
          file,
        )
        .to_json()
        .stringify(),
      )
    ["reg-read", device, offset] =>
      println(
        @host.register_command(m, device, number(offset), None)
        .to_json()
        .stringify(),
      )
    ["reg-write", device, offset, value] => {
      let word = number(value)
      guard word <= 0xffffffff else { fail("register value exceeds UInt32") }
      println(
        @host.register_command(m, device, number(offset), Some(word.to_uint()))
        .to_json()
        .stringify(),
      )
    }
    ["smoke-plan"] => println(Json(@host.smoke_addresses()).stringify())
    ["status-plan"] => println(Json(@host.status_offsets()).stringify())
    ["smoke-status", value] => {
      let word = number(value)
      guard word <= 0xffffffff else { fail("smoke status exceeds UInt32") }
      println(@host.decode_smoke_status(word.to_uint()).to_json().stringify())
    }
    ["status-decode", path] => {
      let words : Array[UInt32] = @json.from_json(
        @json.parse(@fs.read_file_to_string(path)),
      )
      println(@host.decode_status(words).to_json().stringify(indent=2))
    }
    ["launch-check", previous, count, path] => {
      let before = number(previous)
      let count = number(count)
      guard before <= 0xffffffff && count > 0 && count <= 2048 else {
        fail("launch identity range")
      }
      let words : Array[UInt32] = @json.from_json(
        @json.parse(@fs.read_file_to_string(path)),
      )
      println(
        if @host.check_launch(
            before.to_uint(),
            count.to_uint(),
            @host.decode_status(words),
          ) {
          "complete"
        } else {
          "pending"
        },
      )
    }
    ["program-plan", device, path] =>
      println(
        Json(@host.program_commands(m, device, @fs.read_file_to_bytes(path))).stringify(),
      )
    ["scratch-plan", device, path] =>
      println(
        Json(@host.scratch_commands(m, device, @fs.read_file_to_bytes(path))).stringify(),
      )
    ["start-plan", device, count] => {
      let count = number(count)
      guard count <= 2048 else { fail("instruction count exceeds 2048") }
      println(Json(@host.start_commands(m, device, count.to_int())).stringify())
    }
    ["selftest"] => {
      let memory : Map[UInt64, Byte] = Map([])
      let transport : @host.Transport = {
        read: (address, length) => {
          Bytes::makei(length, i => {
            memory.get(address + i.to_uint64()).unwrap_or(0)
          })
        },
        write: (address, bytes) => {
          for i, byte in bytes {
            memory[address + i.to_uint64()] = byte
          }
          bytes.length()
        },
      }
      @host.memory_smoke(m, transport, 42)
      println(
        "offline sparse 2GiB address-space smoke passed; no hardware accessed",
      )
    }
    _ =>
      fail(
        "usage: manifest | validate-manifest FILE | range ADDRESS BYTES | pattern ADDRESS BYTES SEED FILE | verify ADDRESS SEED FILE | compare ADDRESS EXPECTED ACTUAL | dma-read/dma-write DEVICE ADDRESS BYTES FILE | reg-read DEVICE OFFSET | reg-write DEVICE OFFSET VALUE | smoke-plan | selftest",
      )
  }
}

///|
fn main {
  run() catch {
    error => abort("\{Repr(error)}")
  }
}

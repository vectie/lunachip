///|
priv struct Region {
  name : String
  address : UInt32
  words : Array[UInt32]
} derive(FromJson)

///|
priv struct Job {
  name : String
  program_words : Array[UInt32]
  assets : Array[Region]
  scratch_words : Array[UInt32]?
  outputs : Array[Region]
} derive(FromJson)

///|
priv struct Bundle {
  jobs : Array[Job]
} derive(FromJson)

///|
fn encoded_words(words : Array[UInt32]) -> Bytes {
  Bytes::makei(words.length() * 4, i => (words[i / 4] >> (i % 4 * 8)).to_byte())
}

///|
fn digest(bytes : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
fn simple_name(name : String) -> Bool {
  name.length() > 0 &&
  name.length() <= 100 &&
  name
  .iter()
  .all(c => {
    match c {
      'a'..<='z' | 'A'..<='Z' | '0'..<='9' | '-' | '_' => true
      _ => false
    }
  })
}

///|
fn prepare_smoke(path : String, root : String) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("smoke output must be new") }
  let source = @fs.read_file_to_bytes(path)
  let bundle : Bundle = @json.from_json(
    @json.parse(@fs.read_file_to_string(path)),
  )
  guard bundle.jobs.length() > 0 else { fail("empty smoke bundle") }
  let names : Map[String, Bool] = Map([])
  for job in bundle.jobs {
    guard simple_name(job.name) &&
      !names.contains(job.name) &&
      job.program_words.length() > 0 &&
      job.program_words.length() <= 32768 &&
      job.program_words.length() % 16 == 0 &&
      job.scratch_words.unwrap_or([]).length() <= 32768 &&
      job.assets.length() > 0 &&
      job.outputs.length() > 0 else {
      fail("invalid smoke job shape or duplicate name")
    }
    names[job.name] = true
    for region in [..job.assets, ..job.outputs] {
      guard simple_name(region.name) &&
        region.words.length() > 0 &&
        region.words.length() <= 262144 else {
        fail("invalid smoke region")
      }
      @host.default_manifest().check_range(
        region.address.to_uint64(),
        (region.words.length() * 4).to_uint64(),
      )
    }
  }
  @fs.create_dir(root)
  @fs.write_bytes_to_file(root + "/source-bundle.json", source)
  let jobs : Array[Json] = []
  for job in bundle.jobs {
    let directory = root + "/" + job.name
    @fs.create_dir(directory)
    let program = encoded_words(job.program_words)
    @fs.write_bytes_to_file(directory + "/program.bin", program)
    let assets : Array[Json] = []
    for index, region in job.assets {
      let file = "asset-" + index.to_string() + ".bin"
      let bytes = encoded_words(region.words)
      @fs.write_bytes_to_file(directory + "/" + file, bytes)
      assets.push({
        "name": region.name,
        "file": file,
        "address": region.address,
        "bytes": bytes.length(),
        "sha256": digest(bytes),
      })
    }
    let traces : Array[Json] = []
    let references : Array[Json] = []
    for index, region in job.outputs {
      let file = "cpu-" + index.to_string() + ".bin"
      let bytes = encoded_words(region.words)
      ignore(@host.compare_fp32(bytes, bytes))
      @fs.write_bytes_to_file(directory + "/" + file, bytes)
      traces.push({
        "name": region.name,
        "reference_file": file,
        "address": region.address,
        "words": region.words.length(),
      })
      references.push({
        "file": file,
        "words": region.words.length(),
        "sha256": digest(bytes),
      })
    }
    let fields : Map[String, Json] = {
      "status": "PASS",
      "scope": "offline PBlaze3 integrated smoke inputs; not physical execution",
      "assets": Json(assets),
      "traces": Json(traces),
      "cpu_traces": Json(references),
      "program_descriptors": Json(job.program_words.length() / 16),
      "program_sha256": Json(digest(program)),
      "comparison_absolute_tolerance": 0.0001,
      "comparison_relative_tolerance": 0.0001,
    }
    let scratch_words = job.scratch_words.unwrap_or([])
    if !scratch_words.is_empty() {
      let scratch = encoded_words(scratch_words)
      @fs.write_bytes_to_file(directory + "/scratch.bin", scratch)
      fields["scratch_file"] = "scratch.bin"
      fields["scratch_sha256"] = Json(digest(scratch))
    }
    let manifest = Json::object(fields).stringify(indent=2) + "\n"
    @fs.write_string_to_file(directory + "/fixture.json", manifest)
    let bytes = @fs.read_file_to_bytes(directory + "/fixture.json")
    jobs.push({
      "name": job.name,
      "directory": directory,
      "fixture_sha256": digest(bytes),
    })
  }
  let summary : Json = { "source_sha256": digest(source), "jobs": Json(jobs) }
  @fs.write_string_to_file(
    root + "/jobs.json",
    summary.stringify(indent=2) + "\n",
  )
  println(summary.stringify(indent=2))
}

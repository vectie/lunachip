///|
fn artifacts(kind : String) -> ReadOnlyArray[@projection.Artifact] raise {
  match kind {
    "mig-profile-replay" => @layer.mig_profile_replay()
    "export" => @validation.replay_bundle()
    "stream-replay" => @validation.replay_bundle(streaming=true)
    "stream-formal" => @validation.formal_bundle(streaming=true)
    "group32k-bridge-formal"
    | "group32k-bridge-negative"
    | "strided-bridge-formal"
    | "ordered-group-bridge-formal"
    | "ordered-group-stripe512-formal"
    | "ordered-group-stripe512-negative"
    | "ordered-group-stripe512-prefetch-formal"
    | "ordered-group-stripe512-prefetch-negative"
    | "ordered-group-bridge-negative"
    | "strided-bridge-negative" =>
      @validation.formal_bundle(
        streaming=true,
        wide512=true,
        wide1024=true,
        deep_batch=true,
        strided_rows=kind.has_prefix("strided-") ||
          kind.has_prefix("ordered-group-"),
        group64_rows=kind.has_prefix("ordered-group-"),
        stripe512=kind.has_prefix("ordered-group-stripe512-"),
        prefetch_row_blocks=kind.has_prefix("ordered-group-stripe512-prefetch-"),
        negative=kind.has_suffix("negative"),
      )
    "group32k-controller-formal"
    | "group32k-controller-negative"
    | "strided-controller-formal"
    | "strided-controller-negative" =>
      @layer.resident_formal_bundle(
        chain=true,
        program_bursts=true,
        stream_unary=true,
        indirect_bf16=true,
        deep_batch=true,
        strided_rows=kind.has_prefix("strided-"),
        negative=kind.has_suffix("negative"),
      )
    "prefetch64-formal" =>
      @validation.formal_bundle(streaming=true, wide512=true, wide1024=true)
    "prefetch64-negative" =>
      @validation.formal_bundle(
        streaming=true,
        wide512=true,
        wide1024=true,
        negative=true,
      )
    "wide512-formal" => @validation.formal_bundle(streaming=true, wide512=true)
    "wide512-negative" =>
      @validation.formal_bundle(streaming=true, wide512=true, negative=true)
    "stream-negative" =>
      @validation.formal_bundle(streaming=true, negative=true)
    "layer-replay" => @layer.replay_bundle()
    "prefetch64-layer-replay"
    | "scalar-lines-layer-replay"
    | "store-bursts-layer-replay"
    | "chain-layer-replay"
    | "program-bursts-layer-replay"
    | "stream-unary-layer-replay"
    | "staged-decode-layer-replay"
    | "stream-reductions-layer-replay"
    | "paired-rows-layer-replay"
    | "full-rows-layer-replay"
    | "dual-read-layer-replay"
    | "bf16-load-layer-replay"
    | "bounded-add-layer-replay"
    | "group32k-layer-replay"
    | "strided-rows-layer-replay" => {
      let strided_rows = kind == "strided-rows-layer-replay"
      let deep_batch = strided_rows || kind == "group32k-layer-replay"
      let bounded_add = deep_batch || kind == "bounded-add-layer-replay"
      let indirect_bf16 = bounded_add || kind == "bf16-load-layer-replay"
      let dual_read = indirect_bf16 || kind == "dual-read-layer-replay"
      let full_rows = dual_read || kind == "full-rows-layer-replay"
      let paired_rows = full_rows || kind == "paired-rows-layer-replay"
      let stream_reductions = paired_rows ||
        kind == "stream-reductions-layer-replay"
      let staged_decode = stream_reductions ||
        kind == "staged-decode-layer-replay"
      let stream_unary = staged_decode || kind == "stream-unary-layer-replay"
      @layer.replay_bundle(
        streaming=true,
        profile=true,
        vectors=true,
        wide512=true,
        rows64=true,
        banked64=true,
        prefetch256=true,
        scalar_lines=kind != "prefetch64-layer-replay",
        store_bursts=kind == "store-bursts-layer-replay" ||
          kind == "chain-layer-replay" ||
          kind == "program-bursts-layer-replay" ||
          stream_unary,
        chain=kind == "chain-layer-replay" ||
          kind == "program-bursts-layer-replay" ||
          stream_unary,
        stream_unary~,
        staged_decode~,
        stream_reductions~,
        paired_rows~,
        full_rows~,
        dual_read~,
        indirect_bf16~,
        bounded_add~,
        deep_batch~,
        strided_rows~,
        program_bursts=kind == "program-bursts-layer-replay" || stream_unary,
      )
    }
    "banked64-layer-replay" =>
      @layer.replay_bundle(
        streaming=true,
        profile=true,
        vectors=true,
        wide512=true,
        rows64=true,
        banked64=true,
      )
    "rows64-layer-replay" =>
      @layer.replay_bundle(
        streaming=true,
        profile=true,
        vectors=true,
        wide512=true,
        rows64=true,
      )
    "wide512-layer-replay" =>
      @layer.replay_bundle(
        streaming=true,
        profile=true,
        vectors=true,
        wide512=true,
      )
    "stream-layer-replay" => @layer.replay_bundle(streaming=true)
    "profile-layer-replay" => @layer.replay_bundle(streaming=true, profile=true)
    "vector-layer-replay" =>
      @layer.replay_bundle(streaming=true, profile=true, vectors=true)
    "formal-positive" => @validation.formal_bundle()
    "formal-negative" => @validation.formal_bundle(negative=true)
    "bf16-load-formal"
    | "bf16-load-negative"
    | "stream-unary-formal"
    | "stream-unary-negative" =>
      @layer.resident_formal_bundle(
        chain=true,
        program_bursts=true,
        stream_unary=true,
        indirect_bf16=kind.has_prefix("bf16-load"),
        negative=kind.has_suffix("-negative"),
      )
    "program-bursts-formal" =>
      @layer.resident_formal_bundle(chain=true, program_bursts=true)
    "program-bursts-negative" =>
      @layer.resident_formal_bundle(
        chain=true,
        program_bursts=true,
        negative=true,
      )
    "chain-formal" => @layer.resident_formal_bundle(chain=true)
    "chain-negative" => @layer.resident_formal_bundle(chain=true, negative=true)
    "resident-formal" => @layer.resident_formal_bundle()
    "profile-formal" => @layer.resident_formal_bundle(profile=true)
    "profile-negative" =>
      @layer.resident_formal_bundle(profile=true, negative=true)
    "resident-negative" => @layer.resident_formal_bundle(negative=true)
    _ => fail("unknown PBlaze3 AXI fixture kind")
  }
}

///|
fn save(
  root : String,
  files : ReadOnlyArray[@projection.Artifact],
) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh output directory required") }
  @fs.create_dir(root)
  let seen : Map[String, Bool] = Map([])
  for file in files {
    guard file.path != "" &&
      file.path != "." &&
      file.path != ".." &&
      !file.path.contains("/") &&
      !file.path.contains("\\") &&
      !seen.contains(file.path) else {
      fail("flat, unique fixture paths required")
    }
    seen[file.path] = true
    @fs.write_string_to_file(root + "/" + file.path, file.content)
  }
}

///|
fn deterministic(root : String, kind : String) -> Unit raise {
  let files = artifacts(kind)
  for file in files {
    assert_eq(
      @fs.read_file_to_string(root + "/" + file.path),
      file.content,
      msg="fresh elaboration differs at " + file.path,
    )
  }
  println(
    "PASS deterministic " + kind + ": " + files.length().to_string() + " files",
  )
}

///|
fn main raise {
  match @env.args()[1:] {
    [kind, root] if [
        "mig-profile-replay", "ordered-group-bridge-formal", "ordered-group-bridge-negative",
        "ordered-group-stripe512-formal", "ordered-group-stripe512-negative", "ordered-group-stripe512-prefetch-formal",
        "ordered-group-stripe512-prefetch-negative", "strided-rows-layer-replay",
        "strided-bridge-formal", "strided-bridge-negative", "strided-controller-formal",
        "strided-controller-negative", "group32k-bridge-formal", "group32k-bridge-negative",
        "group32k-controller-formal", "group32k-controller-negative", "group32k-layer-replay",
        "bounded-add-layer-replay", "bf16-load-layer-replay", "dual-read-layer-replay",
        "full-rows-layer-replay", "paired-rows-layer-replay", "export", "layer-replay",
        "formal-positive", "formal-negative", "resident-formal", "resident-negative",
        "stream-replay", "stream-formal", "stream-negative", "stream-layer-replay",
        "profile-layer-replay", "vector-layer-replay", "profile-formal", "profile-negative",
        "wide512-layer-replay", "rows64-layer-replay", "banked64-layer-replay", "prefetch64-layer-replay",
        "scalar-lines-layer-replay", "store-bursts-layer-replay", "bf16-load-formal",
        "bf16-load-negative", "stream-unary-formal", "stream-unary-negative", "stream-unary-layer-replay",
        "staged-decode-layer-replay", "stream-reductions-layer-replay", "program-bursts-layer-replay",
        "program-bursts-formal", "program-bursts-negative", "chain-layer-replay",
        "chain-formal", "chain-negative", "wide512-formal", "wide512-negative", "prefetch64-formal",
        "prefetch64-negative",
      ].contains(kind) => {
      save(root, artifacts(kind))
      println("Exported PBlaze3 AXI " + kind + " to " + root)
    }
    ["deterministic", kind, root] => deterministic(root, kind)
    [check, root, actual] if [
        "verify-strided-rows-layer", "verify-group32k-layer", "verify-bounded-add-layer",
        "verify-bf16-load-layer", "verify-dual-read-layer", "verify-full-rows-layer",
        "verify-paired-rows-layer", "verify", "verify-layer", "verify-stream", "verify-stream-layer",
        "verify-wide512-layer", "verify-rows64-layer", "verify-banked64-layer", "verify-prefetch64-layer",
        "verify-scalar-lines-layer", "verify-store-bursts-layer", "verify-chain-layer",
        "verify-program-bursts-layer", "verify-stream-unary-layer", "verify-staged-decode-layer",
        "verify-stream-reductions-layer",
      ].contains(check) => {
      let kind = match check {
        "verify-strided-rows-layer" => "strided-rows-layer-replay"
        "verify-group32k-layer" => "group32k-layer-replay"
        "verify-bounded-add-layer" => "bounded-add-layer-replay"
        "verify-bf16-load-layer" => "bf16-load-layer-replay"
        "verify-dual-read-layer" => "dual-read-layer-replay"
        "verify-full-rows-layer" => "full-rows-layer-replay"
        "verify-paired-rows-layer" => "paired-rows-layer-replay"
        "verify" => "export"
        "verify-layer" => "layer-replay"
        "verify-wide512-layer" => "wide512-layer-replay"
        "verify-scalar-lines-layer" => "scalar-lines-layer-replay"
        "verify-stream-unary-layer" => "stream-unary-layer-replay"
        "verify-staged-decode-layer" => "staged-decode-layer-replay"
        "verify-stream-reductions-layer" => "stream-reductions-layer-replay"
        "verify-program-bursts-layer" => "program-bursts-layer-replay"
        "verify-chain-layer" => "chain-layer-replay"
        "verify-store-bursts-layer" => "store-bursts-layer-replay"
        "verify-prefetch64-layer" => "prefetch64-layer-replay"
        "verify-banked64-layer" => "banked64-layer-replay"
        "verify-rows64-layer" => "rows64-layer-replay"
        "verify-stream" => "stream-replay"
        _ => "stream-layer-replay"
      }
      deterministic(root, kind)
      assert_eq(
        @fs.read_file_to_string(actual),
        @fs.read_file_to_string(root + "/expected.tsv"),
        msg="pinned Verilator output differs from fresh LunaWave replay",
      )
      println("PASS PBlaze3 AXI LunaWave/Verilator byte-exact replay")
    }
    _ =>
      fail(
        "FIXTURE_KIND NEW_DIR; deterministic KIND DIR; verify|verify-layer|verify-stream|verify-stream-layer REPLAY_DIR ACTUAL_TSV",
      )
  }
}

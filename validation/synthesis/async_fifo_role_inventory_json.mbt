///|
fn inventory_string_array(value : Json, path : String) -> Array[String] raise {
  let values = premap_array(value, path)
  let out : Array[String] = []
  for index, value in values {
    out.push(premap_string(value, "\{path}[\{index}]"))
  }
  out
}

///|
fn parse_inventory_reset(
  value : Json,
  path : String,
) -> AsyncFifoResetRole raise {
  let fields = premap_object(value, path)
  premap_exact_keys(fields, path, ["signal", "kind", "polarity", "value"])
  let reset = {
    signal: premap_string(
      premap_field(fields, path, "signal"),
      "\{path}.signal",
    ),
    kind: premap_string(premap_field(fields, path, "kind"), "\{path}.kind"),
    polarity: premap_string(
      premap_field(fields, path, "polarity"),
      "\{path}.polarity",
    ),
    value: premap_string(premap_field(fields, path, "value"), "\{path}.value"),
  }
  if reset.kind != "synchronous" ||
    reset.polarity != "high" ||
    reset.value != "zero" {
    raise InvalidValue(path~, value="unsupported reset contract")
  }
  reset
}

///|
fn parse_inventory_domain(
  value : Json,
  path : String,
) -> AsyncFifoDomainRole raise {
  let fields = premap_object(value, path)
  premap_exact_keys(fields, path, ["clock", "edge", "reset"])
  let edge = premap_string(premap_field(fields, path, "edge"), "\{path}.edge")
  if edge != "positive" {
    raise InvalidValue(path="\{path}.edge", value=edge)
  }
  {
    clock: premap_string(premap_field(fields, path, "clock"), "\{path}.clock"),
    edge,
    reset: parse_inventory_reset(
      premap_field(fields, path, "reset"),
      "\{path}.reset",
    ),
  }
}

///|
fn parse_inventory_lanes(value : Json) -> Array[AsyncFifoLaneRole] raise {
  let values = premap_array(value, "$.lanes")
  let lanes : Array[AsyncFifoLaneRole] = []
  for position, value in values {
    let path = "$.lanes[\{position}]"
    let fields = premap_object(value, path)
    premap_exact_keys(fields, path, [
      "index", "memory", "width", "source_payload", "raw_read", "visible_payload",
    ])
    let index = premap_int(premap_field(fields, path, "index"), "\{path}.index")
    let width = premap_int(premap_field(fields, path, "width"), "\{path}.width")
    if index != position || width <= 0 {
      raise InvalidValue(path~, value="lane index/width")
    }
    lanes.push({
      index,
      memory: premap_string(
        premap_field(fields, path, "memory"),
        "\{path}.memory",
      ),
      width,
      source_payload: premap_string(
        premap_field(fields, path, "source_payload"),
        "\{path}.source_payload",
      ),
      raw_read: premap_string(
        premap_field(fields, path, "raw_read"),
        "\{path}.raw_read",
      ),
      visible_payload: premap_string(
        premap_field(fields, path, "visible_payload"),
        "\{path}.visible_payload",
      ),
    })
  }
  if lanes.is_empty() {
    raise InvalidValue(path="$.lanes", value="empty lane list")
  }
  lanes
}

///|
fn validate_inventory_expected_contract(value : Json) -> Unit raise {
  let path = "$.expected_contract"
  let fields = premap_object(value, path)
  premap_exact_keys(fields, path, [
    "kind", "pre_map_typed_graph", "ram_mapping", "timing", "physical_cdc", "metastability",
    "four_state_equivalence",
  ])
  if premap_string(premap_field(fields, path, "kind"), "\{path}.kind") !=
    "canonical-ir-role-inventory-only" {
    raise InvalidValue(path="\{path}.kind", value="unexpected contract value")
  }
  for
    key in [
      "pre_map_typed_graph", "ram_mapping", "timing", "physical_cdc", "metastability",
      "four_state_equivalence",
    ] {
    if !(premap_field(fields, path, key) is False) {
      raise InvalidValue(path="\{path}.\{key}", value="expected false")
    }
  }
}

///|
fn parse_async_fifo_role_inventory_v2(
  source : String,
) -> AsyncFifoRoleInventoryV2 raise {
  let parsed = @json.parse(source) catch {
    error => raise InvalidJson("\{Repr(error)}")
  }
  let root = premap_object(parsed, "$")
  premap_exact_keys(root, "$", [
    "schema_version", "artifact_kind", "fixture", "top_module", "depth", "synchronizer_stages",
    "pointer_width", "address_width", "source_domain", "destination_domain", "source_valid",
    "source_ready", "destination_ready", "destination_valid", "write_binary", "write_binary_next",
    "write_gray", "write_gray_next", "read_binary", "read_binary_next", "read_gray",
    "read_gray_next", "full", "full_next", "nonempty", "nonempty_next", "write_address",
    "read_address", "source_transfer", "destination_transfer", "read_gray_pipeline",
    "write_gray_pipeline", "lanes", "expected_contract",
  ])
  let schema = premap_string(
    premap_field(root, "$", "schema_version"),
    "$.schema_version",
  )
  let artifact = premap_string(
    premap_field(root, "$", "artifact_kind"),
    "$.artifact_kind",
  )
  if schema != "lunachip.async-fifo-role-inventory/v2" ||
    artifact != "async-fifo-pre-map-expected-contract" {
    raise InvalidValue(path="$", value="wrong inventory identity")
  }
  validate_inventory_expected_contract(
    premap_field(root, "$", "expected_contract"),
  )
  let depth = premap_int(premap_field(root, "$", "depth"), "$.depth")
  let stages = premap_int(
    premap_field(root, "$", "synchronizer_stages"),
    "$.synchronizer_stages",
  )
  let pointer_width = premap_int(
    premap_field(root, "$", "pointer_width"),
    "$.pointer_width",
  )
  let address_width = premap_int(
    premap_field(root, "$", "address_width"),
    "$.address_width",
  )
  if depth <= 1 ||
    stages < 2 ||
    pointer_width < 2 ||
    address_width != pointer_width - 1 ||
    depth != 1 << address_width {
    raise InvalidValue(path="$", value="inconsistent FIFO dimensions")
  }
  let string_field = fn(key : String) raise {
    premap_string(premap_field(root, "$", key), "$.\{key}")
  }
  let read_pipeline = inventory_string_array(
    premap_field(root, "$", "read_gray_pipeline"),
    "$.read_gray_pipeline",
  )
  let write_pipeline = inventory_string_array(
    premap_field(root, "$", "write_gray_pipeline"),
    "$.write_gray_pipeline",
  )
  if read_pipeline.length() != stages || write_pipeline.length() != stages {
    raise InvalidValue(path="$", value="pipeline length does not match stages")
  }
  {
    fixture: string_field("fixture"),
    top_module: string_field("top_module"),
    depth,
    synchronizer_stages: stages,
    pointer_width,
    address_width,
    source_domain: parse_inventory_domain(
      premap_field(root, "$", "source_domain"),
      "$.source_domain",
    ),
    destination_domain: parse_inventory_domain(
      premap_field(root, "$", "destination_domain"),
      "$.destination_domain",
    ),
    source_valid: string_field("source_valid"),
    source_ready: string_field("source_ready"),
    destination_ready: string_field("destination_ready"),
    destination_valid: string_field("destination_valid"),
    source_transfer: string_field("source_transfer"),
    destination_transfer: string_field("destination_transfer"),
    write_binary: string_field("write_binary"),
    write_binary_next: string_field("write_binary_next"),
    write_gray: string_field("write_gray"),
    write_gray_next: string_field("write_gray_next"),
    read_binary: string_field("read_binary"),
    read_binary_next: string_field("read_binary_next"),
    read_gray: string_field("read_gray"),
    read_gray_next: string_field("read_gray_next"),
    full: string_field("full"),
    full_next: string_field("full_next"),
    nonempty: string_field("nonempty"),
    nonempty_next: string_field("nonempty_next"),
    write_address: string_field("write_address"),
    read_address: string_field("read_address"),
    read_gray_pipeline: read_pipeline,
    write_gray_pipeline: write_pipeline,
    lanes: parse_inventory_lanes(premap_field(root, "$", "lanes")),
  }
}

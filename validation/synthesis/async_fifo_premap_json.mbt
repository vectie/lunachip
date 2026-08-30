///|
fn premap_object(value : Json, path : String) -> Map[String, Json] raise {
  match value {
    Object(fields) => fields
    _ => raise WrongType(path~, expected="object")
  }
}

///|
fn premap_array(value : Json, path : String) -> Array[Json] raise {
  match value {
    Array(values) => values
    _ => raise WrongType(path~, expected="array")
  }
}

///|
fn premap_string(value : Json, path : String) -> String raise {
  match value {
    String(value) => value
    _ => raise WrongType(path~, expected="string")
  }
}

///|
fn premap_int(value : Json, path : String) -> Int raise {
  match value {
    Number(value, ..) => {
      let integer = value.to_int()
      if integer.to_double() != value {
        raise InvalidValue(path~, value=value.to_string())
      }
      integer
    }
    _ => raise WrongType(path~, expected="integer")
  }
}

///|
fn premap_field(
  fields : Map[String, Json],
  path : String,
  key : String,
) -> Json raise {
  match fields.get(key) {
    Some(value) => value
    None => raise MissingKey(path~, key~)
  }
}

///|
fn premap_exact_keys(
  fields : Map[String, Json],
  path : String,
  allowed : Array[String],
) -> Unit raise {
  for key in fields.keys() {
    if !allowed.contains(key) {
      raise UnknownKey(path~, key~)
    }
  }
  for key in allowed {
    if !fields.contains(key) {
      raise MissingKey(path~, key~)
    }
  }
}

///|
fn premap_string_map(value : Json, path : String) -> Map[String, String] raise {
  let fields = premap_object(value, path)
  let out : Map[String, String] = Map([])
  for key, value in fields {
    out[key] = premap_string(value, "\{path}.\{key}")
  }
  out
}

///|
fn premap_bit(value : Json, path : String) -> PreMapBit raise {
  match value {
    Number(_, ..) => {
      let id = premap_int(value, path)
      if id < 0 {
        raise InvalidValue(path~, value=id.to_string())
      }
      Wire(id)
    }
    String("0") => Zero
    String("1") => One
    String("x") => Unknown
    String("z") => HighImpedance
    String(value) => raise InvalidValue(path~, value~)
    _ => raise WrongType(path~, expected="wire-id-or-bit-constant")
  }
}

///|
fn premap_signal(value : Json, path : String) -> PreMapSignal raise {
  let values = premap_array(value, path)
  if values.is_empty() {
    raise InvalidValue(path~, value="empty signal")
  }
  let bits : Array[PreMapBit] = []
  for index, value in values {
    bits.push(premap_bit(value, "\{path}[\{index}]"))
  }
  { bits, }
}

///|
fn premap_signal_map(
  value : Json,
  path : String,
) -> Map[String, PreMapSignal] raise {
  let fields = premap_object(value, path)
  let out : Map[String, PreMapSignal] = Map([])
  for key, value in fields {
    out[key] = premap_signal(value, "\{path}.\{key}")
  }
  out
}

///|
fn parse_premap_ports(value : Json) -> Map[String, PreMapPort] raise {
  let fields = premap_object(value, "$.modules.<top>.ports")
  let out : Map[String, PreMapPort] = Map([])
  for name, value in fields {
    let path = "$.modules.<top>.ports.\{name}"
    let port = premap_object(value, path)
    premap_exact_keys(port, path, ["direction", "bits"])
    let direction = premap_string(
      premap_field(port, path, "direction"),
      "\{path}.direction",
    )
    if direction != "input" && direction != "output" && direction != "inout" {
      raise InvalidValue(path="\{path}.direction", value=direction)
    }
    out[name] = {
      direction,
      signal: premap_signal(premap_field(port, path, "bits"), "\{path}.bits"),
    }
  }
  out
}

///|
fn parse_premap_netnames(value : Json) -> Map[String, PreMapSignal] raise {
  let fields = premap_object(value, "$.modules.<top>.netnames")
  let out : Map[String, PreMapSignal] = Map([])
  for name, value in fields {
    let path = "$.modules.<top>.netnames.\{name}"
    let net = premap_object(value, path)
    premap_exact_keys(net, path, ["hide_name", "bits", "attributes"])
    ignore(
      premap_int(premap_field(net, path, "hide_name"), "\{path}.hide_name"),
    )
    ignore(
      premap_string_map(
        premap_field(net, path, "attributes"),
        "\{path}.attributes",
      ),
    )
    out[name] = premap_signal(premap_field(net, path, "bits"), "\{path}.bits")
  }
  out
}

///|
fn parse_premap_cells(value : Json) -> Array[PreMapCell] raise {
  let fields = premap_object(value, "$.modules.<top>.cells")
  let cells : Array[PreMapCell] = []
  for name, value in fields {
    let path = "$.modules.<top>.cells.\{name}"
    let cell = premap_object(value, path)
    premap_exact_keys(cell, path, [
      "hide_name", "type", "parameters", "attributes", "port_directions", "connections",
    ])
    ignore(
      premap_int(premap_field(cell, path, "hide_name"), "\{path}.hide_name"),
    )
    ignore(
      premap_string_map(
        premap_field(cell, path, "attributes"),
        "\{path}.attributes",
      ),
    )
    cells.push({
      name,
      cell_type: premap_string(premap_field(cell, path, "type"), "\{path}.type"),
      parameters: premap_string_map(
        premap_field(cell, path, "parameters"),
        "\{path}.parameters",
      ),
      connections: premap_signal_map(
        premap_field(cell, path, "connections"),
        "\{path}.connections",
      ),
      directions: premap_string_map(
        premap_field(cell, path, "port_directions"),
        "\{path}.port_directions",
      ),
    })
  }
  cells
}

///|
fn parse_yosys_pre_map_json(source : String) -> PreMapDocument raise {
  let parsed = @json.parse(source) catch {
    error => raise InvalidJson("\{Repr(error)}")
  }
  let root = premap_object(parsed, "$")
  premap_exact_keys(root, "$", ["creator", "modules"])
  let creator = premap_string(premap_field(root, "$", "creator"), "$.creator")
  let modules = premap_object(premap_field(root, "$", "modules"), "$.modules")
  if modules.length() != 1 {
    raise InvalidValue(path="$.modules", value="expected exactly one module")
  }
  let (name, module_json) = modules.to_array()[0]
  let path = "$.modules.\{name}"
  let hardware_module = premap_object(module_json, path)
  premap_exact_keys(hardware_module, path, [
    "attributes", "ports", "cells", "netnames",
  ])
  ignore(
    premap_string_map(
      premap_field(hardware_module, path, "attributes"),
      "\{path}.attributes",
    ),
  )
  {
    creator,
    hardware_module: {
      name,
      ports: parse_premap_ports(premap_field(hardware_module, path, "ports")),
      cells: parse_premap_cells(premap_field(hardware_module, path, "cells")),
      netnames: parse_premap_netnames(
        premap_field(hardware_module, path, "netnames"),
      ),
    },
  }
}

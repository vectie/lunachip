///|
// These are the original harness anyseq public inputs, not DUT observations.
// The initialized harness clock is intentionally absent from the whitelist.
fn fetched_useful_guidance_pins() -> ReadOnlyArray[(String, Int)] {
  [
    ("reset", 1),
    ("config_valid", 1),
    ("config_base", 32),
    ("config_origin", 32),
    ("publish_valid", 1),
    ("publish_producer", 32),
    ("completion_ready", 1),
    ("memory_request_ready", 1),
    ("memory_response_valid", 1),
    ("memory_response_tag", 32),
    ("memory_response_fault", 2),
    ("memory_response_data", 32),
  ]
}

///|
fn fetched_useful_guidance_rows(
  roster : String,
) -> ReadOnlyArray[String] raise FormalGateError {
  if !roster.has_suffix("\n") {
    raise InvalidFormalBundleIdentity("fetched guidance final newline")
  }
  let rows = roster.split("\n").to_array()
  if rows.length() != 419 * 12 + 1 || rows[419 * 12] != "" {
    raise InvalidFormalBundleIdentity("fetched guidance complete PRE0..418")
  }
  let values : Array[String] = []
  let pins = fetched_useful_guidance_pins()
  for edge in 0..<419 {
    for position in 0..<12 {
      guard rows[edge * 12 + position].split(" ").to_array()
        is ["PRE", ordinal, name, bits] else {
        raise InvalidFormalBundleIdentity("fetched guidance exact PRE row")
      }
      let (expected_name, width) = pins[position]
      if ordinal != "\{edge}" || name != expected_name || bits.length() != width {
        raise InvalidFormalBundleIdentity(
          "fetched guidance public input ordinal/name/width",
        )
      }
      for bit in bits {
        if bit != '0' && bit != '1' {
          raise InvalidFormalBundleIdentity(
            "fetched guidance unknown input bit",
          )
        }
      }
      values.push(bits.to_owned())
    }
  }
  ReadOnlyArray::from_array(values)
}

///|
// An existential input scenario only. It neither changes hardware nor proves
// symbolic safety. PRE n is offered at low/global2n and high/global2n+1;
// actual collected clock and outputs must independently qualify this mapping.
#warnings("-unused_value")
fn fetched_useful_guidance(
  roster : String,
) -> (String, String) raise FormalGateError {
  let values = fetched_useful_guidance_rows(roster)
  let pins = fetched_useful_guidance_pins()
  let scenario = StringBuilder()
  scenario.write_string(
    "# Existential original fetched useful Store cover only.\n" +
    "# Twelve original public inputs; all recorded bits known.\n" +
    "# Native PRE n -> global states 2n,2n+1; full initialized prefix.\n" +
    "# No clock/output/internal-state/cell/read/ghost constraints.\n" +
    "# Global states838..1023 free; actual trace must qualify phase mapping.\n",
  )
  for edge in 0..<419 {
    scenario.write_string("\nstate \{2 * edge} \{2 * edge + 1}\n")
    for position in 0..<12 {
      let (name, width) = pins[position]
      let bits = values[edge * 12 + position]
      let literal = if width == 1 {
        if bits == "1" {
          "true"
        } else {
          "false"
        }
      } else {
        "#b" + bits
      }
      scenario.write_string("assume (= [lc_\{name}] \{literal})\n")
    }
  }
  let mapping = StringBuilder()
  mapping.write_string(
    "LUNACHIP-FETCHED-INPUT-GUIDANCE 1\n" +
    "TOP lc_formal_fetched_useful_top\n" +
    "ROSTER-SHA256 \{sha256_hex(roster)}\n" +
    "NATIVE-PRE 0..418 FRAMES 419 INPUT-ROWS 5028\n" +
    "GLOBAL-PAIRS 0..837 GUIDED-VALUES 10056 FREE-TAIL 838..1023\n" +
    "CLOCK original-initial0-toggle-per-global-step-not-guided\n" +
    "PREFIX full-initialized-no-skipped-transition\n" +
    "MASKS all-input-bits-known-exact-width-no-truncation\n" +
    "CONSTRAINTS original-public-inputs-only-no-output-state-memory-or-progress\n" +
    "CLAIM existential-cover-only-not-symbolic-safety-fairness-or-Phase6-closure\n" +
    "QUALIFICATION actual-model-clock-phase-original-premises-and-causal-trace-required\n",
  )
  for (name, width) in pins {
    mapping.write_string("INPUT \{name} lc_\{name} WIDTH \{width}\n")
  }
  mapping.write_string("END\n")
  (scenario.to_string(), mapping.to_string())
}

///|
/// Typed canonical manifest accompanying an exported formal-property snippet.
pub struct FormalPropertyManifest {
  plan : FormalPropertyPlan
} derive(Debug, Eq)

///|
pub fn FormalPropertyManifest::from_plan(
  plan : FormalPropertyPlan,
) -> FormalPropertyManifest {
  { plan, }
}

///|
pub fn FormalPropertyManifest::properties(
  self : FormalPropertyManifest,
) -> ReadOnlyArray[FormalProperty] {
  self.plan.properties()
}

///|
fn property_manifest_line(ordinal : Int, item : FormalProperty) -> String {
  "F \{ordinal} \{item.id().ordinal()} \{property_identifier(item)} \{formal_kind_text(item.kind())} \{encode_text(item.name())} \{item.domain().canonical_name()} \{signal_manifest_text(item.domain().clock())} predicate \{signal_manifest_text(item.predicate())} disable \{disable_manifest_text(item.disable())}\n"
}

///|
/// Serialize the exact property identities, roles, observation domains, and
/// disable behaviors represented by an exported snippet.
pub fn FormalPropertyManifest::to_canonical_text(
  self : FormalPropertyManifest,
) -> String {
  let output = StringBuilder()
  output.write_string("LUNACHIP-FORMAL-PROPERTIES 1\n")
  output.write_string("PROPERTIES \{self.properties().length()}\n")
  for ordinal, item in self.properties() {
    output.write_string(property_manifest_line(ordinal, item))
  }
  output.write_string("END\n")
  output.to_string()
}

///|
priv struct LineTokenReader {
  line : Int
  tokens : Array[String]
  mut cursor : Int
}

///|
fn LineTokenReader::take(
  self : LineTokenReader,
  expected : String,
) -> String raise FormalError {
  if self.cursor >= self.tokens.length() {
    raise InvalidCanonicalLine(
      line=self.line,
      expected~,
      actual=self.tokens.join(" "),
    )
  }
  let value = self.tokens[self.cursor]
  self.cursor += 1
  value
}

///|
fn LineTokenReader::expect(
  self : LineTokenReader,
  expected : String,
) -> Unit raise FormalError {
  let actual = self.take(expected)
  if actual != expected {
    raise InvalidCanonicalLine(
      line=self.line,
      expected~,
      actual=self.tokens.join(" "),
    )
  }
}

///|
fn LineTokenReader::finish(
  self : LineTokenReader,
  expected : String,
) -> Unit raise FormalError {
  if self.cursor != self.tokens.length() {
    raise InvalidCanonicalLine(
      line=self.line,
      expected~,
      actual=self.tokens.join(" "),
    )
  }
}

///|
fn read_property_signal(
  reader : LineTokenReader,
) -> @property.PropertySignal raise FormalError {
  let signal_kind = reader.take("property signal")
  match signal_kind {
    "named" => {
      let path = decode_text(reader.line, reader.take("named signal path"))
      let name = decode_text(reader.line, reader.take("named signal name"))
      @property.PropertySignal::named(path, name) catch {
        _ =>
          raise InvalidCanonicalLine(
            line=reader.line,
            expected="valid named property signal",
            actual=reader.tokens.join(" "),
          )
      }
    }
    "node" => {
      let module_path = decode_text(
        reader.line,
        reader.take("node signal module path"),
      )
      let ordinal_text = reader.take("node signal ordinal")
      let ordinal = parse_int(reader.line, "node signal ordinal", ordinal_text)
      let node = @ir.NodeId::new(ordinal) catch {
        _ =>
          raise InvalidCanonicalLine(
            line=reader.line,
            expected="non-negative node signal ordinal",
            actual=reader.tokens.join(" "),
          )
      }
      @property.PropertySignal::node(module_path, node) catch {
        _ =>
          raise InvalidCanonicalLine(
            line=reader.line,
            expected="valid node property signal",
            actual=reader.tokens.join(" "),
          )
      }
    }
    _ =>
      raise InvalidCanonicalLine(
        line=reader.line,
        expected="named|node property signal",
        actual=reader.tokens.join(" "),
      )
  }
}

///|
fn parse_property_kind(
  reader : LineTokenReader,
  text : String,
) -> FormalPropertyKind raise FormalError {
  match text {
    "assert" => Assertion
    "assume" => Assumption
    "cover" => Cover
    _ =>
      raise InvalidCanonicalLine(
        line=reader.line,
        expected="assert|assume|cover",
        actual=reader.tokens.join(" "),
      )
  }
}

///|
fn parse_disable_behavior(
  reader : LineTokenReader,
) -> DisableBehavior raise FormalError {
  match reader.take("disable behavior") {
    "never" => NeverDisabled
    "known-high-asynchronous" =>
      DisableBehavior::when_known_high_asynchronous(
        read_property_signal(reader),
      )
    _ =>
      raise InvalidCanonicalLine(
        line=reader.line,
        expected="never|known-high-asynchronous",
        actual=reader.tokens.join(" "),
      )
  }
}

///|
fn parse_property_manifest_line(
  line : Int,
  tokens : Array[String],
  expected_ordinal : Int,
) -> FormalProperty raise FormalError {
  let reader : LineTokenReader = { line, tokens, cursor: 0 }
  reader.expect("F")
  let ordinal = parse_int(line, "property ordinal", reader.take("ordinal"))
  if ordinal != expected_ordinal {
    raise InvalidCanonicalLine(
      line~,
      expected="property ordinal \{expected_ordinal}",
      actual=reader.tokens.join(" "),
    )
  }
  let id_ordinal = parse_int(line, "property ID", reader.take("property ID"))
  let id = @property.PropertyId::new(id_ordinal) catch {
    _ =>
      raise InvalidCanonicalLine(
        line~,
        expected="non-negative property ID",
        actual=reader.tokens.join(" "),
      )
  }
  let stable_name = reader.take("stable property name")
  validate_sv_identifier(stable_name)
  let kind = parse_property_kind(reader, reader.take("property kind"))
  let name = decode_text(line, reader.take("property source name"))
  reader.expect("rising-pre-edge")
  let clock = read_property_signal(reader)
  reader.expect("predicate")
  let predicate = read_property_signal(reader)
  reader.expect("disable")
  let disable = parse_disable_behavior(reader)
  reader.finish("canonical formal property line")
  let item = FormalProperty::checked(
    id,
    name,
    kind,
    predicate,
    ObservationDomain::rising_pre_edge(clock),
    disable,
  )
  let expected_name = property_identifier(item)
  if stable_name != expected_name {
    raise StablePropertyNameMismatch(expected=expected_name, actual=stable_name)
  }
  item
}

///|
/// Strictly parse a formal-property manifest. Signal encodings, stable labels,
/// property ordering, and every domain/disable token are revalidated before
/// the input is accepted as canonical.
pub fn parse_formal_property_manifest(
  source : String,
) -> FormalPropertyManifest raise FormalError {
  let reader = CanonicalReader::new(source)
  read_header(reader, "LUNACHIP-FORMAL-PROPERTIES")
  let (count_line, count_tokens) = reader.tokens("PROPERTIES count")
  require_tokens(count_line, count_tokens, "PROPERTIES", 2, "PROPERTIES count")
  let count = parse_int(count_line, "property count", count_tokens[1])
  if count <= 0 {
    raise EmptyPropertySet
  }
  let properties : Array[FormalProperty] = []
  for ordinal in 0..<count {
    let (line, tokens) = reader.tokens("F property record")
    properties.push(parse_property_manifest_line(line, tokens, ordinal))
  }
  let manifest = FormalPropertyManifest::from_plan(
    FormalPropertyPlan::checked(properties),
  )
  finish_canonical(reader, source, manifest.to_canonical_text())
  manifest
}

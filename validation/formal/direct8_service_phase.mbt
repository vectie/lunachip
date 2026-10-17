///|
let direct8_service_phase_id : String = "phase6-flux-tile-direct8-q3-engine-service-phase-r2-h2"

///|
priv enum Direct8ServicePart {
  Joint
  Ownership
  AckCredit
  Payload
  JointPayload
} derive(Eq)

///|
fn Direct8ServicePart::id(self : Direct8ServicePart) -> String {
  match self {
    Joint => direct8_service_phase_id
    Ownership => "phase6-flux-tile-direct8-q3-engine-service-owner-r2-h2"
    AckCredit => "phase6-flux-tile-direct8-q3-engine-service-ack-credit-r2-h2"
    Payload => "phase6-flux-tile-direct8-q3-engine-service-payload-r2-h2"
    JointPayload =>
      "phase6-flux-tile-direct8-q3-engine-service-phase-payload-r2-h2"
  }
}

///|
fn Direct8ServicePart::count(self : Direct8ServicePart) -> Int {
  match self {
    Joint => 52
    Ownership => 49
    AckCredit => 51
    Payload => 51
    JointPayload => 55
  }
}

///|
fn Direct8ServicePart::scope(self : Direct8ServicePart) -> String {
  match self {
    Joint =>
      "original48-plus-client-phase-age11-service-credit4-and-client-credit-no-command-age-potential-or-latency-selection"
    Ownership =>
      "original48-plus-client-engine-phase-ownership-only-no-ACK-credit-or-command-latency-selection"
    AckCredit =>
      "original48-plus-age11-ACK-service-credit4-and-client-credit-no-client-phase-or-command-latency-selection"
    Payload =>
      "original48-plus-active-C-metadata-and-pending-read-ID-status-no-client-phase-ACK-credit-or-command-latency-selection"
    JointPayload =>
      "original52-plus-active-C-metadata-and-pending-read-ID-status-no-command-age-potential-or-latency-selection"
  }
}

///|
fn Direct8ServicePart::has_payload(self : Direct8ServicePart) -> Bool {
  self == Payload || self == JointPayload
}

///|
fn direct8_service_part_from_id(id : String) -> Direct8ServicePart? {
  for part in [Joint, Ownership, AckCredit, Payload, JointPayload] {
    if part.id() == id {
      return Some(part)
    }
  }
  None
}

///|
fn direct8_service_phase_property_names(
  part? : Direct8ServicePart = Joint,
) -> ReadOnlyArray[String] {
  let names = ["d8l_phase_link", "d8l_issue_progress"]
  if part == Joint || part == Ownership || part == JointPayload {
    names.push("d8l_client_phase")
  }
  if part == Joint || part == AckCredit || part == JointPayload {
    for
      name in [
        "d8l_client_service11", "d8l_service_credit4", "d8l_client_credit",
      ] {
      names.push(name)
    }
  }
  if part.has_payload() {
    for name in direct8_payload_property_names() {
      names.push(name)
    }
  }
  ReadOnlyArray::from_array(names)
}

///|
let direct8_service_phase_id : String = "phase6-flux-tile-direct8-q3-engine-service-phase-r2-h2"

///|
priv enum Direct8ServicePart {
  Joint
  Ownership
  AckCredit
} derive(Eq)

///|
fn Direct8ServicePart::id(self : Direct8ServicePart) -> String {
  match self {
    Joint => direct8_service_phase_id
    Ownership => "phase6-flux-tile-direct8-q3-engine-service-owner-r2-h2"
    AckCredit => "phase6-flux-tile-direct8-q3-engine-service-ack-credit-r2-h2"
  }
}

///|
fn Direct8ServicePart::count(self : Direct8ServicePart) -> Int {
  match self {
    Joint => 52
    Ownership => 49
    AckCredit => 51
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
  }
}

///|
fn direct8_service_phase_property_names(
  part? : Direct8ServicePart = Joint,
) -> ReadOnlyArray[String] {
  let names = ["d8l_phase_link", "d8l_issue_progress"]
  if part != AckCredit {
    names.push("d8l_client_phase")
  }
  if part != Ownership {
    for
      name in [
        "d8l_client_service11", "d8l_service_credit4", "d8l_client_credit",
      ] {
      names.push(name)
    }
  }
  ReadOnlyArray::from_array(names)
}

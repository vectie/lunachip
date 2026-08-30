///|
fn atomic_input_port(
  ports : ReadOnlyArray[HarnessPort],
  emitted_name : String,
) -> HarnessPort? {
  for port in ports {
    if port.direction == Input && port.emitted_name == emitted_name {
      return Some(port)
    }
  }
  None
}

///|
fn atomic_safe_path(filename : String) -> Bool {
  if filename.is_empty() ||
    filename.has_prefix("/") ||
    !filename.has_suffix(".cpp") {
    return false
  }
  for part in filename.split("/") {
    if part.is_empty() || part == ".." {
      return false
    }
    for symbol in part {
      let code = symbol.to_int()
      let letter = (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
      let digit = code >= 48 && code <= 57
      if !(letter ||
        digit ||
        symbol == '.' ||
        symbol == '_' ||
        symbol == '+' ||
        symbol == '-') {
        return false
      }
    }
  }
  true
}

///|
fn validate_atomic_ports(
  ports : ReadOnlyArray[HarnessPort],
  stimulus : AtomicStimulus,
) -> Unit raise HarnessError {
  for port in ports {
    if port.width < 1 || port.width > 64 {
      raise UnsupportedPortWidth(name=port.source_name, width=port.width)
    }
    let signal_width = port.signal_type.width().bits()
    if port.width != signal_width {
      raise AtomicPortSignalWidthMismatch(
        name=port.emitted_name,
        port=port.width,
        signal=signal_width,
      )
    }
    for symbol in port.source_name {
      let code = symbol.to_int()
      if port.direction == Output && (code < 32 || (code >= 127 && code <= 159)) {
        raise InvalidAtomicOutputName(port.source_name)
      }
    }
  }
  for index, port in ports {
    for previous in 0..<index {
      if ports[previous].emitted_name == port.emitted_name {
        raise DuplicateAtomicPortName(port.emitted_name)
      }
    }
    if port.direction == Output {
      for previous in 0..<index {
        if ports[previous].direction == Output &&
          ports[previous].source_name == port.source_name {
          raise DuplicateAtomicOutputName(port.source_name)
        }
      }
    }
  }
  for domain in stimulus.domains() {
    match atomic_input_port(ports, domain.clock_port()) {
      Some(port) if port.signal_type.is_clock() => ()
      _ => raise InvalidAtomicStimulusClockPort(domain.clock_port())
    }
  }
  for port in ports {
    if port.direction == Input &&
      port.signal_type.is_clock() &&
      !stimulus
      .domains()
      .any(domain => domain.clock_port() == port.emitted_name) {
      raise MissingAtomicClockDomain(port.emitted_name)
    }
  }
  for event in stimulus.events() {
    for drive in event.drives() {
      match atomic_input_port(ports, drive.name()) {
        Some(port) if !port.signal_type.is_clock() =>
          if drive.value().width() != port.width {
            raise AtomicStimulusPortWidthMismatch(
              name=drive.name(),
              expected=port.width,
              actual=drive.value().width(),
            )
          }
        _ => raise MissingAtomicStimulusPort(drive.name())
      }
    }
  }
}

///|
fn validate_atomic_result_prefix(
  result_prefix : String,
) -> Unit raise HarnessError {
  if !result_prefix.has_suffix("\n") {
    raise InvalidAtomicResultPrefix(reason="missing final newline")
  }
  if result_prefix.contains("\"") ||
    result_prefix.contains("\\") ||
    result_prefix.contains("\r") {
    raise InvalidAtomicResultPrefix(reason="not representable as a C++ literal")
  }
  for symbol in result_prefix {
    let code = symbol.to_int()
    if (code < 32 && code != 9 && code != 10) || (code >= 127 && code <= 159) {
      raise InvalidAtomicResultPrefix(reason="unsafe control character")
    }
  }
}

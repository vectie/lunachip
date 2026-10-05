///|
// This fixed host profile records actual public transactions, not issued
// commands. The stimulus owns completion accounting and generation checks.
priv struct RemoteFaultHostState {
  old_words : Array[Int]
  mut store_failure : Request?
  mut load_failure : Request?
  mut write_effect_bytes : Int
  mut store_words : Int
  mut previous_store : Request?
  mut store_ack_bytes : Int
  mut replacement_reads : Int
  mut replacement_ack_bytes : Int
}

///|
fn remote_fault_host() -> Host raise {
  let state : RemoteFaultHostState = {
    old_words: remote_fault_old_words(),
    store_failure: None,
    load_failure: None,
    write_effect_bytes: 0,
    store_words: 0,
    previous_store: None,
    store_ack_bytes: 0,
    replacement_reads: 0,
    replacement_ack_bytes: 0,
  }
  {
    kind: RemoteFault(state),
    memory: remote_fault_memory(),
    pending: None,
    held: None,
    next_tag: 0UL,
    requests: 0,
    reads: 0,
    writes: 0,
    stalls: 0,
  }
}

///|
fn remote_fault_read_allowed(address : Int) -> Bool {
  (address >= 3072 && address < 3200) ||
  address == 512 ||
  address == 513 ||
  address == 640 ||
  address == 641 ||
  address == 643 ||
  address == 644 ||
  address == 896 ||
  address == 897 ||
  address == 768 ||
  address == 769 ||
  address == 771 ||
  address == 772
}

///|
fn remote_fault_write_allowed(address : Int) -> Bool {
  address == 1536 ||
  address == 1540 ||
  address == 1792 ||
  address == 1796 ||
  address == 1920 ||
  address == 1924 ||
  address == 2048 ||
  address == 2052
}

///|
fn RemoteFaultHostState::accept_write(
  self : RemoteFaultHostState,
  request : Request,
) -> (UInt64, Int) raise {
  let ordinal = self.store_words
  let selected = self.store_failure is None && ordinal == 1
  if self.store_failure is None {
    let expected_address = if ordinal == 0 { 1536UL } else { 1540UL }
    if request.address != expected_address || ordinal > 1 {
      fail(
        "remote-fault initial store word order differs from accepted requests",
      )
    }
    let bits = self.old_words[ordinal].to_int64().reinterpret_as_uint64() &
      0xffffffffUL
    if request.data != bits {
      fail("remote-fault initial store differs from the independent C0 oracle")
    }
  }
  if selected {
    guard self.previous_store is Some(previous) else {
      fail("remote-fault second store word has no earlier accepted owner")
    }
    if previous.address != 1536UL ||
      previous.write != 1UL ||
      self.store_ack_bytes != 4 {
      fail("remote-fault partial store preceded its first successful word ACK")
    }
    self.store_failure = Some(request)
  }
  self.previous_store = Some(request)
  self.store_words += 1
  let effect = if selected { 2 } else { 4 }
  self.write_effect_bytes += effect
  (if selected { 1UL } else { 0UL }, effect)
}

///|
fn RemoteFaultHostState::accept_read(
  self : RemoteFaultHostState,
  request : Request,
) -> UInt64 raise {
  let replacement = request.address == 768UL ||
    request.address == 769UL ||
    request.address == 771UL ||
    request.address == 772UL
  if !replacement || self.load_failure is Some(_) {
    return 0UL
  }
  let expected = match self.replacement_reads {
    0 => 768UL
    1 => 769UL
    2 => 771UL
    _ => fail("remote-fault failed reload issued past its selected third byte")
  }
  if request.address != expected ||
    self.replacement_ack_bytes != self.replacement_reads {
    fail("remote-fault replacement read preceded its ordered successful ACKs")
  }
  self.replacement_reads += 1
  if request.address == 771UL {
    // Production cannot request this next byte until each preceding good
    // response has also committed its bank element. The completion checks
    // independently require precisely two committed elements.
    self.load_failure = Some(request)
    1UL
  } else {
    0UL
  }
}

///|
fn RemoteFaultHostState::acknowledge(
  self : RemoteFaultHostState,
  response : Response,
  drive : HostDrive,
) -> Unit raise {
  if response.delay != 0 ||
    response.tag != response.request.tag ||
    drive.response_tag != response.tag ||
    drive.response_fault != response.fault ||
    drive.response_data != response.data {
    fail("remote-fault ACK differs from its saved accepted response")
  }
  if response.fault == 1UL {
    let owner = if response.request.write == 1UL {
      self.store_failure
    } else {
      self.load_failure
    }
    if owner != Some(response.request) {
      fail("remote-fault response lost its selected request owner")
    }
  } else if response.fault == 0UL {
    if response.request.write == 1UL {
      self.store_ack_bytes += 4
    } else if self.load_failure is None &&
      (response.request.address == 768UL || response.request.address == 769UL) {
      self.replacement_ack_bytes += 1
    }
  } else {
    fail("remote-fault host generated an unsupported response status")
  }
}

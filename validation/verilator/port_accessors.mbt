///|
pub fn HarnessPort::source_name(self : HarnessPort) -> String {
  self.source_name
}

///|
pub fn HarnessPort::emitted_name(self : HarnessPort) -> String {
  self.emitted_name
}

///|
pub fn HarnessPort::width(self : HarnessPort) -> Int32 {
  self.width
}

///|
pub fn HarnessPort::signal_type(self : HarnessPort) -> @ir.SignalType {
  self.signal_type
}

///|
pub fn HarnessPort::is_input(self : HarnessPort) -> Bool {
  self.direction == Input
}

///|
pub fn HarnessPort::is_output(self : HarnessPort) -> Bool {
  self.direction == Output
}

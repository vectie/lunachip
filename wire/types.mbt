///|
/// Construction failures specific to the LunaWire elaboration API.
pub(all) suberror WireError {
  BuilderFinished
  ForeignSignal
  ForeignOutput
  ForeignRegister
  DuplicateDriver(String)
  UndrivenOutput(String)
  DuplicateNextDriver(Int)
  UndrivenRegister(Int)
} derive(Debug, Eq)

///|
/// A typed signal handle owned by one module builder.
pub struct Signal {
  owner : Array[Unit]
  id : @ir.NodeId
  signal_type : @ir.SignalType
}

///|
pub fn Signal::id(self : Signal) -> @ir.NodeId {
  self.id
}

///|
pub fn Signal::signal_type(self : Signal) -> @ir.SignalType {
  self.signal_type
}

///|
/// An output sink. It must receive exactly one driver before `finish`.
pub struct Output {
  owner : Array[Unit]
  index : Int
  name : String
  signal_type : @ir.SignalType
}

///|
pub fn Output::name(self : Output) -> String {
  self.name
}

///|
pub fn Output::signal_type(self : Output) -> @ir.SignalType {
  self.signal_type
}

///|
/// A declared register whose value exists before its next-state logic.
pub struct RegisterHandle {
  owner : Array[Unit]
  index : Int
  value : Signal
  clock : @ir.NodeId
  initial : UInt64?
}

///|
/// Return the register's old committed value signal.
pub fn RegisterHandle::value(self : RegisterHandle) -> Signal {
  self.value
}

///|
/// Stateful elaboration context for one module. Canonical order is call order.
pub struct ModuleBuilder {
  name : String
  owner : Array[Unit]
  nodes : Array[@ir.Node]
  outputs : Array[Output]
  drivers : Array[@ir.NodeId?]
  registers : Array[RegisterHandle]
  next_drivers : Array[@ir.NodeId?]
  mut finished : Bool
}

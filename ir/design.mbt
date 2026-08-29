///|
/// A deterministic collection of validated modules and a named top module.
pub struct Design {
  name : String
  modules : ReadOnlyArray[Module]
  top : String
} derive(Debug, Eq)

///|
/// Validate and freeze a design in caller-provided construction order.
pub fn Design::checked(
  name : String,
  modules : ArrayView[Module],
  top : String,
) -> Design raise IrError {
  require_name(name, "design")
  require_name(top, "top module")
  let names : Array[String] = []
  for hardware_module in modules {
    if contains_name(names, hardware_module.name()) {
      raise DuplicateName(kind="module", name=hardware_module.name())
    }
    names.push(hardware_module.name())
  }
  if !contains_name(names, top) {
    raise MissingTopModule(top)
  }
  { name, modules: ReadOnlyArray::from_array(modules), top }
}

///|
pub fn Design::single(name : String, top : Module) -> Design raise IrError {
  Design::checked(name, [top], top.name())
}

///|
pub fn Design::name(self : Design) -> String {
  self.name
}

///|
pub fn Design::modules(self : Design) -> ReadOnlyArray[Module] {
  self.modules
}

///|
pub fn Design::top_name(self : Design) -> String {
  self.top
}

///|
pub fn Design::top_module(self : Design) -> Module? {
  for hardware_module in self.modules {
    if hardware_module.name() == self.top {
      return Some(hardware_module)
    }
  }
  None
}

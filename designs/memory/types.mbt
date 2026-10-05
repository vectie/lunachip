///|
/// Checked configuration failures for reusable synchronous-memory components.
pub(all) suberror MemoryComponentError {
  EmptyComponentName
  InvalidFifoDepth(Int)
  FifoDepthNotPowerOfTwo(Int)
  InvalidBankCount(Int)
  BankCountNotPowerOfTwo(Int)
  InvalidRowsPerBank(Int)
  InvalidElementType
  InvalidMaskGranularity(element_width~ : Int, granularity~ : Int)
  MissingMaskSignal
  UnexpectedMaskSignal
  ExpectedControlPort(String)
  ExpectedElementPort(String)
  ExpectedBankPort(port~ : String, width~ : Int)
  ExpectedRowPort(port~ : String, width~ : Int)
  ExpectedMaskPort(width~ : Int)
  UnsupportedBankedCollisionPolicy(@ir.MemoryReadWritePolicy)
} derive(Debug, Eq)

///|
/// The FIFO depth contract is never inferred from the integer value.
pub(all) enum FifoDepthContract {
  PowerOfTwo
  GeneralDepth
} derive(Debug, Eq)

///|
/// Checked FIFO construction parameters.
pub struct FifoConfig {
  name : String
  element_type : @ir.SignalType
  depth : @ir.MemoryDepth
  depth_contract : FifoDepthContract
  occupancy_width : @ir.Width
} derive(Debug, Eq)

///|
pub fn FifoConfig::new(
  name : String,
  element_type : @ir.SignalType,
  depth : Int,
  depth_contract : FifoDepthContract,
) -> FifoConfig raise MemoryComponentError {
  if name.is_empty() {
    raise EmptyComponentName
  }
  if !element_type.is_data() {
    raise InvalidElementType
  }
  if depth <= 0 {
    raise InvalidFifoDepth(depth)
  }
  if depth_contract is PowerOfTwo && !is_power_of_two(depth) {
    raise FifoDepthNotPowerOfTwo(depth)
  }
  let canonical_depth = @ir.MemoryDepth::new(depth) catch {
    _ => raise InvalidFifoDepth(depth)
  }
  let occupancy_width = width_for_maximum(depth) catch {
    _ => raise InvalidFifoDepth(depth)
  }
  {
    name,
    element_type,
    depth: canonical_depth,
    depth_contract,
    occupancy_width,
  }
}

///|
pub fn FifoConfig::name(self : FifoConfig) -> String {
  self.name
}

///|
pub fn FifoConfig::element_type(self : FifoConfig) -> @ir.SignalType {
  self.element_type
}

///|
pub fn FifoConfig::depth(self : FifoConfig) -> @ir.MemoryDepth {
  self.depth
}

///|
pub fn FifoConfig::depth_contract(self : FifoConfig) -> FifoDepthContract {
  self.depth_contract
}

///|
pub fn FifoConfig::occupancy_width(self : FifoConfig) -> @ir.Width {
  self.occupancy_width
}

///|
/// FIFO request/response signals. A successful pop request produces
/// `response_valid` and its corresponding data exactly one cycle later.
pub struct FifoSignals {
  push_ready : @wire.Signal
  pop_ready : @wire.Signal
  response_valid : @wire.Signal
  response_data : @wire.Signal
  full : @wire.Signal
  empty : @wire.Signal
  occupancy : @wire.Signal
}

///|
pub fn FifoSignals::push_ready(self : FifoSignals) -> @wire.Signal {
  self.push_ready
}

///|
pub fn FifoSignals::pop_ready(self : FifoSignals) -> @wire.Signal {
  self.pop_ready
}

///|
pub fn FifoSignals::response_valid(self : FifoSignals) -> @wire.Signal {
  self.response_valid
}

///|
pub fn FifoSignals::response_data(self : FifoSignals) -> @wire.Signal {
  self.response_data
}

///|
pub fn FifoSignals::full(self : FifoSignals) -> @wire.Signal {
  self.full
}

///|
pub fn FifoSignals::empty(self : FifoSignals) -> @wire.Signal {
  self.empty
}

///|
pub fn FifoSignals::occupancy(self : FifoSignals) -> @wire.Signal {
  self.occupancy
}

///|
/// The bank-select contract is explicit. General counts include a validity
/// comparison; power-of-two counts guarantee every selector encoding is valid.
pub(all) enum BankCountContract {
  PowerOfTwoBanks
  GeneralBankCount
} derive(Debug, Eq)

///|
/// Whole-element or fixed-granularity writes for every bank.
pub(all) enum BankedWriteMask {
  WholeElement
  Granular(Int)
} derive(Debug, Eq)

///|
/// Checked split-address banked-memory parameters. Callers provide separate
/// bank and row signals; no undocumented bit slicing or modulo mapping occurs.
pub struct BankedMemoryConfig {
  name : String
  element_type : @ir.SignalType
  bank_count : Int
  rows_per_bank : @ir.MemoryDepth
  bank_contract : BankCountContract
  write_mask : BankedWriteMask
  read_write_policy : @ir.MemoryReadWritePolicy
  bank_width : @ir.Width
} derive(Debug, Eq)

///|
pub fn BankedMemoryConfig::new(
  name : String,
  element_type : @ir.SignalType,
  bank_count : Int,
  rows_per_bank : Int,
  bank_contract : BankCountContract,
  write_mask : BankedWriteMask,
  read_write_policy : @ir.MemoryReadWritePolicy,
) -> BankedMemoryConfig raise MemoryComponentError {
  if name.is_empty() {
    raise EmptyComponentName
  }
  if !element_type.is_data() {
    raise InvalidElementType
  }
  if bank_count <= 0 {
    raise InvalidBankCount(bank_count)
  }
  if bank_contract is PowerOfTwoBanks && !is_power_of_two(bank_count) {
    raise BankCountNotPowerOfTwo(bank_count)
  }
  if rows_per_bank <= 0 {
    raise InvalidRowsPerBank(rows_per_bank)
  }
  let rows = @ir.MemoryDepth::new(rows_per_bank) catch {
    _ => raise InvalidRowsPerBank(rows_per_bank)
  }
  match write_mask {
    WholeElement => ()
    Granular(granularity) => {
      let width = element_type.width().bits()
      if granularity <= 0 || width % granularity != 0 {
        raise InvalidMaskGranularity(element_width=width, granularity~)
      }
    }
  }
  if read_write_policy is Reject {
    raise UnsupportedBankedCollisionPolicy(read_write_policy)
  }
  let bank_width = width_for_maximum(bank_count - 1) catch {
    _ => raise InvalidBankCount(bank_count)
  }
  {
    name,
    element_type,
    bank_count,
    rows_per_bank: rows,
    bank_contract,
    write_mask,
    read_write_policy,
    bank_width,
  }
}

///|
pub fn BankedMemoryConfig::name(self : BankedMemoryConfig) -> String {
  self.name
}

///|
pub fn BankedMemoryConfig::element_type(
  self : BankedMemoryConfig,
) -> @ir.SignalType {
  self.element_type
}

///|
pub fn BankedMemoryConfig::bank_count(self : BankedMemoryConfig) -> Int {
  self.bank_count
}

///|
pub fn BankedMemoryConfig::rows_per_bank(
  self : BankedMemoryConfig,
) -> @ir.MemoryDepth {
  self.rows_per_bank
}

///|
pub fn BankedMemoryConfig::bank_contract(
  self : BankedMemoryConfig,
) -> BankCountContract {
  self.bank_contract
}

///|
pub fn BankedMemoryConfig::write_mask(
  self : BankedMemoryConfig,
) -> BankedWriteMask {
  self.write_mask
}

///|
pub fn BankedMemoryConfig::read_write_policy(
  self : BankedMemoryConfig,
) -> @ir.MemoryReadWritePolicy {
  self.read_write_policy
}

///|
pub fn BankedMemoryConfig::bank_width(self : BankedMemoryConfig) -> @ir.Width {
  self.bank_width
}

///|
pub fn BankedMemoryConfig::row_width(self : BankedMemoryConfig) -> @ir.Width {
  self.rows_per_bank.address_width()
}

///|
pub struct BankedMemorySignals {
  read_data : @wire.Signal
  read_accepted : @wire.Signal
  response_valid : @wire.Signal
  read_bank_valid : @wire.Signal
  write_bank_valid : @wire.Signal
  write_accepted : @wire.Signal
}

///|
pub fn BankedMemorySignals::read_data(
  self : BankedMemorySignals,
) -> @wire.Signal {
  self.read_data
}

///|
pub fn BankedMemorySignals::read_accepted(
  self : BankedMemorySignals,
) -> @wire.Signal {
  self.read_accepted
}

///|
pub fn BankedMemorySignals::response_valid(
  self : BankedMemorySignals,
) -> @wire.Signal {
  self.response_valid
}

///|
pub fn BankedMemorySignals::read_bank_valid(
  self : BankedMemorySignals,
) -> @wire.Signal {
  self.read_bank_valid
}

///|
pub fn BankedMemorySignals::write_bank_valid(
  self : BankedMemorySignals,
) -> @wire.Signal {
  self.write_bank_valid
}

///|
pub fn BankedMemorySignals::write_accepted(
  self : BankedMemorySignals,
) -> @wire.Signal {
  self.write_accepted
}

///|
fn is_power_of_two(value : Int) -> Bool {
  value > 0 && (value & (value - 1)) == 0
}

///|
fn width_for_maximum(maximum : Int) -> @ir.Width raise @ir.IrError {
  let mut value = maximum
  let mut bits = 0
  while value > 0 {
    value = value >> 1
    bits += 1
  }
  @ir.Width::new(bits.max(1))
}

///|
pub extend MemoryComponentError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MemoryComponentError with Eq::{not_equal, equal}

///|
pub extend FifoDepthContract with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FifoDepthContract with Eq::{not_equal, equal}

///|
pub extend FifoConfig with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FifoConfig with Eq::{not_equal, equal}

///|
pub extend BankCountContract with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BankCountContract with Eq::{not_equal, equal}

///|
pub extend BankedWriteMask with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BankedWriteMask with Eq::{not_equal, equal}

///|
pub extend BankedMemoryConfig with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BankedMemoryConfig with Eq::{not_equal, equal}

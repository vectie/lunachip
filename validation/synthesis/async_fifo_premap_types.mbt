///|
/// A canonical bit in Yosys JSON. Connection arrays are least-significant bit
/// first; constants remain typed so an unknown cannot be mistaken for a wire.
enum PreMapBit {
  Wire(Int)
  Zero
  One
  Unknown
  HighImpedance
} derive(Debug, Eq, Hash)

///|
struct PreMapSignal {
  bits : Array[PreMapBit]
} derive(Debug, Eq)

///|
fn PreMapSignal::width(self : PreMapSignal) -> Int {
  self.bits.length()
}

///|
struct PreMapPort {
  direction : String
  signal : PreMapSignal
} derive(Debug, Eq)

///|
struct PreMapCell {
  name : String
  cell_type : String
  parameters : Map[String, String]
  connections : Map[String, PreMapSignal]
  directions : Map[String, String]
} derive(Debug, Eq)

///|
struct PreMapModule {
  name : String
  ports : Map[String, PreMapPort]
  cells : Array[PreMapCell]
  netnames : Map[String, PreMapSignal]
} derive(Debug, Eq)

///|
struct PreMapDocument {
  creator : String
  hardware_module : PreMapModule
} derive(Debug, Eq)

///|
struct AsyncFifoResetRole {
  signal : String
  kind : String
  polarity : String
  value : String
} derive(Debug, Eq)

///|
struct AsyncFifoDomainRole {
  clock : String
  edge : String
  reset : AsyncFifoResetRole
} derive(Debug, Eq)

///|
struct AsyncFifoLaneRole {
  index : Int
  memory : String
  width : Int
  source_payload : String
  raw_read : String
  visible_payload : String
} derive(Debug, Eq)

///|
struct AsyncFifoRoleInventoryV2 {
  fixture : String
  top_module : String
  depth : Int
  synchronizer_stages : Int
  pointer_width : Int
  address_width : Int
  source_domain : AsyncFifoDomainRole
  destination_domain : AsyncFifoDomainRole
  source_valid : String
  source_ready : String
  destination_ready : String
  destination_valid : String
  source_transfer : String
  destination_transfer : String
  write_binary : String
  write_binary_next : String
  write_gray : String
  write_gray_next : String
  read_binary : String
  read_binary_next : String
  read_gray : String
  read_gray_next : String
  full : String
  full_next : String
  nonempty : String
  nonempty_next : String
  write_address : String
  read_address : String
  read_gray_pipeline : Array[String]
  write_gray_pipeline : Array[String]
  lanes : Array[AsyncFifoLaneRole]
} derive(Debug, Eq)

///|
pub struct AsyncFifoPreMapIssue {
  code : String
  role : String
  expected : String
  observed : String
} derive(Debug, Eq)

///|
pub struct AsyncFifoPreMapReport {
  fixture : String
  top_module : String
  creator : String
  checks : Array[String]
  issues : Array[AsyncFifoPreMapIssue]
  sequential_bits : Int
  memory_bits : Int
} derive(Debug, Eq)

///|
fn AsyncFifoPreMapReport::completed_checks_passed(
  self : AsyncFifoPreMapReport,
) -> Bool {
  self.issues.is_empty()
}

///|
pub fn AsyncFifoPreMapReport::issues(
  self : AsyncFifoPreMapReport,
) -> ReadOnlyArray[AsyncFifoPreMapIssue] {
  ReadOnlyArray::from_array(self.issues)
}

///|
pub fn AsyncFifoPreMapIssue::code(self : AsyncFifoPreMapIssue) -> String {
  self.code
}

///|
pub fn AsyncFifoPreMapIssue::role(self : AsyncFifoPreMapIssue) -> String {
  self.role
}

///|
pub fn AsyncFifoPreMapIssue::expected(self : AsyncFifoPreMapIssue) -> String {
  self.expected
}

///|
pub fn AsyncFifoPreMapIssue::observed(self : AsyncFifoPreMapIssue) -> String {
  self.observed
}

///|
suberror AsyncFifoPreMapError {
  InvalidJson(String)
  UnknownKey(path~ : String, key~ : String)
  MissingKey(path~ : String, key~ : String)
  WrongType(path~ : String, expected~ : String)
  InvalidValue(path~ : String, value~ : String)
} derive(Debug, Eq)

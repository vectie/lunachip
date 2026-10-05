///|
/// Private elaboration inputs shared by the existing compute controller and
/// alternative operand storage. Active dimensions and reduction are latched.
priv struct ExecuteStorageInputs {
  accept : @wire.Signal
  read_launch : @wire.Signal
  read_step : @wire.Signal
  active_rows : @wire.Signal
  active_columns : @wire.Signal
  reduction : @wire.Signal
}

///|
/// Read data and initialization prefixes exist before command preflight. The
/// finish hook receives preflight legality and can then connect storage writes
/// and readiness without forward references in the combinational graph.
priv struct ExecuteStorage {
  a_data : Array[@wire.Signal]
  b_data : Array[@wire.Signal]
  a_valid : Array[@wire.Signal]
  b_valid : Array[@wire.Signal]
  a_prefixes : Array[@wire.Signal]
  b_prefixes : Array[@wire.Signal]
  finish : (@wire.Signal) -> (@wire.Signal, @wire.Signal) raise
}

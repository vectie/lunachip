///|
/// LunaWave keeps its original value vocabulary as a source-compatible facade
/// while the shared semantic implementation is owned by `semantics`.
pub using @semantics {type LogicBit, type LogicValue, type LogicValueError}

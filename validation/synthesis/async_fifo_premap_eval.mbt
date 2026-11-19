///|
enum PreMapLogic {
  L0
  L1
  LX
} derive(Debug, Eq)

///|
fn logic_not(value : PreMapLogic) -> PreMapLogic {
  match value {
    L0 => L1
    L1 => L0
    LX => LX
  }
}

///|
fn logic_and(left : PreMapLogic, right : PreMapLogic) -> PreMapLogic {
  match (left, right) {
    (L0, _) | (_, L0) => L0
    (L1, L1) => L1
    _ => LX
  }
}

///|
fn logic_xor(left : PreMapLogic, right : PreMapLogic) -> PreMapLogic {
  match (left, right) {
    (L0, value) | (value, L0) => value
    (L1, value) | (value, L1) => logic_not(value)
    _ => LX
  }
}

///|
fn premap_parameter_int(cell : PreMapCell, name : String) -> Int32? {
  guard cell.parameters.get(name) is Some(text) else { return None }
  let mut value = 0
  for digit in text {
    match digit {
      '0' => value = value << 1
      '1' => value = (value << 1) | 1
      _ => return None
    }
  }
  Some(value)
}

///|
fn premap_connection(cell : PreMapCell, name : String) -> PreMapSignal? {
  cell.connections.get(name)
}

///|
fn premap_driver(
  hardware_module : PreMapModule,
  wire : Int32,
) -> (PreMapCell, Int32)? {
  let mut found : (PreMapCell, Int32)? = None
  for cell in hardware_module.cells {
    for port, direction in cell.directions {
      if direction == "output" {
        guard cell.connections.get(port) is Some(signal) else { continue }
        for index, bit in signal.bits {
          if bit == Wire(wire) {
            if found is Some(_) {
              return None
            }
            found = Some((cell, index))
          }
        }
      }
    }
  }
  found
}

///|
fn premap_eval_bit(
  bit : PreMapBit,
  hardware_module : PreMapModule,
  roots : Map[Int32, PreMapLogic],
  memo : Map[Int32, PreMapLogic],
  visiting : Map[Int32, Bool],
) -> PreMapLogic {
  match bit {
    Zero => L0
    One => L1
    Unknown | HighImpedance => LX
    Wire(wire) => {
      guard roots.get(wire) is None else { return roots[wire] }
      guard memo.get(wire) is None else { return memo[wire] }
      if visiting.contains(wire) {
        return LX
      }
      visiting[wire] = true
      let value = match premap_driver(hardware_module, wire) {
        Some((cell, output_index)) =>
          premap_eval_cell_output(
            cell, output_index, hardware_module, roots, memo, visiting,
          )
        None => LX
      }
      visiting.remove(wire)
      memo[wire] = value
      value
    }
  }
}

///|
fn premap_eval_signal(
  signal : PreMapSignal,
  hardware_module : PreMapModule,
  roots : Map[Int32, PreMapLogic],
  memo : Map[Int32, PreMapLogic],
  visiting : Map[Int32, Bool],
) -> Array[PreMapLogic] {
  signal.bits.map(bit => {
    premap_eval_bit(bit, hardware_module, roots, memo, visiting)
  })
}

///|
fn logic_truth(values : Array[PreMapLogic]) -> PreMapLogic {
  let mut unknown = false
  for value in values {
    match value {
      L1 => return L1
      LX => unknown = true
      L0 => ()
    }
  }
  if unknown {
    LX
  } else {
    L0
  }
}

///|
fn logic_equal(
  left : Array[PreMapLogic],
  right : Array[PreMapLogic],
  case_equal : Bool,
) -> PreMapLogic {
  if left.length() != right.length() {
    return LX
  }
  let mut unknown = false
  for index in 0..<left.length() {
    match (left[index], right[index]) {
      (L0, L0) | (L1, L1) | (LX, LX) if case_equal => ()
      (L0, L0) | (L1, L1) => ()
      (LX, _) | (_, LX) if !case_equal => unknown = true
      _ => return L0
    }
  }
  if unknown {
    LX
  } else {
    L1
  }
}

///|
fn premap_eval_cell_output(
  cell : PreMapCell,
  output_index : Int32,
  hardware_module : PreMapModule,
  roots : Map[Int32, PreMapLogic],
  memo : Map[Int32, PreMapLogic],
  visiting : Map[Int32, Bool],
) -> PreMapLogic {
  let input = fn(name : String) {
    match premap_connection(cell, name) {
      Some(signal) =>
        premap_eval_signal(signal, hardware_module, roots, memo, visiting)
      None => []
    }
  }
  match cell.cell_type {
    "$not" => {
      let a = input("A")
      if output_index < a.length() {
        logic_not(a[output_index])
      } else {
        LX
      }
    }
    "$and" | "$xor" => {
      let a = input("A")
      let b = input("B")
      if output_index >= a.length() || output_index >= b.length() {
        LX
      } else if cell.cell_type == "$and" {
        logic_and(a[output_index], b[output_index])
      } else {
        logic_xor(a[output_index], b[output_index])
      }
    }
    "$reduce_or" => logic_truth(input("A"))
    "$reduce_xor" => {
      let mut value = L0
      for bit in input("A") {
        value = logic_xor(value, bit)
      }
      value
    }
    "$logic_not" => logic_not(logic_truth(input("A")))
    "$logic_and" => logic_and(logic_truth(input("A")), logic_truth(input("B")))
    "$eq" | "$eqx" | "$nex" => {
      let equal = logic_equal(input("A"), input("B"), cell.cell_type != "$eq")
      if cell.cell_type == "$nex" {
        logic_not(equal)
      } else {
        equal
      }
    }
    "$mux" => {
      let a = input("A")
      let b = input("B")
      let select = input("S")
      if output_index >= a.length() ||
        output_index >= b.length() ||
        select.length() != 1 {
        LX
      } else {
        match select[0] {
          L0 => a[output_index]
          L1 => b[output_index]
          LX =>
            if a[output_index] == b[output_index] {
              a[output_index]
            } else {
              LX
            }
        }
      }
    }
    "$pmux" => {
      let a = input("A")
      let b = input("B")
      let select = input("S")
      let width = premap_parameter_int(cell, "WIDTH").unwrap_or(0)
      if output_index >= width || output_index >= a.length() {
        LX
      } else {
        let mut selected = -1
        for index, value in select {
          match value {
            L1 => if selected < 0 { selected = index } else { return LX }
            LX => return LX
            L0 => ()
          }
        }
        if selected < 0 {
          a[output_index]
        } else {
          let index = selected * width + output_index
          if index < b.length() {
            b[index]
          } else {
            LX
          }
        }
      }
    }
    _ => LX
  }
}

///|
fn premap_relation_matches(
  hardware_module : PreMapModule,
  target : PreMapSignal,
  roots : Array[PreMapSignal],
  expected : (Int32) -> Array[Bool],
) -> Bool {
  let root_bits : Array[PreMapBit] = []
  for signal in roots {
    for bit in signal.bits {
      root_bits.push(bit)
    }
  }
  if root_bits.length() > 16 {
    return false
  }
  for assignment in 0..<(1 << root_bits.length()) {
    let root_values : Map[Int32, PreMapLogic] = Map([])
    for index, bit in root_bits {
      guard bit is Wire(wire) else { return false }
      root_values[wire] = if ((assignment >> index) & 1) == 1 { L1 } else { L0 }
    }
    let actual = premap_eval_signal(
      target,
      hardware_module,
      root_values,
      Map([]),
      Map([]),
    )
    let wanted = expected(assignment)
    if actual.length() != wanted.length() {
      return false
    }
    for index in 0..<wanted.length() {
      if actual[index] != (if wanted[index] { L1 } else { L0 }) {
        return false
      }
    }
  }
  true
}

///|
fn assignment_word(assignment : Int32, offset : Int32, width : Int32) -> Int32 {
  (assignment >> offset) & ((1 << width) - 1)
}

///|
fn word_bits(value : Int32, width : Int32) -> Array[Bool] {
  Array::makei(width, index => ((value >> index) & 1) == 1)
}

///|
pub extend PreMapLogic with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PreMapLogic with Eq::{not_equal, equal}

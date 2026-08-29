# LunaChip conservative SystemVerilog backend

## Version and target

Backend version 1 covers the memory-free SystemVerilog-2017 subset; version 2
adds first-class synchronous memories and is selected when a design contains
memory state. Each canonical IR module is emitted as one `EmittedModule` whose filename is exactly
`<emitted-module-identifier>.sv`. Strict lint and compilation must consume
these per-module artifacts. `EmittedDesign.source` is only a deterministic
concatenated convenience view.

Each file uses `` `default_nettype none `` around exactly one module. Ports,
internal nets, constants, slices, casts, and arithmetic widths are explicit.
Combinational nodes retain canonical NodeId order. Registers use `always_ff`
and nonblocking assignment.

## Semantic lowering

- `Bits` and `UInt` lower to unsigned `logic`; `SInt` lowers to signed `logic`.
- clocks and resets lower to one-bit `logic` ports.
- add, subtract, equality, and ordered comparisons use width-specialized
  synthesizable helpers. Their four-state behavior matches LunaWave's known
  mask semantics rather than SystemVerilog operator pessimism.
- multiply explicitly preserves LunaWave's known-zero dominance. Full signed
  and unsigned multiplication extends both operands to the full result width
  before multiplication.
- logical and arithmetic shifts carry explicit unsigned/signed casts.
- slice bounds, concatenation order, extension, truncation, reinterpretation,
  and mux branch order are rendered directly from validated canonical IR.
- a register update is one nested conditional expression under `always_ff`:
  active-high synchronous reset, then enable/next, then old-state hold. The
  conditional expression also preserves LunaWave's per-bit X merge for unknown
  reset and enable controls.

Synchronous memories lower to unpacked `logic` arrays with registered reads.
Single-port writes use direct addressed nonblocking assignments. Multi-port
writes compose deterministic lower-port-ID priority per bit only for addressed
words; they do not emit a depth-wide next-array copy or commit loop. Read-old,
read-new, no-change, undefined, masks, enables, collision assertions, and
non-power-of-two bounds remain explicit in the emitted source.

Each memory defines `lc_ak<memory-id>(address)` for address-knownness. In normal
four-state simulation it evaluates `((^address) !== 1'bx)`, preserving LunaWave
unknown-address behavior. Under the standard ``FORMAL`` macro defined by
Yosys `read_verilog -formal`, it returns `1'b1`: the selected formal model is
two-state, so every solver address is binary and there is no independent X
known-mask dimension. Numeric bounds remain enforced for non-power-of-two
depths. Formal receipts must declare this abstraction; a formal result makes no
claim about unknown-address payloads or X detection. Those semantics remain
covered by LunaWave unit tests and normal four-state RTL simulation.

Canonical `RegisterSpec.initial = None` emits no initializer. A four-state
simulator therefore observes X until reset or a next-state update. An explicit
initial value is rejected with `UnsupportedExplicitRegisterInitial`; emitting
an `initial` block or silently dropping the value would not be portable
synthesis semantics. Differential fixtures must reset before observation.

A supported nonempty module has no dead canonical nodes. Reachability begins
at every output driver and closes backward over every combinational operand.
A reachable register additionally makes its clock, next state, reset, and
enable dependencies reachable. The first unreachable canonical NodeId fails
with `UnreachableNode`; the emitter does not silently eliminate the node, add
dummy logic, or weaken lint. This keeps the all-node name manifest truthful.
An empty zero-node module remains supported.

## Identifier encoding

All identifiers are ordinary, unescaped SystemVerilog identifiers with an
`lc_` prefix. Source names are encoded injectively as `_bHH` for every
canonical UTF-8 byte. Nothing is deleted or normalized, so Unicode, reserved
words, punctuation, and strings that resemble the encoding cannot collide.
The first encoded byte follows the decimal ordinal directly; there is no
additional separator, so generated identifiers never enter C++'s reserved
double-underscore namespace. Role prefixes plus canonical ordinals provide
scoped uniqueness:

- `lc_m<module-id><encoded-name>` — module;
- `lc_n<node-id>` — module-local node;
- `lc_i<node-id><encoded-name>` — input port;
- `lc_o<port-id><encoded-name>` — output port;
- `lc_a<memory-id><encoded-name>` — module-local memory array;
- `lc_ak<memory-id>` — memory address-knownness helper;
- `lc_fn_<operation>_w<width>` — module-local semantic helper.

## Name manifest versions

`NameManifest.to_canonical_text` is newline-terminated UTF-8 text:

```text
LUNACHIP-SYSTEMVERILOG-NAMES 1
TOP <module-id>
REGISTER-INITIALIZATION implicit-four-state-x-reject-explicit
MAP <kind> <module-id> <local-id> <source-utf8-hex-or-dash> <sv-identifier>
...
END
```

Mapping order is module order, then each node followed immediately by its
input-port mapping when applicable, then output-port order. A module mapping
uses local ID `-1`; node and input IDs are NodeIds; output IDs are canonical
output-array indices. The source-name field is lower-case UTF-8 bytes separated
by underscores, or `-` when a node has no source name.

Version 2 adds `MEMORY-INITIALIZATION implicit-four-state-x` and `memory`
mappings while retaining every version-1 record and order rule. Memory-free
designs remain byte-identical version 1 manifests.

The current canonical IR has names but no generator source-span table. The
manifest therefore maps all presently available module/node/port identities;
future span metadata can extend a new manifest version without changing v1.

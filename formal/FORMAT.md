# LunaChip formal artifact formats

All artifacts are UTF-8 text with LF line endings and one final LF. Text values
that might contain whitespace or non-ASCII characters are encoded as lowercase
hexadecimal UTF-8 bytes. SHA-256 values are exactly 64 lowercase hexadecimal
digits. Parsers reject unknown versions, reordered or extra fields, malformed
integers, duplicate names, noncanonical list order, extra whitespace, and any
input that does not byte-for-byte equal its canonical reserialization.

## Property export

`export_properties` returns an SVA snippet for insertion immediately before the
containing module's `endmodule` and a `LUNACHIP-FORMAL-PROPERTIES 1` manifest.
Stable labels combine the property ID with an injective UTF-8 encoding of the
source name. The current observation domain is `rising-pre-edge`.

`export_yosys_clocked_properties` returns an equivalent clocked-immediate
rendering for the locked Yosys frontend. It retains the exact same typed
property manifest and stable labels. For these point predicates, a known-high
disable is tested at the observation edge; the source-set digest distinguishes
this concrete rendering from the concurrent SVA rendering.

`parse_formal_property_manifest` reconstructs the typed plan and verifies every
stable label, property ordinal, signal identity, role, domain, disable mode,
and canonical byte. The export manifest is not an unparsed sidecar.

The disable modes are:

- `never`: the property is always active at its observation domain;
- `known-high-asynchronous`: SVA `disable iff (signal === 1'b1)`, so unknown
  does not silently disable checking.

Predicates are emitted as `predicate === 1'b1`. Assertions and assumptions
therefore fail closed on unknown under a four-state simulator; covers hit only
on known one. External two-state formal engines retain their normal symbolic
interpretation.

## Proof task manifest schema 1

A bounded task records:

```text
LUNACHIP-FORMAL-TASK 1
TASK <name-utf8-hex>
ARTIFACT <logical-name-utf8-hex> sha256 <digest>
TOOL <name-utf8-hex> <version-utf8-hex>
ENGINE <engine-utf8-hex>
CLASS bounded
MODE bmc-safety|bounded-cover
BOUND <positive-clock-steps>
ASSUMPTIONS <count>
A <ordinal> <stable-name-utf8-hex>
PROPERTIES <count>
P <ordinal> <stable-name-utf8-hex>
END
```

An unbounded task replaces the class/mode/bound records with:

```text
CLASS unbounded
MODE prove-safety
INDUCTION k-induction <positive-depth>|pdr
```

Assumption and property lists are canonical UTF-8 byte order, internally
unique, mutually disjoint, and the property list is nonempty. Artifact names
are logical POSIX-relative names; absolute paths, Windows drive/backslash
paths, empty components, `.` and `..` are rejected.

An untimed task always uses schema 1. Its constructors, canonical field order,
accepted bytes, and emitted bytes are unchanged.

## Proof task manifest schema 2

A task carrying an explicit multi-clock timing contract uses
`LUNACHIP-FORMAL-TASK 2`. It retains every schema-1 task field through the
property list and then appends:

```text
GLOBAL-TIMESTEP <positive-engine-steps>
COINCIDENCE atomic-global-pre-state
CLOCKS <positive-count>
C <ordinal> <domain-id> rising named <path-utf8-hex> <name-utf8-hex>
C <ordinal> <domain-id> rising node <module-path-utf8-hex> <node-id>
LEGAL-TRANSITIONS <count>
L <ordinal> <stable-assumption-label-utf8-hex>
FAIRNESS <count>
F <ordinal> <stable-assumption-label-utf8-hex>
END
```

`GLOBAL-TIMESTEP` is a positive count in the formal engine's global discrete
step unit. It is deliberately not a physical-time claim. Clock bindings are
sorted by ascending domain ID. Domain IDs and exact named/node signal
references are unique, and the current supported edge is explicitly
`rising`. Sparse domain IDs remain valid.

`atomic-global-pre-state` means that all clock edges active on one global
timestep observe one shared pre-state and commit together. A runner may not
replace this with sequential clock updates in domain or source order.

Legal-transition and fairness lists are separately sorted by canonical UTF-8
byte order, internally unique, and mutually disjoint. Every listed value must
also occur in the task's `ASSUMPTIONS` list. They are stable exported labels,
not source property names or free-form runner directives. Empty legal or
fairness lists are allowed; an empty clock list is not.

The schema-2 parser rejects unsupported signal kinds, clock edges, coincidence
policies, negative domain IDs, duplicate clock domains or signals, duplicate
or cross-role labels, labels absent from the task assumptions, noncanonical
ordering, and any byte that does not match canonical reserialization.

## Proof result manifest schema 1

A result starts with `LUNACHIP-FORMAL-RESULT 1`, records
`TASK-MANIFEST sha256 <digest>`, repeats all canonical task fields, and then
records:

```text
RESULT <typed-result>
COUNTEREXAMPLE none|artifact <name-utf8-hex> sha256 <digest>
WITNESS none|artifact <name-utf8-hex> sha256 <digest>
DETAIL none|utf8-hex <reason-utf8-hex>
END
```

Bounded safety results are `bounded-pass`, `counterexample`, `inconclusive`,
or `tool-error`. Bounded cover results are `cover-witness`,
`no-cover-witness-within-bound`, `inconclusive`, or `tool-error`. Only an
unbounded safety result may be `proved`. The parser rejects `proved` under a
bounded task even if every other byte is canonical.

`counterexample` requires a counterexample artifact. `cover-witness` requires
a witness artifact. Other success outcomes forbid both. Inconclusive and tool
error outcomes require a nonempty detail; conclusive outcomes forbid one.

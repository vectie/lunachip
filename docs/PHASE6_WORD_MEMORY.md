# Opt-in portable word-read transport

`ring_concurrent_word_tile` constructs the fetched concurrent core with
four-byte descriptor fetches and a word-buffered operand loader. The existing
`ring_concurrent_tile` constructor keeps its byte-read transport and exact
canonical IR, ordinary SystemVerilog and name-manifest identities.

The new constructor adds the canonical parameter `memory_read_bytes=4`.
Adapters must select this transport explicitly and support its read shapes;
the existing byte-only capability manifest does not negotiate this extension.
Descriptor encoding0.2, logical commands, dimensions, two-slot ownership,
completion ordering, signed arithmetic and result stores retain their rules.
The prior Device ABI/proof receipts do not automatically qualify this variant.

| Transfer | Address | Bytes | Mask | Response data |
| --- | --- | --- | --- | --- |
| Byte read | Any admitted byte | 1 | 1 | Byte in bits7:0, zero extended |
| Word read | Four-byte aligned | 4 | 15 | Four consecutive bytes, little endian |
| Result write | Four-byte aligned | 4 | 15 | Existing acknowledged store rules |

Read requests carry `write=0` and `data=0`. The bus still has one outstanding
request, held request fields under backpressure, a global UInt32 tag, and
owner-local tag restoration. The existing three-client round-robin arbiter
and protocol-fault poison logic are shared unchanged. A tag increments for
each accepted memory transaction, including one increment for a word read.

The descriptor reader consumes addresses0,4,…,28 within each32-byte slot,
assembling low and high halves of its four64-bit packet lanes. Publication
and slot-release rules are unchanged; partial fetches never admit a packet.

The operand loader chooses a word when the current address is aligned and
at least four columns remain in that row. Its full-width column comparison
precedes selection. It falls back to byte reads for unaligned prefixes and
short tails, so a word never crosses a row or reads padding. Existing complete
rectangle preflight still checks dimensions, stride and address bounds.

On a successful response, the loader commits the low byte as signed INT8
through the original bank-ready interface. Every accepted bank write advances
the cursor and completed-byte count by one. While buffered bytes remain, it
shifts by eight bits and stays in Commit; otherwise it requests the next
transfer. A stalled bank holds the buffer, count and coordinates. This adds
two bits of buffered-byte state without adding a memory or changing a bank.

A failed word response commits none of that word. Earlier bank commits remain
the completed-byte prefix. Malformed replies retain protocol fault/poison
behavior; unrelated poison cancels remaining commits. Reset clears buffered
ownership and requires the same joint external-transaction flush as before.
These are transport error boundaries; a failed generation never becomes a
successful operand merely because some bytes reached its bank.

Native tests cover all four alignments, short rows/tails, an8x8 signed-edge
matrix, held individual lanes, word failures, descriptor faults and reset.
The component verification fixture calls the actual loader construction and
control functions with free memory/poison/bank-ready cuts and Idle admission.
Its local properties and cover witnesses have that explicit scope. Independent
full-core RTL replay and physical CPU comparisons are separate gates; no
full-device unbounded proof is implied.

The first physical consumer is the [PRX100 projection target](PRX100_WORD_MEMORY.md).
That adapter accepts both read shapes in its existing synchronous staging
BRAM and exposes separate request counters. Clock, descriptor publication,
DDR bridge and workload comparisons are specified by that target contract.

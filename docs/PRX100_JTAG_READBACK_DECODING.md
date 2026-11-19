# PRX100 readback DATA decoding

The host-only `prx100-fpy` driver retains the qualified FPDDR1.3Q bitstream,
30 MHz JTAG, depth 16 operand queues and the FPW buffered bulk policy. It
compares `baseline` regex DATA decoding with `fast` fixed-width decoding and
batched completed-result DATA properties. Integer and floating-point hardware,
all physical payloads, launch ordering and completion checks are unchanged.

The fast decoder first accepts an underscore-separated list only when its
length matches the requested burst and every field contains exactly eight
ASCII hexadecimal digits. Otherwise it removes underscores and ASCII
whitespace, checks the exact requested width and hexadecimal character set,
and slices eight characters at a time in descending order. This preserves
Vivado's most-significant-word-first DATA representation as increasing-address
words, normalizes letter case, and rejects malformed or missing values.
The actual board campaigns take the slicing path for all 89 decoded values.
Ordinary short/control transactions retain the preceding decoder.

Completed-result DATA is fetched with one `get_property DATA $txns` call after
the existing sequential result/counter transaction list completes. The number
of returned values must equal the transaction count before decoding any value.
Every result word and all 34 counters per physical batch remain present and
checked. No result read occurs before observed DONE/error0. This changes
host property handling; the result transactions remain sequential within one
command, and group response visibility is unchanged.

Each coalesced 106-projection campaign still contains 11 physical batches,
848 DDR outputs, 374 counter words, complete poison/model-before/model-after
operand readbacks, guard checks and the preceding invalid-access tests.
The six logical warm requests share one18-job physical batch. Bulk groups
remain homogeneous and bounded by 16 transactions, 256 words per burst and
4 KiB boundaries. Existing explicit submitted-write and no-input-data read
markers retain their FPW meanings; no actual read word is omitted.

The first `prx100-fpx` experiment uses string-map/xdigit validation followed by
regex chunking. It and its full comparison series remain available separately.
The selected `prx100-fpy` series uses fresh baseline and candidate runs; results
from the two series must not be combined to manufacture a baseline.

Run in the pinned guest with a fresh root:

```
moon run /work/prx100-fpy-board.mbtx -- run \
  /work/builds/prx100-fpq-vivado-20261018-hold-a2 \
  /work/builds/prx100-fpp-jobs-20261017.json \
  /work/builds/prx100-fpq-qualification-20261018-a1.json \
  /work/builds/prx100-fpy-board-NEW 30000000 coalesced buffered fast
```

Use `baseline` instead of `fast` for the comparison. Run the `prx100-fpy`
audit, groups, metrics, policy, launches, warm and bulk validators, then
`prx100-fpy-readback.mbtx`. The last validator checks source-instrumented
decoder-path counts against the complete CPU-audited read coverage. Close the
owned server with `prx100-fpy-close.mbtx`. Each board run retains its exact
driver, generated Tcl, raw actual values, phase timings and tool/bit identity.

The [measurement report](evidence/prx100-fpx-20261018.md) records end-to-end
timings, decoder tests, counter coverage, independent audits and retained
evidence. Existing RTL/formal/physical qualification is inherited by exact
hardware identity; this host-only change requires no new FPGA build.

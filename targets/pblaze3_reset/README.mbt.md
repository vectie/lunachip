# PBlaze3 reset hold

`hardware_module()` constructs canonical module `Pblaze3ResetHold` with clock
input `clk`, active-high asynchronous `reset`, and active-low reset output
`release_n`. The output remains low while reset is asserted and for the first
127 healthy rising edges after deassertion. It rises on the 128th edge and
remains high until another reset assertion. A single eight-bit counter resets
to zero and saturates at 128; no initial register value is assumed.

```mbt check
///|
test {
  assert_eq(@pblaze3_reset.hardware_module().name(), "Pblaze3ResetHold")
}
```

The board shell owns raw fault combination and vendor `XPM_CDC_ASYNC_RST`.
Its reset output connects to `reset`, with asynchronous assertion and
synchronous deassertion in the independent 50 MHz `clk` domain. Keeping reset
asserted holds the counter at zero; a renewed fault restarts the full interval.
The 128 counted periods after upstream synchronous deassertion give 2.56 us
at 50 MHz, exceeding the board's 1.5 us XDMA reset assertion requirement.
This module does not create clocks, synchronize raw fault inputs, or measure
elapsed wall-clock time. A halted clock cannot advance release; asynchronous
assertion remains effective without a clock edge.

Native LunaWave tests cover exact release, held reset, saturation, reset at the
release boundary, assertion between edges, restart and a halted clock. The
generator emits through the standard canonical RTL backend. Physical clock
quality, vendor reset synchronization, XDMA timing and board behavior require
separate implementation and hardware evidence.

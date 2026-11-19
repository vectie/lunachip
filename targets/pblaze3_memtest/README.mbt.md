# PBlaze3 autonomous memory test

This independent target waits for calibrated, healthy memory, then executes two
complete write/read rounds through the existing PBlaze3 AXI bridge. Each round
writes every selected 16-byte line before reading any line. Round zero uses
address XOR seed XOR lane salt; round one complements those words. The production
export covers all 134,217,728 lines of the provisional 2 GiB window. Small counts
and aligned high bases are elaboration-only parameters for simulation.

The controller and unchanged bridge share a 50 MHz clock. The physical board
shell owns coordinated reset, calibration synchronization and the vendor AXI
clock converter to the 200 MHz MIG domain. Reset abandons work and preserves DDR
contents; failure never resets the bridge. Responses continue draining after a
sticky failure. A fresh coordinated reset is required for another run.

Only two 32-bit read-only GPIO observations are needed. `status0[31:29]` is phase
(0 waiting, 1 write issue, 2 write response, 3 read issue, 4 read responses,
5 PASS, 6 FAIL), bit28 is round, and bits27:0 count completed 16-byte lines in
the current phase. `status1` gives the current line address or the first failing
word address. Successful full-memory completion is exactly `status0=0xb8000000`:
phase5, round1 and count0x08000000. No write over JTAG starts the test.

Extra canonical observation ports retain completed writes/reads, the failed
word, expected/actual data, and first error code: 1 data mismatch, 2 calibration
or bridge-health loss, 3 nonzero response fault, 4 malformed/unowned response.
The physical shell does not expose these extra observations in its minimal GPIO
interface. A full pass establishes the tested 2 GiB window, not the absence of
additional physical memory. It does not qualify temperature, voltage or long
retention limits. No board qualification follows from simulation.

```mbt check
///|
test {
  assert_eq(@pblaze3_memtest.controller().name(), "Pblaze3Memtest")
  assert_eq(
    @pblaze3_memtest.controller(beats=2U, base_address=0x7fffffe0U).name(),
    "Pblaze3Memtest",
  )
}
```

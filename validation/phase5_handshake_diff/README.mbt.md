# Phase 5 toggle-handshake differential fixtures

This native-only package derives one Verilator-v2 stimulus stream per fixture
from the same normalized rational schedule used by LunaWave. Every fully-known
external input is driven before each atomic event, and every public output is
compared after every event. The production C++ bridge raises all coincident
clocks before its single evaluation.

The coordinated reset fixture labels unilateral mid-flight reset behavior as
`expected-reset-flush-loss`; it is not counted as a delivered transaction or
as lossless recovery. These tests make no placement, metastability, MTBF,
recovery/removal, timing-closure, or physical implementation claim.

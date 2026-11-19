# PRX100 matrix clock optimization — 2026-10-23

| Median resident end-to-end, five samples per image | Fresh baseline | Candidate | Reduction |
|---|---:|---:|---:|
| full | 350.949 ms | 304.011 ms | 13.375% |
| decode | 100.396 ms | 91.002 ms | 9.357% |

The dominant measured matrix cost is arithmetic issue: sixteen ordered FP32 lanes already accept one product per lane per edge. This optimization raises the core/debug clock from 33 1/3 MHz to 40.000 MHz. All MoonBit hardware, canonical IR and first-party emitted RTL are byte-identical; vendor clock IP and supplemental target timing constraints are the intentional physical changes. BF16 weight delivery, FP32 multiplication/accumulation, rounding, K order, nonlinear programs and memory layouts are unchanged.

| Matrix cycle attribution | Baseline | Candidate |
|---|---:|---:|
| total | 151.656 ms | 129.050 ms |
| issue | 117.965 ms | 98.304 ms |
| weight_wait | 21.101 ms | 20.255 ms |
| pipeline_drain | 7.373 ms | 6.144 ms |
| bank_handoff | 3.686 ms | 3.072 ms |
| result_write | 1.475 ms | 1.229 ms |
| instruction_control | 0.056 ms | 0.047 ms |

Matrix weight wait is the residual of actual per-instruction counters after subtracting the fixed, simulation-checked state schedule. It does not distinguish MIG, CDC and controller latency. These diagnostic sections insert HALTs; uninterrupted kernel and resident timings are measured separately. The original baseline attributed about 77.8% of matrix cycles to issuing arithmetic. Raising the clock initially exposed a target-constraint defect: Vivado applied 5 ns edge spacing to asynchronous FIFO payload paths. The canonical FIFO publishes its pointer through two synchronizer stages and registers nonempty before consumption. Explicit 10 ns payload/Gray delay bounds and 5 ns Gray bus-skew limits replace that inappropriate phase-dependent check. The bounds are narrower than the publication window; same-domain paths and synchronizer second stages retain normal setup/hold checks. See the retained PRX100_MATRIX_CLOCK contract for the derivation and AMD references.

| Workload / phase | Baseline median | Candidate median | Reduction |
|---|---:|---:|---:|
| full / kernel_us | 296.649 ms | 250.073 ms | 15.701% |
| full / launch_poll_counters_us | 302.925 ms | 258.462 ms | 14.678% |
| full / final_readback_us | 45.159 ms | 43.004 ms | 4.772% |
| full / cpu_check_us | 3.322 ms | 4.737 ms | -42.595% |
| full / program_switch_outside_timer_us | 647.368 ms | 657.856 ms | -1.620% |
| decode / kernel_us | 76.062 ms | 64.107 ms | 15.718% |
| decode / launch_poll_counters_us | 85.184 ms | 72.214 ms | 15.226% |
| decode / final_readback_us | 13.810 ms | 14.832 ms | -7.400% |
| decode / cpu_check_us | 1.452 ms | 1.162 ms | 19.972% |
| decode / program_switch_outside_timer_us | 163.819 ms | 167.567 ms | -2.288% |

Resident end-to-end includes START, polling, counters, final DDR readback, file writes and actual CPU checking. Intermediate tensors and KV stay on the board. Upload, program switching, integrity sweeps, diagnostics and tool startup are outside these timers. Both images use the same 100 MHz DDR UI, 10 MHz JTAG, queues of 16 and snapshot host policy. Component medians need not sum to the total median. Candidate counter conversion uses 25 ns per cycle.

Both campaigns pass 896,896 FP32 word comparisons at the unchanged CPU tolerance `1e-4 + 1e-4*abs(reference)`. Every checked word matches the ordered operation model bit-for-bit, and 317 cross-image tensors are byte-identical. All 108,544 actual in-timer checker words are independently rechecked. Maximum candidate stage/final absolute CPU error is 0.000030517578125 / 0.00000286102294921875. The existing nonlinear approximations can differ slightly from CPU library functions. Fresh CPU execution reproduces all 108 pinned reference binaries exactly.

Fresh scalar CPU four-token compute-only samples: 93, 93, 94 ms. They exclude loading and trace writes, have millisecond timer resolution and use no optimized BLAS. Initial uploads took 152.889 / 158.169 s in the baseline/candidate campaigns, including both packed and row-major controls. These are separate observations, not full cold-start inference timings.

Fresh pinned `moon info`, `moon fmt`, strict native checking and all 1,297 native tests pass. All 1,448 module files on each host match that host's qualified parent, including every one of the 199 protected integer inputs. The 15 hardware export files also match byte-for-byte. Prior actual-RTL differential, Yosys and bounded formal evidence is inherited through exact input identities and a fresh complete sealed-inventory verification; the new experiment does not claim fresh formal proofs. The complete inherited qualification is recorded in qualification.json.

Fresh routed setup, hold and pulse-width timing, DRC, core/UI/debug clocks and all 46 bus-skew checks (34 first-party Gray buses and 12 vendor checks) pass. Setup/hold slack: 0.143 / 0.034 ns. Resources: 52549 LUTs, 38340 registers, 70 BRAM tiles and 35 DSPs. Each clock attempt has a separate build directory and its reports are retained; no rejected image is programmed. The reloaded routed checkpoint independently checks all 34 Gray source-to-first-stage paths at 10 ns, all 34 normally timed second stages, all 17 payload FIFO bounds at 10 ns, and the health synchronizer. The four asynchronous reset assertion pins are the only new false-path endpoints. No clock-wide timing exception was added.

| Workload | Image | All resident samples, milliseconds |
|---|---|---|
| full | baseline | 358.069, 355.284, 347.744, 344.983, 350.949 |
| full | candidate | 302.888, 308.143, 310.878, 304.011, 300.491 |
| decode | baseline | 100.396, 100.310, 101.392, 107.292, 97.173 |
| decode | candidate | 91.002, 91.606, 88.482, 87.165, 92.559 |

All first uses, outliers and losing samples are retained. Each image also runs five row-major controls per workload, prefill and full diagnostics. Campaigns are separate rather than interleaved across bitstreams, so host timing noise remains. The board uses volatile configuration; flash and host OS are unchanged. The result covers one complete layer 0 / context 4 and cached position 3 decode, not full-model inference.

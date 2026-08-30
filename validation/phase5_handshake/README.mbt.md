# Phase 5 toggle-handshake native evidence

This package validates the public `LunaWire` toggle-handshake constructor by
executing its ordinary registered graph with `LunaWave`. It adds no behavioral
handshake model and makes no claim about metastability, MTBF, placement,
routing, recovery/removal, timing closure, or lossless unilateral reset.

The directed matrix covers coordinated idle reset, exact two-through-four
stage request and acknowledgement latency, stable source and destination
payload storage, destination backpressure, consume/refill, queued traffic,
atomic coincident edges, four-state controls and payloads, reset flush/loss,
snapshot restoration, and schema-2 replay/trace/VCD identity. A unilateral
reset while traffic is live is classified only as
`expected-reset-flush-loss`.

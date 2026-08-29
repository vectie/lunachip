# Phase 3 validation protocol

Status: **passed locally on 2026-08-30**. The authoritative ARM64 run used the
locked OCI provider and the `volume` workspace transport. All six fixtures
passed strict lint, compiled, executed, and agreed with LunaWave for exactly
102,000 post-reset cycles. The complete evidence record is checked in at
[`evidence/phase3-evidence.txt`](evidence/phase3-evidence.txt); its SHA-256 is
`abeabec77108423a2388491eae754f8afcc25d16367173b5f89553ad582f8e9e` and
its terminal state is `pass`.

## One fail-closed gate

Run the gate with no argument to create a private temporary run root, or give
it an absent or empty directory outside the repository when the artifacts must
be retained at a known location:

```sh
scripts/phase3-differential-gate.sh
scripts/phase3-differential-gate.sh /absolute/empty/run-root
LUNACHIP_VERILATOR_MOUNT_MODE=volume scripts/phase3-differential-gate.sh
```

An explicit directory is never reused when nonempty. The gate materializes the
six standard bundles itself, validates every harness manifest, and requires a
canonical `design.lcir` artifact in every bundle. It then uses only the pinned
OCI provider to lint, compile, and execute every fixture. Missing Docker state,
an absent platform digest, a warning, a build or harness failure, malformed
result bytes, an identity mismatch, a semantic mismatch, or fewer than the
locked 102,000 post-reset cycles stops the gate. There is no archive or host
tool fallback.

The runner defaults to read-only bind mounts. A remote Docker context such as
Colima may not share the host's `/private/tmp`; for that case, set
`LUNACHIP_VERILATOR_MOUNT_MODE=volume`. The runner stages checked inputs with
`docker cp` into an isolated Docker volume, runs the same locked image with the
same network and capability restrictions, and copies declared outputs back.
The gate validates and records `bind` or `volume` as workspace transport. This
is not a tool-provider fallback and does not relax content or result checks.

The representative families are combinational logic, arithmetic, controlled
counter, pipeline, LFSR, and ready/valid. Each contributes 17,000 compared
cycles. Cycle 0 is a synchronous-reset preamble: the harness executes its
rising edge, but neither LunaWave nor the differential evidence counts or
compares it. Compared result rows therefore run contiguously from cycle 1
through cycle 17,000.

## Independent result identity

`actual.tsv` is self-identifying. Its first row carries the bridge semantic
version, canonical-IR SHA-256, and exact stimulus SHA-256 written into the
compiled harness. Generated SystemVerilog identifiers are also the exact C++
model-member identifiers recorded in `manifest.json`; the bridge performs no
second sanitizer or name-mangling reconstruction. The MoonBit
`verify-standard` mode parses the identity fields from the independently
produced file and rejects identity disagreement before
comparing normalized observations. The gate does not substitute identity from
`expected.tsv`, and it does not use a bytewise file comparison as a semantic
oracle. Bundle materialization and verification both use the native release
target so the 102,000-cycle gate does not depend on debug-build overhead.

On success, deterministic evidence records the Git HEAD and status digest,
Moon compiler version, observed Verilator version, locked OCI platform digest,
selected workspace transport, exact canonical tool commands and statuses,
fixture/cycle totals, and SHA-256 for the lock, canonical IR, each RTL source,
both manifests, C++ harness,
stimulus, LunaWave expected result, Verilator actual result, and normalized
comparison report. `$RUN_ROOT` in
the recorded wrapper commands is the stable token for the run root; Verilator
commands use the stable container paths `/work` and `/out`. A failed run keeps
`phase3-evidence.incomplete` and never creates pass evidence.

The checked evidence intentionally records the pre-Phase-3 Git HEAD plus a
digest of the complete dirty status used by the gate. The Phase 3 commit is
created only after that evidence and its implementation are reviewed together;
the artifact hashes and tool identity, rather than a circular commit hash,
bind the independently executed run.

## Archive lint versus OCI execution

The extracted macOS ARM64 Homebrew bottle is independently locked and useful
for identity checks and strict SystemVerilog lint. It is not the Phase 3
compile/execute oracle because compilation would pull an unpinned host C++
toolchain into the result. Only the digest-addressed official OCI image has the
locked `identity`, `lint`, `compile`, and `execute` capabilities used by this
gate.

Local image preparation first attempted Docker Hub's ordinary pull transport,
which repeatedly terminated with `EOF`. Recovery used a direct,
content-addressed OCI import: the selected platform manifest and blobs were
transferred by digest, imported into the local Docker content store, and then
checked through `docker image inspect` and the runner's strict version check.
This changes only transport. The runnable image remains
`docker.io/verilator/verilator@<locked-platform-digest>`; mutable tags, rebuilt
images, alternate providers, and network access during execution remain
forbidden.

## Review checklist

- `scripts/phase3-verilator-validate.sh` and every generated manifest pass.
- All six lint and build commands return status 0 with warnings still fatal.
- All six harnesses execute with networking disabled and reset at cycle 0.
- MoonBit `verify-standard` reports equality for 102,000 post-reset cycles.
- Every required artifact digest is present in `phase3-evidence.txt`.
- The evidence terminates with `STATE pass`; incomplete evidence is not a pass.

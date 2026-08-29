# Pinned Verilator boundary

This directory defines LunaChip's independent Verilator 5.050 boundary. The
lock records immutable bytes; it is not evidence that a provider was fetched,
executed, or passed a differential gate.

## Providers

`oci` is the hermetic Phase 3 provider. Both supported Linux platform images
are addressed by manifest digest, never by `latest` or the mutable release tag.
The runner disables networking, drops capabilities, mounts the generated input
bundle read-only, and writes only to a separate output mount. OCI is the only
provider allowed to compile or execute a generated harness because the image
contains Verilator's C++ build environment.

`archive` is a checked macOS ARM64 Tahoe Homebrew bottle. Its archive, complete
extracted content tree, Perl wrapper, and native binary hashes are locked
independently. The tree digest is SHA-256 over sorted lines of
`<file-sha256><two spaces><relative-path><newline>` for every regular file; any
added, removed, or changed file fails closed. It may verify identity and lint
emitted RTL. It may not compile or execute Phase 3 evidence: doing that would
silently introduce an unpinned host compiler and build tools. The archive
provider never searches `PATH` for Verilator.

The upstream source hash is recorded separately from both packaging providers.
It documents which release source was packaged; it does not make either
provider interchangeable with a local source build.

## Command contract

Run every script from any directory; each resolves the repository root from
its own location.

```sh
scripts/phase3-verilator-validate.sh
scripts/phase3-verilator-provision.sh oci
scripts/phase3-verilator-run.sh oci version
scripts/phase3-verilator-run.sh oci lint path/to/bundle path/to/output
scripts/phase3-verilator-run.sh oci build path/to/bundle path/to/output
scripts/phase3-verilator-run.sh oci execute path/to/bundle path/to/output
```

Provisioning is explicit and may download only the digest selected for the
host architecture. The runner never pulls, installs, searches the host, or
falls back between providers. For the archive provider, set
`LUNACHIP_VERILATOR_ARCHIVE_ROOT` to the extracted `verilator/5.050` directory:

```sh
LUNACHIP_VERILATOR_ARCHIVE_ROOT=/absolute/extract/verilator/5.050 \
  scripts/phase3-verilator-run.sh archive version
```

`archive build` and `archive execute` are deliberately rejected. Bundle and
output directories must already exist, be distinct, and not use symlinks.
Build and lint outputs must start empty; execution refuses to overwrite an
existing result. Missing Docker, a stopped daemon, an absent digest, a wrong
executable digest, or a version mismatch is a hard error with a remediation
command.

## Harness generator interface

An emitter-owned harness generator creates a directory containing
`manifest.json`, every relative path named by that manifest, and no symlinks.
The manifest follows `harness.schema.json`.

- `sources` is the stable ordered list of emitted `.sv` files.
- `harness_cpp` includes `Vlunachip_model.h` and accepts exactly two arguments:
  the input stimulus path followed by the output result path. It drives all
  inputs simultaneously, performs one low/evaluate then high/evaluate rising
  edge per cycle, samples outputs after the high evaluation, and writes the
  requested result.
- Port identifiers in `manifest.json` are used directly as generated C++ model
  members; the harness does not reconstruct a second sanitized spelling.
- Phase 3 bridge ports are 1 to 64 bits wide. Wider emitted RTL remains valid,
  but requires a future multiword harness schema instead of silent truncation.
- `stimulus` is UTF-8 TSV with LF line endings and a final newline. Its header
  is `cycle` followed by every non-clock input in manifest order. It has one
  row per cycle; cycle numbers are canonical unsigned decimal (only zero may
  start with `0`). Values are lowercase hexadecimal without prefixes, padded
  to `ceil(width / 4)` digits, with unused high bits zero. Four-state input
  vectors and surrounding whitespace are rejected.
- `result` has the same byte-level rules. Its header is `cycle` followed by
  every output in manifest order, and each stimulus cycle produces exactly
  one result row. The differential comparator owns normalization and
  comparison; the C++ harness must not decide pass or fail against LunaWave.
- `clock.port` is excluded from TSV data. The harness starts it low. Generated
  stimulus must synchronously reset every compared state element before the
  first observation is compared.

The runner fixes the generated C++ class prefix to `Vlunachip_model`, the
language to IEEE 1800-2017, unknown initialization/assignment to zero, and one
build job. Inputs are mounted at `/work` and outputs at `/out`, so emitted
commands and diagnostics do not contain host-specific bundle paths.

## Lint and capability policy

Lint enables `--Wall` and `-Wpedantic`; warnings remain fatal. Timing constructs
are disabled because LunaChip's emitted subset has explicit edge-triggered
sequential logic and no delays or testbench timing controls. Assertions remain
enabled. `-Wno-fatal`, blanket warning suppression, unsupported black boxes,
and `--timing` are forbidden by the lock validator.

The compile policy uses `--cc --exe --build`, deterministic two-state unknown
handling, a fixed generated-model prefix, and a single build job. A later
evidence manifest must record the exact lock digest, provider digest, complete
command, input bundle digest, result digest, exit status, and normalized
comparison digest. None of those execution claims are made by this lock.

## Provenance

Version and flag behavior follow the Verilator 5.050 user guide:

- <https://verilator.org/guide/latest/install.html>
- <https://verilator.org/guide/latest/exe_verilator.html>
- <https://verilator.org/guide/latest/changes.html>
- <https://github.com/verilator/verilator/blob/v5.050/ci/docker/run/Dockerfile>

The official install guide documents released `verilator/verilator:<version>`
executable images and their wrapper behavior. The exact Docker Hub query
`GET https://hub.docker.com/v2/repositories/verilator/verilator/tags/v5.050`
resolved the currently published `v5.050` record to the index and platform
digests in `lock.json` on 2026-08-29. The `v` spelling comes from that registry
record (older guide examples omit it). The mutable tag is retained only as a
human discovery hint and is never executed.

## Differential gate

`scripts/phase3-differential-gate.sh [EMPTY_RUN_ROOT]` is the only integrated
Phase 3 pass gate. It materializes the standard bundles, validates each
manifest, and uses the OCI provider for strict lint, compile, and execution
before asking the MoonBit bridge to compare all independently generated result
files. The archive remains lint-only and is never selected as a fallback. See
`docs/PHASE3_VALIDATION.md` for reset-cycle accounting, self-identifying result
TSV, artifact evidence, and the local content-addressed import used after the
ordinary Docker Hub pull transport ended with `EOF`.

The integrated gate also accepts `LUNACHIP_VERILATOR_MOUNT_MODE=volume` for a
remote Docker context that cannot resolve host bind-mount paths. This stages
the checked bundle through an isolated Docker volume and records that workspace
transport without changing the locked OCI provider.

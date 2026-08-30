# Phase 4 synthesis and formal toolchain

## Status and scope

This boundary makes Yosys synthesis and SymbiYosys formal checks reproducible,
warning-strict, and fail-closed. The lock, schemas, validator, negative
self-tests, command generation, and both Docker transports are implemented.
The selected image has passed the nine-fixture Phase 4 synthesis matrix through
the volume transport on an arm64 host. That result establishes the synthesis
claims in `PHASE4_SYNTHESIS.md`; formal BMC/induction/cover claims remain bound
to their separate formal-gate evidence.

The boundary covers generic synthesis plus safety BMC, safety proof by
k-induction, and cover reachability. It does not claim FPGA mapping, timing
closure, physical design, fabrication, or silicon behavior.

## Provenance and immutable identity

YosysHQ publishes the official [Yosys source](https://github.com/YosysHQ/yosys),
[SBY source](https://github.com/YosysHQ/sby), and
[OSS CAD Suite archives](https://github.com/YosysHQ/oss-cad-suite-build/releases).
It does not publish an official combined Yosys/SBY OCI image. LunaChip therefore
uses a third-party image whose build input is public and auditable: the
[Zubax FPGA toolchain recipe](https://github.com/Zubax/fpga-toolchain-docker/blob/484793d8832ca010f6e3068f53677fa4f92a1177/oss/Dockerfile).
The publisher distinction is intentional; Zubax is the OCI publisher, while
YosysHQ and Bitwuzla remain the upstream tool sources.

The executable identity is exactly:

```text
platform: linux/amd64
image: ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775
OCI config: sha256:5a4191a1b674e2ca9eff5af1929f0fd217c95cce45a641259ce09274ecdde44a
recipe commit: 484793d8832ca010f6e3068f53677fa4f92a1177
oss/Dockerfile sha256: 741a232801ceaec884b5a7f74bcc7862378d34f88ed9632aa71932d3c270ea28
```

The image's `latest` tag is discovery metadata only. Execution always uses the
manifest digest and always requests `linux/amd64`; the non-executable
`unknown/unknown` attestation manifest associated with the tag is not selected.
An arm64 host therefore requires Docker's amd64 emulation support. There is no
native-host, archive, alternate-image, alternate-solver, or mutable-tag
fallback.

The recipe pins these tool inputs, which the lock independently identifies:

| Tool | Version/ref | Upstream artifact SHA-256 |
| --- | --- | --- |
| [Yosys](https://github.com/YosysHQ/yosys/tree/v0.68) | `v0.68` | `78faed2a95944eb18cbcfff0aaa77e976ed549e2b1c95493a9b8191eca067cb1` |
| [SBY](https://github.com/YosysHQ/sby/tree/b1a1e98cba941ec8433f8dc27f416cd7bb7f14be) | commit `b1a1e98cba941ec8433f8dc27f416cd7bb7f14be` (`v0.68`) | `bd2d73f34a5e58c64cbb4d421172c756d918ff8a2220cd0300328cf14d5e085d` |
| [Bitwuzla](https://github.com/bitwuzla/bitwuzla/releases/tag/0.9.1) | `0.9.1` Linux x86-64 static release | `057f1546ae2068df57beb178f3eeab1678f0e5f0c378787a05b7bb294617c9c6` |

The tool versions are checked again inside every execution and archived as
`tool-versions.txt`. Before execution, the exact locked repository manifest is
required in `RepoDigests`. The image ID must equal either the locked OCI config
digest (Docker's classic image store) or the locked manifest digest (Docker's
containerd image store); any other local identity is rejected. The config is
No tag lookup or mutable reference occurs when the container starts.

## Locked synthesis flow

The validator accepts only content-digested `.sv` sources and a safe Yosys top
identifier. The runner creates `yosys.ys`; a caller does not provide a script.
For every source it uses `read_verilog -sv -noautowire`, then:

```text
hierarchy -check -top <top>
proc
memory -nomap
check -assert
write_rtlil /out/pre-map.rtlil
write_json /out/pre-map.json
stat
synth -top <top> -flatten -latches error -noabc
check -assert
write_json /out/netlist.json
write_verilog -noattr -noexpr -nodec /out/netlist.v
```

Yosys runs with `-Q -T -e '.*'`: matching warnings are errors, banner and
footer timestamps are suppressed, and there are no warning waivers. Before
generic synthesis maps memories to cells, the runner executes `proc` and
`memory -nomap`, records `stat`, and archives the checkpoint as both
`pre-map.rtlil` and `pre-map.json`; this makes memory inference reviewable
instead of inferring efficiency from a final flattened netlist, while giving
typed structural checkers a graph format that does not depend on line-oriented
regular expressions. Successful output contains the generated script, exact
command, version record, log, pre-map RTLIL and JSON, final JSON and Verilog
netlists, and `PASS` status. Missing artifacts fail the run.

The generic synthesis step deliberately uses `-noabc`. The Phase 4 matrix
claims preservation of Yosys memory cells before mapping, not technology
mapping, area, or timing. Skipping ABC keeps the post-synthesis archival
netlists practical under the locked amd64-on-arm64 execution path without
weakening the pre-map inference observation.

## Locked formal flow and claim vocabulary

The manifest fixes one of three pairs; any mismatch is invalid:

| Mode | Locked claim | Meaning of `PASS` |
| --- | --- | --- |
| `bmc` | `bounded-safety-up-to-bound` | No assertion failure was found in the modeled executions through the declared depth. It is not an unbounded proof. |
| `prove` | `unbounded-safety-if-base-and-induction-pass` | SBY's base case and k-induction step both passed at the declared induction depth, establishing the modeled safety property without a time bound. |
| `cover` | `reachability-within-bound` | The cover target was reached within the declared depth; SBY records a shortest trace. |

The generated SBY configuration uses only `smtbmc bitwuzla` and fixes
`multiclock on`. The latter is required for the explicit global-formal-clock
harness that derives the design clock; omitting it would change the transition
system rather than merely reducing performance. Manifest `bound`
becomes SBY `depth`: it is a bounded horizon in `bmc`/`cover` and the
k-induction depth in `prove`. The [official SBY reference](https://yosyshq.readthedocs.io/projects/sby/en/stable/reference.html)
defines this mode-dependent option, supported engines, and Bitwuzla support. The
[official induction FAQ](https://yosyshq.readthedocs.io/projects/ap011/en/latest/faq_sby.html)
explains the separate base and induction checks.

An induction failure is not automatically a reachable design bug: the failed
induction state can be unreachable from reset. A base-case failure supplies a
bounded reachable counterexample under the declared assumptions; an induction
failure is retained and classified as an induction failure. Likewise, timeout,
unknown, tool error, and an unexpected result are non-pass outcomes. The
manifest's `expect` field is a regression expectation used by SBY to determine
its exit code; it never upgrades the semantic strength of a result.

The generated SBY script uses `multiclock on`, `logger -werror .*`,
`read_verilog -formal -sv -noautowire`, `hierarchy -check`, and `prep`. Each task has a maximum bound of
100,000 and timeout of 3,600 seconds. The generated `.sby`, exact command,
versions, SBY status directory, logs, models, and available VCD/testbench/
constraint traces remain in the caller's output directory for later hashing by
the Phase 4 evidence gate.

## Isolation and transport

Every tool execution uses the digest-pinned image with:

```text
--platform linux/amd64
--user <host-uid>:<host-gid>
--network none
--read-only
--cap-drop ALL
--security-opt no-new-privileges
--pids-limit 512
--tmpfs /tmp:rw,nosuid,nodev,size=256m
--workdir /tmp
HOME=/tmp TMPDIR=/tmp PYTHONDONTWRITEBYTECODE=1
```

Input is read-only and output is the only persistent writable area. The default
bind transport is for a local Docker daemon. With a remote daemon, set
`LUNACHIP_YOSYS_MOUNT_MODE=volume`; the runner stages bytes with `docker cp`,
uses scoped volumes, copies results back, rejects symlinked output, and cleans
all scoped resources. A new Docker volume is root-owned, so one isolated
container from the same pinned image changes only `/out`'s mode before
execution. It runs the image's `/usr/bin/python3` once as root under the same
network, read-only-root, capability, privilege, and PID isolation flags. The
actual Yosys/SBY container still runs as the host UID/GID. This narrow Python
initializer is necessary on arm64 emulation because the image's Rust coreutils
`/bin/chmod` panics while reading the emulated auxiliary vector; it is not
LunaChip source code or a service. Every run archives
`transport-receipt.txt`, including the mode, initializer identity, runtime
UID/GID, and locked image.

Transport changes byte movement only, not image identity, commands,
privileges, or result semantics. Docker's official
[run reference](https://docs.docker.com/reference/cli/docker/container/run/)
and [volume documentation](https://docs.docker.com/engine/storage/volumes/)
define these mechanisms.

## Commands and required empirical gate

```sh
scripts/phase4-yosys-selftest.sh
scripts/phase4-yosys-provision.sh oci
scripts/phase4-yosys-run.sh oci version
scripts/phase4-yosys-run.sh oci synth BUNDLE EMPTY_OUTPUT
scripts/phase4-yosys-run.sh oci formal TASK BUNDLE EMPTY_OUTPUT
```

For the existing remote LunaChip profile, the equivalent invocation is:

```sh
DOCKER_CONTEXT=colima-lunachip-phase3 \
LUNACHIP_YOSYS_MOUNT_MODE=volume \
scripts/phase4-yosys-provision.sh oci
```

Provisioning pulls only the digest-addressed amd64 image and verifies the three
versions. A real Phase 4 gate must then run representative successful synthesis,
bounded, induction, and cover jobs plus deliberately failing safety fixtures;
retain counterexamples; hash the lock, manifest, sources, generated commands,
versions, netlists, logs, statuses, and traces; and report tool failure or
registry unavailability without substituting another provider.

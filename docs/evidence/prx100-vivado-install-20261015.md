# PRX100 isolated Vivado installation, 2026-10-15

The user authorized an isolated Ubuntu22.04 environment on the existing Linux
server, storage under `/data`, and Vivado2025.2 installation. The existing
Ubuntu20.04 host package inventory remained byte-identical. No host package,
repository, startup service, bridge or firewall change was made.

## Installed environment

The KVM guest runs Ubuntu22.04.5 x86-64 with8 virtual CPUs,40GiB RAM and a400GiB
sparse disk. The initial24GiB allocation was increased after actual synthesis
memory pressure. A16GiB guest swap file was added during synthesis, within the
same VM disk. Its host storage root is `/data/lunachip-prx100`; guest SSH binds
only to host loopback port22240. The guest disk depends on the retained Ubuntu
cloud-image backing file. The VM does not automatically start after reboot.
Access and restart instructions are retained in `ACCESS.txt` and
`vm/start-command.txt` under the host storage root.

The AMD Linux web installer was transferred with matching SHA256:
`a78dbe8943c1c7ea14aea13937192d6316c0ba94e05bf6f4ebcdca9ef1a73280`.
Its embedded integrity check passed. The user generated the AMD authentication
token privately inside the guest. Credentials and token contents are excluded
from evidence.

The batch installer completed with exit0. Vivado ML Standard and Artix-7 device
support are installed at `/tools/amd/2025.2/Vivado`; other device families and
optional products were excluded. The configuration SHA256 is
`a6782eb4d042c7a74233d922b4487f7198321860891fc68c47fcb6690841db47`.
The executable's actual version output identifies2025.2, SW Build6299465,
IP Build6300035 and SharedData Build6298862. An actual Tcl query resolves
`xc7a100tfgg676-2`, and synthesis obtains a license for that device.

Guest logs live under `/work/logs`; build inputs, commands, source identities
and results live under `/work/builds`. The launcher pin binds executable bytes
and complete version output, not the entire installation or cross-host
bitstream reproducibility.

## Target qualification

The first real smoke build is retained as
`/work/builds/prx100-smoke-vivado-20261015-a1`. It fails during elaboration:
Vivado requires explicit input net kinds with `default_nettype none`.

The PRX100 adapter now annotates module input declarations with `wire` and
records `explicit-input-wire-v1` in the target manifest. A regression removes
those annotations and verifies exact equality with ordinary emitted RTL.
Canonical IR, portable hardware generators and the general emitter are
unchanged. The retained Array8 canonical core digest remains
`37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8`.

The build runner accepts both the uppercase and lowercase2025.2 CLI banners
while retaining exact pin verification and rejecting other releases. Its
release-header and inventory refusal tests pass on the actual guest.

The revised build uses the clean guest source snapshot `ad85ef1`.
`/work/builds/prx100-smoke-vivado-20261015-a2` passes the earlier elaboration
failure but the guest kernel kills synthesis at approximately23GiB resident
memory, immediately before swap activation. Its exit137 and kernel evidence
are retained. The swap-enabled attempt
`/work/builds/prx100-smoke-vivado-20261015-a3` was stopped with SIGTERM(exit143)
after heavy swapping, before a clean guest shutdown and RAM increase.
The40GiB attempt `/work/builds/prx100-smoke-vivado-20261015-a4` was also stopped
with SIGTERM(exit143) after synthesis approached40GiB resident memory without
completing. No additional RAM was allocated. Installation, device recognition
and license acquisition pass; PRX100 implementation remains unqualified.
An RTL/inference investigation is required before retrying the full target;
the source of this memory growth has not been established. No BRAM mapping,
routed timing or real bitstream is claimed.

The final local strict native suite passes1061/1061, with interface generation,
formatting and warning-strict checking complete. Pinned Verilator5.050 lint,
build and execution pass for the normalized composed byte interface; all3655
cycles agree with the typed comparator. Actual and expected result files have
SHA256 `86d9e19924f59adc6490da652f6322a78ed57bb5c9e9066584ffc580a7f69f10`.
The new result identity binds the normalized RTL; the stimulus is unchanged.
Pinned Yosys0.68 generic synthesis and final `check -assert` also pass. These
tools and scopes are the same as in the preceding PRX100 preparation ledger.
No new formal theorem, completed Phase6/7 gate or board execution is claimed.

## Retention

The campaign inputs, four vendor-build attempts, version/part probes and exact
guest Git source bundle are retained under
`/work/builds/prx100-vivado-evidence-20261015`. The Mac campaign archive is
`artifacts/prx100-vivado-qualification-20261015`, with a SHA256 inventory and
seal. It includes current independent digital evidence and host package
inventory comparisons. Compiler caches, vendor binaries, credentials and the
AMD authentication token are excluded. Original working copies are preserved;
no historical archive or unrelated cache was modified or removed.

The first local retention attempt exceeded the process-output capture limit
while checking a large decompressed Yosys result. Its partial working copy,
exact driver and failure log are preserved at
`/private/tmp/prx100-vivado-retention-attempt1-20261015`. The corrected driver
streams decompression to separate working files and uses complete `cmp`
checks; those verification copies also remain outside the final archive.

## Access

From the Mac:

```sh
ssh -p 32123 HwHiAiUser@106.39.18.146
```

Then enter the guest from the server:

```sh
ssh -i /data/lunachip-prx100/vm/id_ed25519 -o UserKnownHostsFile=/data/lunachip-prx100/vm/known_hosts -p 22240 builder@127.0.0.1
source /tools/amd/2025.2/Vivado/settings64.sh
vivado -version
```

The server's `/data/lunachip-prx100/ACCESS.txt` records build and restart
instructions. Choose a fresh directory for every build; existing outputs are
deliberately refused.

## Physical connection

The CP2102 UART was detected earlier; the latest host USB check finds neither
board USB device. The board schematic
shows an onboard FT2232HL path from the CPU_TAG USB connector through the FPGA
JTAG selector. Connect a second USB data cable to that connector before
concluding an external programmer is required. Follow the board connection
instructions in `targets/prx100/README.mbt.md`; power off before changing
jumpers. No USB pass-through, FPGA programming or physical execution has been
performed.

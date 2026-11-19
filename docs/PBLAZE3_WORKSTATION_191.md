# PBlaze3 workstation

The accelerator, USB cable and KVM guest are on `QaQ` at
`192.168.2.191`. The guest retains the Ubuntu installation, Vivado 2026.1
license identity, tool pins, model and historical build directories from
`prx100-jammy`. Guest SSH is bound to loopback on the workstation.

## Storage

| Location | Physical device | Contents |
| --- | --- | --- |
| `.191:/data/lunachip-prx100/vm/` | ZHITAI TiPro7000 2 TB NVMe, ext4 | Active VM and its working disks |
| `.191:/data/lunachip-prx100/vm/host191/local-active.qcow2` | Same NVMe | Writes from the migrated VM, including current Vivado runs under guest `/work/builds` |
| `.191:/mnt/lunachip-archive/lunachip-175-20261117/` | WDC WD40PURX 4 TB SATA HDD, ext4 | Recovery copy of the frozen source project, including the original VM chain |
| `.191:~/lunachip-migration-20261117/` | Same NVMe | Transfer logs and verification results |

On `.175`, the original `/data` mapped through LVM to the Seagate
`ST8000NM017B` 8 TB SATA HDD. Both the 225.4 GiB parent and the 50.3 GiB
overlay lived on that disk. The Ubuntu seed image used another 697 MiB.
Together the three images occupied 276.36 GiB and presented a 400 GiB
virtual disk. The two Samsung 980 SSDs on `.175` carried the RAID1 host
system volume. On `.191` the existing HDD filesystem is mounted by UUID
and the recovery directory is private to the workstation user.
[Source disk mapping](../artifacts/pblaze3-weight-overlap-100mhz-20261117-a1/source-storage.txt)
· [Destination disk mapping](../artifacts/pblaze3-weight-overlap-100mhz-20261117-a1/destination-storage.txt)

The live guest switched to its local NVMe disk chain at 17:57 CST on
November 17. The source and destination image hashes matched after
restoring a 16 MiB region of the transferred base. QEMU reports the live
writable image and all three backing files on `.191`. Both Vivado jobs
survived the switch. To start the guest after a shutdown, run
`bash /data/lunachip-prx100/vm/host191/start-command.txt` as `jiaanguo`
on the workstation.
[Live migration and image hashes](../artifacts/pblaze3-weight-overlap-100mhz-20261117-a1/migration-local-disk.txt)

At 18:23 CST the complete inventory on the source, the NVMe copy and
the HDD archive matched for all 53,608 regular files, including the three
VM images. All 50 symbolic link targets and 32 empty directories were
preserved. A byte-by-byte reconstruction of the 250,573,619,200-byte
rejected copy passed before releasing its storage. The recovery record
identifies the exact file, retained base, compressed patch, offset and both hashes.
[Three-way inventory](../artifacts/pblaze3-weight-overlap-100mhz-20261117-a1/migration-three-way.txt) · [Recovery record](../artifacts/pblaze3-weight-overlap-100mhz-20261117-a1/migration-cleanup.json)

The private copy of the original 230 MiB board documentation is at
`.191:/mnt/lunachip-archive/lunachip-vendor/pblaze3/wang_memblaze资料.7z`.
Its SHA-256 matches the previously recorded vendor input. Scanning the
1,052 members of the embedded Vivado project found no MCS/PRM image or
configuration-memory programming command identifying the flash part.
[Vendor source identity](../boards/pblaze3/vendor/provenance.json) · [Project search](../artifacts/pblaze3-pcie-100mhz-20261117-a1/vendor-flash-inspection.log)

## Access

The repository's PBlaze3 remote commands use the OpenSSH alias
`pblaze3-host` for both SSH and SCP. On a client with LAN access the
alias needs the following entries in `~/.ssh/config`.

```sshconfig
Host pblaze3-host
    HostName 192.168.2.191
    User jiaanguo
```

The development Mac reaches this private subnet through its configured
SSH jump host. From the Mac, connect to the workstation and then to the
guest with the pinned guest host key.

```sh
ssh pblaze3-host
ssh -i /data/lunachip-prx100/vm/id_ed25519 \
  -o UserKnownHostsFile=/data/lunachip-prx100/vm/known_hosts \
  -p 22240 builder@127.0.0.1
```

The workstation has adjacent LunaChip and LunaFlux development checkouts
at `/work/src/pblaze3-20261117-a1/{lunachip,lunaflux}`. Each shallow
checkout has its original Git commit and the working source changes.
The project-specific compiler matches the Vivado guest. To build on the
workstation, use the following environment in that shell.

```sh
export MOON_HOME=/work/toolchains/moon-20261012
export PATH="$MOON_HOME/bin:$PATH"
cd /work/src/pblaze3-20261117-a1/lunachip
moon check --target native --deny-warn
```

The pinned compiler also passed the native LunaFlux Qwen client tests on
this host. The matched control and lookahead Vivado inputs are under
`/work/builds/pblaze3-pcie-100mhz-20261117-a1/hardware-inputs/`.
[Checkout identities](../artifacts/pblaze3-pcie-100mhz-20261117-a1/workstation-checkouts.txt)
· [Compiler and checks](../artifacts/pblaze3-pcie-100mhz-20261117-a1/workstation-native-toolchain.log)
· [Native tests](../artifacts/pblaze3-pcie-100mhz-20261117-a1/workstation-targeted-tests.log)

## PCIe access on the host

PBlaze3 negotiated PCIe Gen2 ×8 at `0000:b3:00.0`. The board has
2 GiB DDR3. The workstation has eight 16 GB DDR4 DIMMs. The host runs
the native XDMA client. Place-and-route and bitstream generation run in
the local Vivado guest. Use the Digilent cable `261020153153` for initial
configuration and recovery. The `7a33` diagnostic image exposes its ILA
through PCIe XVC. The `7a31` inference image uses the control BAR for
execution and profiling. The XDMA driver can create an `_xvc` node
independently of the hardware's debug connections.
[PCIe transport and check results](../artifacts/pblaze3-pcie-100mhz-20261117-a1/RESULTS.md)

The matched 1 KiB inference builds use the `pcie-control-timing` profile in
`pblaze3-pcie-inference-build.mbtx`. Check `transport-properties.txt` for
`/xdma CONFIG.xdma_rnum_rids=16`, `/weight_ui_pipe CONFIG.REG_W=7` and
`/weight_ui_pipe CONFIG.REG_R=1` after block-design validation. The original
`pcie-control` profile reproduces the earlier interface settings.
[Timing repair and validation](../artifacts/pblaze3-pcie-command-ram-20261118-c1/RESULTS.md)

The Vivado 2026.1 build guest selected BASIC and rejected
`read_checkpoint -incremental` with error 12-29181. The route script sets
`general.maxThreads` to four on this eight-vCPU guest. To evaluate a
different license, point `XILINXD_LICENSE_FILE` to the license file or
server inside the guest and start a fresh Vivado process. Check the selected
tier in the first `Common 17-3922` message in the Vivado log. AMD offers free
regeneration for a valid 2025.1 or 2025.2 Enterprise license. Its 2026.1
feature table lists incremental compile for UltraScale and UltraScale+.
Confirm the command on the XC7K325T before budgeting for CORE.
[Actual Vivado error](../artifacts/pblaze3-pcie-command-ram-20261118-c1/reuse2-control.console)
· [AMD licensing options](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado/vivado-licensing-options.html)
· [AMD 2026.1 feature table](https://docs.amd.com/r/2026.1-English/ug973-vivado-release-notes-install-license/Feature-Availability-by-Subscription-Tier)

For a node-locked entitlement, this command prints the guest Ethernet
Host ID that AMD's license form requests. Run it as `builder` inside
the guest. The explicit loader runs the bundled FlexNet utility on this
Ubuntu installation.

```sh
/lib64/ld-linux-x86-64.so.2 \
  /tools/amd-2026.1/2026.1/Vivado/bin/unwrapped/lnx64.o/lmutil lmhostid -ether
```

| Operation | Workstation path |
| --- | --- |
| Weights, instruction segments, tensors, full logits and arbitrary DDR buffers | XDMA H2C/C2H |
| Start, completion, greedy token, DDR health, FPGA cycles and stalls | PCIe user BAR |
| Arm the DDR read trigger and retrieve all 1,024 ILA samples on `7a33` | PCIe XVC at 7.8125 MHz |
| Synthesis, placement and routing | Vivado in the local VM, with checkpoints on NVMe |
| Load a complete FPGA image or recover a missing PCIe endpoint | Digilent USB/JTAG |

For hardware waveform capture over PCIe, AMD provides an AXI-to-BSCAN
Debug Bridge that can share the control BAR. The installed XDMA driver's
default XVC offset is 0x40000, inside the inference controller's reserved
range. A debug image needs its own address decode and a matching host
offset before using that interface. Keeping the endpoint online during compute-logic updates
requires a static PCIe shell and a reconfigurable partition with its
own partial bitstream. The matched inference builds use full-device
bitstreams. [AMD AXI-XVC](https://docs.amd.com/r/en-US/pg195-pcie-dma/XVC-over-PCIe-Through-AXI-AXI-XVC)
· [AMD 7-series configuration](https://docs.amd.com/r/en-US/pg054-7series-pcie/Tandem-Configuration)

A full-image update can also be staged in configuration flash. A running
endpoint would receive the file by PCIe, verify the inactive flash image,
and request a MultiBoot reload through ICAPE2/WBSTAR. The host would then
rescan PCIe. The vendor pin file specifies SPI ×4. The installed flash
part, its capacity, and the location of a recoverable boot image still
need verification before that path can be used on this card.
[Vendor SPI configuration](../boards/pblaze3/vendor/vendor-io.xdc) · [AMD 7 Series Configuration Guide](https://docs.amd.com/api/khub/documents/FOs3lXmlcWxBhTIFxVKyGA/content)

The separate `ddr-xdma-ila-xvc` diagnostic design exposes a 250 MHz
XDMA ILA at PCIe subsystem `7a33` using a 4 KiB XVC window at
BAR offset `0x40000`. Its GPIO occupies the first 64 KiB. The launcher
validates the subsystem and physical device before opening the XVC
character device. Vivado has verified the register mapping and all 46
probe connections. The server and capture commands are for that debug
image after physical qualification. In the local VM, a reverse SSH
forward to the workstation's loopback listener lets the Vivado hardware
server reach the PCIe-backed XVC server.

```sh
# On .191, with the 7a33 diagnostic image active.
cd /work/src/pblaze3-20261117-a1/lunachip
export MOON_HOME=/work/toolchains/moon-20261012 PATH=/work/toolchains/moon-20261012/bin:$PATH
run=/work/builds/pblaze3-pcie-100mhz-20261117-a1
moon run scripts/pblaze3-xvc-server.mbtx "$run/xvc_pcie" /dev/xdma0 23539
```

The capture recipe arms the ILA on a DDR read-address handshake. Wait for
`armed` in Vivado's fresh capture directory, issue one C2H read on the
workstation, compare the bytes, then create `read-complete` **in that
same directory in the guest**. Vivado rejects a header-only CSV: it requires
1,024 consecutive samples and one trigger. For the aligned 1 KiB test,
compare the C2H file to the original payload with `cmp`, then run
`moon run scripts/pblaze3-xvc-read-proof.mbtx dma-read.csv 0x10000000 pattern.bin`
with that original payload. It checks the AR addresses, matches read responses
to their AXI IDs, checks RRESP and RLAST, and compares all 64 beats byte for
byte. On November 18, a single real read at `0x10000000` triggered at sample
0. The first data beat arrived at sample 58 and the final beat at sample
137. All 1,024 bytes matched. The vendor XDC fixed the generated TCK
constraint at divide-by-8. The routed shift logic produced a 128 ns
period, and separate timing analysis at that period passed setup and hold.
[Raw ILA](../artifacts/pblaze3-pcie-resume-20261118-b1/wave1/dma-read.ila) ·
[Decoded read](../artifacts/pblaze3-pcie-resume-20261118-b1/wave1/proof.json) ·
[Clock verification](../artifacts/pblaze3-pcie-resume-20261118-b1/tck-proof/tck32.receipt)

For a binary file, the positional arguments are the device prefix, board
DDR byte address, local file path, local file offset and byte count.
A download publishes a new file after the entire transfer succeeds.
An arbitrary upload to an inference image clears the resident-model
marker. Use LunaFlux for managed installs and warm inference.

```sh
cd /work/builds/pblaze3-pcie-100mhz-20261117-a1
./pblaze3_xdma download /dev/xdma0 0 readback-4k.bin 0 4096
```

The inference image assigns subsystem device ID `7a31` and a 1 MiB user
BAR. The controller starts at BAR byte 0 and the four DDR status bits
are at 0x80000. This preserves the Linux bridge's existing address
window. The LunaFlux adapter keeps its logical device-contract addresses.

The following command runs the PCIe bridge and the LunaFlux client on
the workstation. Set `image` to the directory containing the accepted
bitstream, its routed clock report and BUILD_COMPLETE. Set `run` to a
new evidence directory. Use `generate-resident` for the initial install,
`generate-warm` for a new prompt with the resident model, and
`benchmark-warm` for three timed trials with full-logit validation. The two
executables and Tcl bridge are installed under the directory shown.

```sh
cd /work/builds/pblaze3-pcie-100mhz-20261117-a1
model=/work/models/qwen3-0.6b-c1899de
contract=/work/builds/pblaze3-resident-20261030-a1/model-inputs/device-contract.json
fixture=/work/builds/pblaze3-bf16-clock-target-20261115-a1/strided75-install/benchmark/qualification-fixture.json
revision=c1899de289a04d12100db370d81485cdf75e47ca000000000000000000000000
./pcie-qwen benchmark-warm "$image" "$PWD/inference.tcl" "$PWD/pblaze3_xdma" \
  "$PWD/lunachip_qwen" "$contract" "$model" "$revision" "$fixture" \
  "$run" Hello 4 23536 /dev/xdma0
```

# PBlaze3 Vivado license configuration

Status checked 2026-10-26. **Base Vivado 2026.1 is now installed beside the
retained 2025.2 installation.** The retry completed with exit `0` and zero
error markers; its actual launcher is
`/tools/amd-2026.1/2026.1/Vivado/bin/vivado`. Startup/catalog checks passed;
the tool recognizes BASIC as active until **2027-10-26**. Actual XC7K325T
synthesis acquired the `Vivado_Synthesis` license and completed. The earlier
2025.2 XDMA synthesis run for `xc7k325tffg900-2` failed at license checkout:
`Common 17-348` reported the missing `Synthesis` feature, followed by
`Common 17-345`. See the retained
[actual synthesis log](../artifacts/pblaze3-vivado-attempts-20261026-a1/attempts/20261026-a9/evidence/runs/pblaze3_xdma_0_synth_1/runme.log).
Installing the Kintex-7 device files did not provide a synthesis entitlement.

## Current path: validate the installed base 2026.1

The user authorized configuring licensing directly. The authenticated AMD
portal successfully generated **Vivado Basic Tier License, Node Locked
License**, one **No Charge** seat, for the verified Linux VM on 2026-10-26.
The downloaded certificate is installed privately at
`/home/builder/.Xilinx/pblaze3-basic-2026.1.lic` with mode `600`, owner
`builder`, 2057 bytes. Transfer identities matched at every hop, and actual
Vivado startup recognized the certificate. The actual XC7K325T synthesis
and pulse-width gate now pass; see the retained
[2026.1 probe manifest](evidence/pblaze3-pulse-gate-20261026-2026-1-a1/manifest.json).
Base 2026.1 is installed **side by side**, retaining the
pinned 2025.2 installation and its evidence for comparison. An existing license covering 2025.2
can also unblock the preserved 2025.2 build independently.

The account holder completed AMD email verification. The official thin
installer downloaded successfully through the authenticated browser flow.
Its SHA-256 matched on the Mac, relay host and VM; its built-in archive check
passed. Extraction and ConfigGen completed. The minimal installation needs
**20.96 GB** of selected components in an isolated destination. Its first
attempt exited `3` after a component-download timeout around 13 GB; this
was not an authentication or license-check failure. No installer process
remained. The vendor's approximately 14 GiB download cache was preserved
under `/tools/amd-2026.1/Downloads/Vivado_2026.1`. The second attempt used
the same reviewed configuration with that cache left in place and completed
successfully. The final isolated destination occupies approximately 59 GiB.
The existing installer authentication token was accepted; no token was read
or copied by our driver.

| Download identity | Value |
| --- | --- |
| File | `FPGAs_AdaptiveSoCs_Unified_SDI_2026.1_0616_1700_Lin64.bin` |
| Bytes | `413313372` |
| Locally computed SHA-256 | `6583178a487800ed5cf34cacea9d0e3887c30fe688f2b5f5b215a0e910793c93` |

This hash binds the downloaded bytes and transfer checks; it is not presented
as an independently published AMD digest. The preparation driver is
[`pblaze3-vivado-prepare.mbtx`](../scripts/pblaze3-vivado-prepare.mbtx).
Its `status` action reports filtered progress without account identifiers.
The default monitors the original failed attempt. Use this explicit command
to inspect the successful retry:

```sh
moon run scripts/pblaze3-vivado-prepare.mbtx status /downloads/amd-private/pblaze3-install-20261-20261026-a2
```

Raw installer logs remain private on the VM under
`/downloads/amd-private/pblaze3-install-20261-20261026-a1` and the separate
retry directory ending `-a2`; they must not be
copied into an evidence archive without redaction.

For a node-locked certificate, bind it to the inner Linux VM using the
identity below. To transfer an existing certificate without displaying its
contents, first run on the **Mac**, replacing the quoted source path with
the actual `.lic` file:

```sh
scp -P 32123 "/absolute/path/to/license.lic" HwHiAiUser@106.39.18.146:/data/lunachip-prx100/amd-20261-private/pblaze3-existing.lic
ssh -p 32123 HwHiAiUser@106.39.18.146
```

Then run on the **outer compute host**:

```sh
scp -i /data/lunachip-prx100/vm/id_ed25519 -o UserKnownHostsFile=/data/lunachip-prx100/vm/known_hosts -P 22240 /data/lunachip-prx100/amd-20261-private/pblaze3-existing.lic builder@127.0.0.1:/downloads/amd-private/pblaze3-existing.lic
ssh -i /data/lunachip-prx100/vm/id_ed25519 -o UserKnownHostsFile=/data/lunachip-prx100/vm/known_hosts -p 22240 builder@127.0.0.1
```

Finally run as `builder` **inside the Linux VM**:

```sh
install -d -m 700 /home/builder/.Xilinx
install -m 600 /downloads/amd-private/pblaze3-existing.lic /home/builder/.Xilinx/pblaze3-existing.lic
export XILINXD_LICENSE_FILE=/home/builder/.Xilinx/pblaze3-existing.lic
stat -c '%a %U %n' /home/builder/.Xilinx/pblaze3-existing.lic
```

The last command prints permissions, owner and path only; expect `600 builder`.
These commands remain the reusable path for a separately supplied existing
license. The newly generated BASIC certificate uses the distinct filename
`pblaze3-basic-2026.1.lic` described below.

The existing `/home/builder/.Xilinx` directory is automatically searched by
AMD tools, including later independent SSH/build processes running as
`builder`. The export additionally selects the file for children of the
current shell; it does not change another SSH session or the Mac client's
environment. Keep the certificate outside the repository and evidence
archives. Sources:
[certificate installation](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Install-Certificate-Based-Node-Locked-License-Key-File),
[AMD license search order](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/licensing-faq.html).

If the existing license is floating, use the actual licensed server's
`port@host` in `XILINXD_LICENSE_FILE` instead and pass it into each remote
build process; the node-locked VM identity is then not the server identity.
Do not configure a new server unless the existing license requires one.

## Verified VM identity

| VM field | Observed value |
| --- | --- |
| Hostname | `prx100-jammy` |
| Network interface | `enp0s1` |
| MAC address | `52:54:00:12:34:56` |
| FlexNet Ethernet Host ID | `525400123456` |
| OS / architecture | Ubuntu 22.04.5 LTS / x86_64 |

Run these **inside the Linux VM** to reproduce the binding identity:

```sh
hostname
cat /sys/class/net/enp0s1/address
/lib64/ld-linux-x86-64.so.2 /tools/amd/2025.2/Vivado/bin/unwrapped/lnx64.o/lmutil lmhostid -ether
```

All three commands were executed successfully. The last command reported
`525400123456`. Its explicit loader avoids the installed `lmutil` binary's
missing `/lib64/ld-lsb-x86-64.so.3` interpreter without changing the OS. Keep
the VM's MAC stable after licensing; bind to this VM, not the Mac client or
the outer compute host.

## Free BASIC entitlement generated for 2026.1

AMD lists **BASIC, node-locked, $0** and includes **all Kintex-7 devices** in
its 2026.1 BASIC device table. The installed tool recognized this BASIC
certificate at startup and subsequently acquired the synthesis license on
`xc7k325tffg900-2` (`Common 17-349`).
BASIC requires free renewal every 12
months and does not enable releases before 2026.1. It therefore cannot fix
the installed 2025.2 checkout. Sources:
[AMD license tiers](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado/vivado-buy.html),
[UG973 device coverage](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Device-Availability-by-Subscription-Tier),
[AMD licensing FAQ](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/licensing-faq.html).

The authenticated portal workflow was completed with the user's explicit
authorization. These are the reproducible steps:

1. Open [AMD Product Licensing](https://account.amd.com/en/forms/license/license-form.html)
   and sign in. Complete the requested account/contact verification.
2. Select the **Vivado BASIC** certificate-based entitlement and generate a
   **node-locked** license. BASIC is listed as node-locked only; no floating
   license server is required.
3. Add the existing Linux VM as the host. Use the verified values above, selecting
   Ethernet/MAC as the Host ID type.
4. Review the selection, accept the license terms, and download the `.lic`
   file. AMD also emails it. Keep the certificate private and outside source
   control/evidence archives.

These steps follow
[UG973 license generation](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Create-and-Generate-a-License-Key-File).
The actual account-specific portal displayed the BASIC entitlement as
`Certificate - No Charge`. Its confirmation reported successful generation
for Host ID `525400123456`; Manage Licenses showed `prx100-jammy`, Linux
64-bit, Ethernet MAC and one activated BASIC seat. The browser downloaded
`Xilinx.lic` (2057 bytes). The license contents and account identifiers are
excluded from evidence.

## Side-by-side base 2026.1 preparation

Select **base 2026.1**, not 2026.1.1: AMD explicitly excludes minor releases
from BASIC. The Linux web installer is 394.17 MB; it downloads selected
components afterward. The 98.28 GB full archive is unnecessary for a
Vivado/Kintex-7-only installation. Sources:
[AMD 2026.1 downloads](https://www.amd.com/en/support/downloads/adaptive-socs-and-fpgas/development-tools/2026-1.html),
[authenticated Linux installer link](https://account.amd.com/en/forms/downloads/xef.html?filename=FPGAs_AdaptiveSoCs_Unified_SDI_2026.1_0616_1700_Lin64.bin).

The VM has 39 GiB RAM and approximately 229 GiB free disk at audit time.
Its OS is explicitly supported by
[UG973 2026.1](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Supported-Operating-Systems).
The fresh 2026.1 installer is under `/downloads/amd-private`; the existing
2025.2 `xsetup --batch Add` only
adds components to that installation. Its inspected `--help` exposes no
new-release thin-installer fetch operation; `DownloadOnly` downloads a full
image. Do not use that operation to obtain this 394.17 MB client.

These preparation commands were executed successfully in the VM:

```sh
bash /downloads/amd-private/FPGAs_AdaptiveSoCs_Unified_SDI_2026.1_0616_1700_Lin64.bin --check
bash /downloads/amd-private/FPGAs_AdaptiveSoCs_Unified_SDI_2026.1_0616_1700_Lin64.bin --keep --noexec --target /downloads/amd-private/installer-2026.1
/downloads/amd-private/installer-2026.1/xsetup -b ConfigGen
```

ConfigGen selection `2` chose Vivado and wrote its default
`/home/builder/.Xilinx/install_config.txt`. The prior file was backed up
beforehand, then restored and byte-compared after creating the separate
2026.1 configuration. Passing `-c NEWPATH` to ConfigGen was rejected because
`-c` names an input configuration, not a new output path.

The reviewed `/downloads/amd-private/install_config-2026.1.txt` contains:

| Option | Selected value |
| --- | --- |
| Product / edition | `Vivado` / `Vivado Design Suite` |
| Destination | `/tools/amd-2026.1` |
| Optional modules | `Kintex-7 FPGAs:1`; every other entry `0` |
| License acquisition | `Acquire or Manage a License Key:0` |
| Program/desktop shortcuts and file associations | All `0` |
| Configuration SHA-256 | `b2c3969f8c42f270ff186d699bc03f92f65976ecfa466da537503dcf7bfb6182` |
| Restored previous default SHA-256 | `27a236d050735dec5ab6a6bacc930e842c07dd00ba4e7026d7116965c8bb4bf8` |

The extracted installer identifies branch `2026.1`, build
`2026-05-27 11:41:04 UTC`, version `f57d91f`. This is the installer identity.
The actual installed tool reports **Vivado v2026.1**, **SW Build 6511674**,
**IP Build 6504888**, **SharedData Build 6501428**. The separate pin is
`/work/builds/vivado-2026.1-pin.json`. Its catalog contains
`xc7k325tffg900-2` and reports XDMA `4.2`, MIG 7-series `4.2`, clock wizard
`6.0`. References:
[extract the installer](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Extract-Web-Installer-Batch-Mode-Client),
[generate its configuration](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Generate-a-Configuration-File).

AMD documents a seven-day token lifetime. The existing token was accepted
by the actual 2026.1 installer under `builder`; its contents were not read.
If authentication expires on a later attempt, the account holder can run
the following interactive command. Do not put credentials in arguments or
logs. This token authenticates downloads; it is not the BASIC license.
Source:
[UG973 authentication token](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Acquire-Authentication-Token).

```sh
/downloads/amd-private/installer-2026.1/xsetup -b AuthTokenGen
```

The authorized side-by-side installation completed using this command:

```sh
/downloads/amd-private/installer-2026.1/xsetup -b Install -a XilinxEULA,3rdPartyEULA -c /downloads/amd-private/install_config-2026.1.txt
```

Source:
[UG973 web installation](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Web-Installer-Download-and-Install).
It uses the standard installer agreements, with automatic license
acquisition disabled. The free BASIC entitlement was generated separately
through the user's authenticated portal; no paid/evaluation entitlement
was selected.

## BASIC certificate and separate tool validation

The generated certificate was transferred to
`/downloads/amd-private/pblaze3-basic-2026.1.lic` and installed in AMD's
Linux discovery directory. These are the placement and shell-selection
commands:

```sh
install -m 600 /downloads/amd-private/pblaze3-basic-2026.1.lic /home/builder/.Xilinx/pblaze3-basic-2026.1.lic
export XILINXD_LICENSE_FILE=/home/builder/.Xilinx/pblaze3-basic-2026.1.lic
```

The dedicated [`pblaze3-license-install.mbtx`](../scripts/pblaze3-license-install.mbtx)
transfers the exact browser-downloaded certificate through the private relay
and VM staging directories, checks byte identity at each hop without
printing certificate contents or hashes, and installs it with mode `600`.
AMD documents automatic discovery
under `~/.Xilinx` and explicit file selection through `XILINXD_LICENSE_FILE`:
[UG973 certificate installation](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Install-Certificate-Based-Node-Locked-License-Key-File),
[license search order](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/licensing-faq.html).

The separate 2026.1 pin and actual XC7K325T synthesis validation are complete.
The pulse probe's 20 ns case exited `0` with no pulse-width violation; its
0.1 ns negative case was rejected by real `Timing 38-282` diagnostics and
exited `2` with one violation. `Common 17-349` confirms that the synthesis
license was acquired. The probe's sealed logs and checksum inventory are
retained in
[the dedicated evidence directory](evidence/pblaze3-pulse-gate-20261026-2026-1-a1/).
This proves the installed tool's target synthesis entitlement and pulse gate.
The complete MIG/XDMA board build, timing closure and physical board checks
remain separate gates. The 2025.2 pin and its failed-run evidence are retained.

BASIC limits XSIM to 50,000 instances and restricts ILA/debug features;
telemetry cannot be disabled. Ordinary third-party simulator support and
JTAG programming remain available. IP licensing is unchanged, so vendor-IP
generation and checkout still need actual validation. Sources:
[UG973 feature limits](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Feature-Availability-by-Subscription-Tier),
[AMD IP licensing FAQ](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/licensing-faq.html).

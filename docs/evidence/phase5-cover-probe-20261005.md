# Remaining asynchronous-FIFO cover probes on 2026-10-05

Both previously unexecuted named cover tasks now pass independently under the
unchanged pinned tool lock. Fresh bundles were generated at source commit
`e135ee382c959b7047597f100fb44c4239873adb`:

| Task | Result | Witness step | SBY elapsed |
|---|---|---|---|
| `valid-async-fifo-cover-simultaneous` | cover-witness | 31 | 18 seconds |
| `valid-async-fifo-cover-watched` | cover-witness | 31 | 18 seconds |

Each is bounded to 128 global formal steps, with its existing schema-2 timing
contract, seven assumptions, two legal clock-transition assumptions and two
clock fairness assumptions. The first witness reaches simultaneous enqueue
and dequeue; the second reaches watched-token consumption. No unbounded or
physical CDC claim follows.

The runs used the existing network-disabled, read-only volume transport and
the locked `linux/amd64` image
`ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`.
Both complete runner invocations exited zero; their typed `result.lcfr`
records contain `RESULT cover-witness` and bind exactly one witness.
The retained `outputs.sha256` manifests verify after copying.

The complete bundles, outputs, logs and witnesses are retained outside Git at
`/Users/kq/Workspace/lunachip/.phase5-cover-probe-evidence-20261005`.
Original run root:
`/private/tmp/lunachip-phase5-cover-probe-20261005.XNRdrr`.

These are individual task results, not a completed FIFO or Phase 5 gate.
The earlier incomplete receipt is preserved and has not been amended or
sealed. A fresh full FIFO gate and successful unchanged-snapshot Phase 5
aggregate are still required. This successful startup does not promise that
all later external processes will start.

| Artifact | SHA-256 |
|---|---|
| `bundles/valid-async-fifo/source-set.lcfs` | `a98b20fb71bb50ae2438cba79bbedfd972f8a9e8330b625d02125c8f20b023db` |
| `simultaneous/result.lcfr` | `caf69f64d6a8e4f103451fb7ecfafe6c60f99b7f49754eb8d8adfd6aab183c8e` |
| `simultaneous/receipt.lcfe` | `3222c1ff777382c1824a8afcc101cf7fe777cc30d2bb9e1035fffdca38657c17` |
| `simultaneous/outputs.sha256` | `1ddfce5dad8db657e06acb6b78c69bca40aba489f5b4d2e6872dc9847b04b755` |
| `simultaneous/valid-async-fifo-cover-simultaneous-work/engine_0/trace0.vcd` | `709be5dd8290914ac811b48a192e337388deb0c00fd76477308ce8128f0e4921` |
| `watched/result.lcfr` | `021ccf567373a5fe1ce52c9c6fea9fa2d1ca6822531ea15c1550a0b5f09a927f` |
| `watched/receipt.lcfe` | `d5908aa473c78be1d2f91544ab8b05e6a9fd85be41b58fb230d143918008bcaa` |
| `watched/outputs.sha256` | `e58b1e100391a34beedd66d399e3a59d06195b08510d0704d724d87527d243c5` |
| `watched/valid-async-fifo-cover-watched-work/engine_0/trace0.vcd` | `39874766009e18c2c7f32cadab7bce8ece2948bed6b7f3f93fb2ae493642c0e4` |

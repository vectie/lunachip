# LunaWave replay CLI

Run a saved LunaWave replay bundle without writing a custom simulator program.
The native command uses the canonical IR, stimuli, taps and stop condition
already stored in the bundle, then exports the actual native trace and VCD.

## Run a replay

From the LunaChip repository root:

```sh
moon run --target native --deny-warn cmd/lunawave -- replay /absolute/input.replay /absolute/new-output
```

The output directory must not exist, and its parent must already exist. An
existing file or directory is rejected without reading the input or changing
the destination. The command does not overwrite, resume or remove prior runs.

Successful execution writes exactly two artifacts:

- `trace.txt` is the canonical LunaWave trace, including known masks and event
  boundaries.
- `trace.vcd` is the VCD export of that same actual trace.

Schema 1 bundles retain their legacy trace format. Schema 2 bundles retain
their original normalized timebase, atomic event boundaries and coincident
clock domains; the command does not regenerate a clock schedule. See the
[replay format](../../wave/replay/FORMAT.md) for constructing a bundle through
the public `wave/replay` API.

## Read the outcome

The command reports `stop_reached` and `expected_matches` separately, together
with the expected and actual canonical-trace digests. It succeeds only when
both booleans are true. Matching a partial trace does not mean the requested
stop condition was reached.

A mismatching digest or unreached stop prints a checked `ReplayFailed` error
and exits with code 1 after retaining both actual artifacts. The error includes both booleans,
digests and the output directory so a failed run remains inspectable. Input,
parse, execution and serialization failures create no output directory. An
output I/O failure can leave a partial directory; it is retained, not deleted
or presented as a complete replay.

```sh
moon run --target native --deny-warn cmd/lunawave -- help
```

This command runs LunaWave reference simulation. A successful replay is not
independent RTL agreement, a formal proof, physical timing or hardware evidence.

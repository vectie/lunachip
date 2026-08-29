# Locked Yosys and formal boundary

This directory defines LunaChip's Phase 4 external-tool contract. It is not a
second RTL implementation and it does not permit ambient host tools.

`lock.json` selects exactly one OCI manifest for `linux/amd64`. The mutable
`latest` tag is retained only to explain how the manifest was discovered; no
runner executes that tag. The selected image is published by Zubax, not by
YosysHQ. Its public recipe is pinned by repository commit and file digest, and
the Yosys, SBY, and Bitwuzla inputs named by that recipe are independently
locked here. YosysHQ provides official source releases and OSS CAD Suite
archives, but does not publish an official Yosys/SBY OCI image suitable for
this boundary.

`job.schema.json` is the transport schema. `job.json` names content-digested
SystemVerilog inputs and typed formal tasks. The validator additionally rejects
symbolic links, missing or hash-mismatched inputs, duplicate source paths,
duplicate source basenames, duplicate task names, unsafe paths, unknown keys,
and a formal `mode` whose `claim` has different semantics.

The runner accepts only these commands:

```text
scripts/phase4-yosys-run.sh oci version
scripts/phase4-yosys-run.sh oci synth BUNDLE OUTPUT
scripts/phase4-yosys-run.sh oci formal TASK BUNDLE OUTPUT
```

Formal jobs always use the lock's `multiclock: true` policy. This is part of
the modeled clock semantics, not a caller-selectable performance switch.

`BUNDLE/job.json` is mandatory and `OUTPUT` must exist, be empty, and not be a
symbolic link. The runner generates the Yosys script or SBY file from the
validated manifest. Callers cannot append flags, select another engine, or
substitute a host binary. The output records the generated command and exact
tool versions alongside logs, netlists, status, and any SBY traces.

Synthesis inference is classified by
`scripts/phase4-yosys-inference-check.sh` against
`inference-report.schema.json`. Eligible forms require their complete pre-map
`$mem_v2` shape, including size, width, and read/write-port counts. Dynamic
multiwrite forms are observation-only and never imply a physical-RAM claim.

The default `LUNACHIP_YOSYS_MOUNT_MODE=bind` uses ordinary bind mounts. Set it
to `volume` for a remote Docker daemon that cannot see host paths. Volume mode
copies the already validated input into scoped volumes, runs the same locked
image under the same isolation, copies output back, rejects output symlinks,
and removes its containers and volumes on success or failure.

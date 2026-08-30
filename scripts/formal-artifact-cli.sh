#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

[ "$#" -ge 1 ] || {
  echo "formal-artifact-cli: missing operation" >&2
  exit 1
}
operation=$1
case "$operation" in
  verify|verify-result|collect) ;;
  *)
    echo "formal-artifact-cli: usage: $0 verify BUNDLE TASK | $0 verify-result BUNDLE TASK RESULT | $0 collect ..." >&2
    exit 1
    ;;
esac

# The executable path is retained as a Phase 4 compatibility surface. Its
# verify operation delegates regeneration to validation/formal's phase-neutral
# source-set registry, and collect is already task-schema neutral.
exec moon -C "$repo_dir" run --target native cmd/phase4-formal -- "$@"

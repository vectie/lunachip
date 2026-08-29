#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

forbidden='vectie/(lunanexa|lunaflux|moongate)|moon(suite|gate|claw|desk|town)'

if rg -n \
  --glob '!.mooncakes/**' \
  --glob '!_build/**' \
  --glob '*.mbt' \
  --glob 'moon.pkg' \
  --glob 'moon.mod' \
  "$forbidden" .; then
  echo "forbidden product dependency found" >&2
  exit 1
fi

oversized=$(
  find . \
    -path './_build' -prune -o \
    -path './.mooncakes' -prune -o \
    -path './.git' -prune -o \
    -name '*.mbt' -type f -print |
  while IFS= read -r source_file; do
    line_count=$(wc -l < "$source_file")
    if [ "$line_count" -gt 800 ]; then
      echo "$source_file:$line_count"
    fi
  done
)

if [ -n "$oversized" ]; then
  echo "$oversized" >&2
  echo "MoonBit source exceeds the 800-line architecture review threshold" >&2
  exit 1
fi

echo "LunaChip dependency and source-size boundaries pass"

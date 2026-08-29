#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
artifact_directory="$repository_root/_build/benchmarks"
interposer="$artifact_directory/lunachip-allocation-interposer.dylib"
profile_executable="$artifact_directory/sim-bench-profile.exe"
moon_binary=${MOON_BIN:-moon}
moon_executable=$(command -v "$moon_binary")
moon_home=$(CDPATH= cd -- "$(dirname -- "$moon_executable")/.." && pwd)
release_build="$repository_root/_build/native/release/build"
benchmark_build="$release_build/cmd/sim-bench"

mkdir -p "$artifact_directory"
"$moon_executable" build --target native --release cmd/sim-bench
xcrun --sdk macosx clang \
  -std=c11 -O2 -Wall -Wextra -Werror -dynamiclib \
  "$repository_root/benchmarks/allocation_probe/interposer.c" \
  -o "$interposer"

runtime_archive=
runtime_archive_count=0
for candidate in "$release_build"/libruntime-*.a; do
  if [ -f "$candidate" ]; then
    runtime_archive=$candidate
    runtime_archive_count=$((runtime_archive_count + 1))
  fi
done
if [ "$runtime_archive_count" -ne 1 ]; then
  echo "Expected one MoonBit runtime archive under $release_build; found $runtime_archive_count" >&2
  exit 1
fi

xcrun --sdk macosx clang \
  -I "$moon_home/include" -fwrapv -fno-strict-aliasing \
  -Wno-unused-value -O2 \
  "$benchmark_build/sim-bench.c" \
  "$benchmark_build/libsim-bench.a" \
  "$runtime_archive" \
  -lm "$moon_home/lib/libbacktrace.a" \
  -o "$profile_executable"

DYLD_INSERT_LIBRARIES="$interposer" \
  "$profile_executable"

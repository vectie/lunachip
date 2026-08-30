#!/bin/sh
# Phase-neutral helpers for immutable repository snapshots and artifact manifests.
# Source this file; functions return nonzero instead of exiting the caller.

lc_manifest_error() {
  printf '%s\n' "evidence-manifest: $*" >&2
  return 1
}

lc_manifest_sha256_file() {
  [ "$#" -eq 1 ] || {
    lc_manifest_error "sha256_file requires one path"
    return 1
  }
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    lc_manifest_error "shasum or sha256sum is required"
    return 1
  fi
}

lc_evidence_sha256_file() {
  lc_manifest_sha256_file "$@"
}

lc_manifest_hex() {
  LC_ALL=C od -An -tx1 | tr -d ' \n'
}

lc_manifest_validate_link_target_hex() {
  [ "$#" -eq 1 ] || return 1
  lcmvlth_target=$1
  [ -n "$lcmvlth_target" ] &&
    [ $(( ${#lcmvlth_target} % 2 )) -eq 0 ] &&
    printf '%s\n' "$lcmvlth_target" | grep -Eq '^[0-9a-f]+$' || return 1
  case "$lcmvlth_target" in
    2f*|*2f2f*|2e2e|2e2e2f*|*2f2e2e|*2f2e2e2f*) return 1 ;;
  esac
  if printf '%s\n' "$lcmvlth_target" | grep -Eq \
    '^([0-9a-f][0-9a-f])*(0[0-9a-f]|1[0-9a-f]|7f)'; then
    return 1
  fi
}

lc_manifest_canonical_dir() {
  [ "$#" -eq 1 ] || {
    lc_manifest_error "canonical_dir requires one path"
    return 1
  }
  [ -d "$1" ] && [ ! -L "$1" ] || {
    lc_manifest_error "directory is absent or symbolic: $1"
    return 1
  }
  (CDPATH= cd -- "$1" && pwd -P)
}

lc_manifest_destination() {
  [ "$#" -eq 1 ] || {
    lc_manifest_error "destination requires one path"
    return 1
  }
  lcemd_parent=$(dirname -- "$1") || return 1
  lcemd_name=$(basename -- "$1") || return 1
  [ -n "$lcemd_name" ] && [ "$lcemd_name" != . ] &&
    [ "$lcemd_name" != .. ] || {
    lc_manifest_error "unsafe destination: $1"
    return 1
  }
  lcemd_parent=$(lc_manifest_canonical_dir "$lcemd_parent") || return 1
  printf '%s/%s\n' "$lcemd_parent" "$lcemd_name"
}

lc_evidence_validate_manifest() {
  [ "$#" -eq 2 ] || {
    lc_manifest_error "validate_manifest requires MANIFEST KIND"
    return 1
  }
  lcevm_manifest=$1
  lcevm_kind=$2
  case "$lcevm_kind" in repository|artifacts) ;; *)
    lc_manifest_error "invalid manifest kind: $lcevm_kind"
    return 1 ;;
  esac
  [ -f "$lcevm_manifest" ] && [ ! -L "$lcevm_manifest" ] || {
    lc_manifest_error "manifest is absent or symbolic: $lcevm_manifest"
    return 1
  }
  LC_ALL=C awk -v kind="$lcevm_kind" '
    BEGIN { failed = 0; files = 0; links = 0; ends = 0; previous = "" }
    NR == 1 && $0 != "LUNACHIP-EVIDENCE-FILE-MANIFEST 2" { failed = 1 }
    NR == 2 && $0 != "KIND " kind { failed = 1 }
    NR > 2 {
      if ($1 == "FILE") {
        files += 1
        if (NF != 3 || $2 !~ /^[0-9a-f]+$/ || length($2) != 64 ||
            $3 !~ /^[0-9a-f]+$/ || length($3) % 2 != 0 || seen[$3]++) {
          failed = 1
        }
        path = $3
      } else if ($1 == "LINK") {
        links += 1
        if (kind != "repository" || NF != 3 ||
            $2 !~ /^[0-9a-f]+$/ || length($2) % 2 != 0 ||
            $3 !~ /^[0-9a-f]+$/ || length($3) % 2 != 0 || seen[$2]++) {
          failed = 1
        }
        path = $2
        target = $3
        if (target ~ /^2f/ || target ~ /2f2f/ || target == "2e2e" ||
            target ~ /^2e2e2f/ || target ~ /2f2e2e$/ ||
            target ~ /2f2e2e2f/ ||
            target ~ /^([0-9a-f][0-9a-f])*(0[0-9a-f]|1[0-9a-f]|7f)/) {
          failed = 1
        }
      } else if ($1 == "END") {
        ends += 1
        if (NF != 1) failed = 1
      } else {
        failed = 1
      }
      if ($1 == "FILE" || $1 == "LINK") {
        if (path ~ /^2f/ || path ~ /2f$/ || path ~ /2f2f/ ||
            path == "2e" || path == "2e2e" || path ~ /^2e2f/ ||
            path ~ /^2e2e2f/ || path ~ /2f2e$/ || path ~ /2f2e2e$/ ||
            path ~ /2f2e2f/ || path ~ /2f2e2e2f/ ||
            path ~ /^([0-9a-f][0-9a-f])*(0[0-9a-f]|1[0-9a-f]|7f)/) {
          failed = 1
        }
        if (previous != "" && ("x" previous) >= ("x" path)) failed = 1
        previous = path
      }
    }
    { last = $0 }
    END {
      if (NR < 3 || ends != 1 || last != "END") failed = 1
      exit(failed ? 1 : 0)
    }
  ' "$lcevm_manifest" || {
    lc_manifest_error "manifest grammar validation failed: $lcevm_manifest"
    return 1
  }
}

lc_manifest_tree_paths() {
  [ "$#" -eq 3 ] || {
    lc_manifest_error "tree_paths requires ROOT MODE OUTPUT"
    return 1
  }
  lcemtp_root=$1
  lcemtp_mode=$2
  lcemtp_output=$3
  case "$lcemtp_mode" in repository|artifacts) ;; *)
    lc_manifest_error "invalid tree mode: $lcemtp_mode"
    return 1 ;;
  esac
  if [ "$lcemtp_mode" = repository ]; then
    lcemtp_special=$(
      cd "$lcemtp_root" &&
        find . -path './.git' -prune -o -path './_build' -prune -o \
          \( -type d -o -type f -o -type l \) -o -print
    ) || return 1
  else
    lcemtp_special=$(
      cd "$lcemtp_root" && find . \( -type d -o -type f \) -o -print
    ) || return 1
  fi
  [ -z "$lcemtp_special" ] || {
    lc_manifest_error "tree contains a symbolic or special path: $lcemtp_special"
    return 1
  }
  if [ "$lcemtp_mode" = repository ]; then
    (
      cd "$lcemtp_root"
      find . -path './.git' -prune -o -path './_build' -prune -o \
        \( -type f -o -type l \) -print | LC_ALL=C sort
    ) >"$lcemtp_output"
  else
    (cd "$lcemtp_root" && find . -type f -print | LC_ALL=C sort) \
      >"$lcemtp_output"
  fi
}

lc_evidence_write_manifest() {
  [ "$#" -eq 3 ] || {
    lc_manifest_error "write_manifest requires ROOT DESTINATION KIND"
    return 1
  }
  lcewm_root=$(lc_manifest_canonical_dir "$1") || return 1
  lcewm_destination=$(lc_manifest_destination "$2") || return 1
  lcewm_kind=$3
  case "$lcewm_kind" in repository|artifacts) ;; *)
    lc_manifest_error "invalid manifest kind: $lcewm_kind"
    return 1 ;;
  esac
  case "$lcewm_destination" in "$lcewm_root"|"$lcewm_root"/*)
    lc_manifest_error "manifest destination must be outside its input tree"
    return 1 ;;
  esac
  [ ! -e "$lcewm_destination" ] && [ ! -L "$lcewm_destination" ] || {
    lc_manifest_error "refusing to overwrite manifest: $lcewm_destination"
    return 1
  }
  lcewm_parent=$(dirname -- "$lcewm_destination")
  lcewm_name=$(basename -- "$lcewm_destination")
  lcewm_paths=$(mktemp "$lcewm_parent/.$lcewm_name.paths.XXXXXX") || return 1
  lcewm_temp=$(mktemp "$lcewm_parent/.$lcewm_name.write.XXXXXX") || {
    rm -f "$lcewm_paths"
    return 1
  }
  if lc_manifest_tree_paths "$lcewm_root" "$lcewm_kind" "$lcewm_paths"; then
    :
  else
    lcewm_status=$?
    rm -f "$lcewm_paths" "$lcewm_temp"
    return "$lcewm_status"
  fi
  (
    printf '%s\n' 'LUNACHIP-EVIDENCE-FILE-MANIFEST 2' "KIND $lcewm_kind"
    while IFS= read -r lcewm_found; do
      lcewm_relative=${lcewm_found#./}
      [ -n "$lcewm_relative" ] && [ "$lcewm_relative" != "$lcewm_found" ] || {
        lc_manifest_error "unsafe discovered path: $lcewm_found"
        exit 1
      }
      lcewm_hex=$(printf '%s' "$lcewm_relative" | lc_manifest_hex) || exit 1
      lcewm_path="$lcewm_root/$lcewm_relative"
      if [ -L "$lcewm_path" ]; then
        [ "$lcewm_kind" = repository ] || {
          lc_manifest_error "artifact tree contains link: $lcewm_relative"
          exit 1
        }
        command -v readlink >/dev/null 2>&1 &&
          command -v realpath >/dev/null 2>&1 || {
          lc_manifest_error "readlink and realpath are required for repository links"
          exit 1
        }
        lcewm_target_hex=$(readlink "$lcewm_path" | lc_manifest_hex) || exit 1
        case "$lcewm_target_hex" in
          *0a) lcewm_target_hex=${lcewm_target_hex%0a} ;;
          *)
            lc_manifest_error "readlink did not terminate its output"
            exit 1
            ;;
        esac
        lc_manifest_validate_link_target_hex "$lcewm_target_hex" || {
          lc_manifest_error "unsafe repository link target: $lcewm_relative"
          exit 1
        }
        lcewm_resolved=$(realpath "$lcewm_path") || {
          lc_manifest_error "dangling repository link: $lcewm_relative"
          exit 1
        }
        case "$lcewm_resolved" in
          "$lcewm_root"/*) ;;
          *)
            lc_manifest_error "repository link resolves outside root: $lcewm_relative"
            exit 1
            ;;
        esac
        [ -f "$lcewm_resolved" ] && [ ! -L "$lcewm_resolved" ] || {
          lc_manifest_error "repository link does not resolve to a regular file: $lcewm_relative"
          exit 1
        }
        lcewm_resolved_relative=${lcewm_resolved#"$lcewm_root/"}
        grep -Fx "./$lcewm_resolved_relative" "$lcewm_paths" >/dev/null || {
          lc_manifest_error "repository link target is not separately manifested: $lcewm_relative"
          exit 1
        }
        printf 'LINK %s %s\n' "$lcewm_hex" "$lcewm_target_hex"
      elif [ -f "$lcewm_path" ]; then
        lcewm_digest=$(lc_manifest_sha256_file "$lcewm_path") || exit 1
        printf 'FILE %s %s\n' "$lcewm_digest" "$lcewm_hex"
      else
        lc_manifest_error \
          "file changed type during manifest creation: $lcewm_relative"
        exit 1
      fi
    done <"$lcewm_paths"
    printf '%s\n' END
  ) >"$lcewm_temp" || {
    lcewm_status=$?
    rm -f "$lcewm_paths" "$lcewm_temp"
    return "$lcewm_status"
  }
  rm -f "$lcewm_paths"
  if lc_evidence_validate_manifest "$lcewm_temp" "$lcewm_kind" &&
    ln "$lcewm_temp" "$lcewm_destination"; then
    rm "$lcewm_temp"
  else
    lcewm_status=$?
    rm -f "$lcewm_temp"
    return "$lcewm_status"
  fi
}

lc_evidence_verify_manifest() {
  [ "$#" -eq 3 ] || {
    lc_manifest_error "verify_manifest requires ROOT MANIFEST KIND"
    return 1
  }
  lcevf_root=$(lc_manifest_canonical_dir "$1") || return 1
  lcevf_manifest=$(lc_manifest_destination "$2") || return 1
  lcevf_kind=$3
  case "$lcevf_manifest" in "$lcevf_root"|"$lcevf_root"/*)
    lc_manifest_error "manifest must be outside its input tree"
    return 1 ;;
  esac
  lc_evidence_validate_manifest "$lcevf_manifest" "$lcevf_kind" || return 1
  lcevf_parent=$(dirname -- "$lcevf_manifest")
  lcevf_name=$(basename -- "$lcevf_manifest")
  lcevf_verification=$(mktemp \
    "$lcevf_parent/.$lcevf_name.verify.XXXXXX") || return 1
  rm "$lcevf_verification"
  if lc_evidence_write_manifest \
    "$lcevf_root" "$lcevf_verification" "$lcevf_kind"; then
    if cmp -s "$lcevf_manifest" "$lcevf_verification"; then
      lcevf_status=0
    else
      lc_manifest_error "manifest does not exactly match tree: $lcevf_manifest"
      lcevf_status=1
    fi
  else
    lcevf_status=$?
  fi
  rm -f "$lcevf_verification"
  return "$lcevf_status"
}

lc_evidence_snapshot_repository() {
  [ "$#" -eq 2 ] || {
    lc_manifest_error "snapshot_repository requires REPOSITORY DESTINATION"
    return 1
  }
  lc_evidence_write_manifest "$1" "$2" repository || return 1
  lc_evidence_verify_manifest "$1" "$2" repository
}

lc_evidence_create_artifact_manifest() {
  [ "$#" -eq 2 ] || {
    lc_manifest_error "create_artifact_manifest requires ROOT DESTINATION"
    return 1
  }
  lc_evidence_write_manifest "$1" "$2" artifacts || return 1
  lc_evidence_verify_manifest "$1" "$2" artifacts
}

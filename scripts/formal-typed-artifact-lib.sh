#!/bin/sh
# Strict verification for typed Phase-4 formal result/receipt artifacts.
# Source after evidence-manifest-lib.sh. Functions return nonzero and never
# exit the caller.

lc_formal_typed_error() {
  printf '%s\n' "formal-typed-artifact: $*" >&2
  return 1
}

lc_formal_receipt_line() {
  [ "$#" -eq 2 ] || {
    lc_formal_typed_error "receipt_line requires RECEIPT KEYWORD"
    return 1
  }
  lcfrl_receipt=$1
  lcfrl_keyword=$2
  [ "$(grep -Ec "^$lcfrl_keyword " "$lcfrl_receipt")" -eq 1 ] || {
    lc_formal_typed_error "$lcfrl_keyword record count"
    return 1
  }
  grep -E "^$lcfrl_keyword " "$lcfrl_receipt"
}

lc_formal_verify_receipt_artifact() {
  [ "$#" -eq 4 ] || {
    lc_formal_typed_error \
      "verify_receipt_artifact requires RECEIPT KEYWORD NAME FILE"
    return 1
  }
  lcfvra_receipt=$1
  lcfvra_keyword=$2
  lcfvra_expected_name=$3
  lcfvra_artifact=$4
  [ -f "$lcfvra_artifact" ] && [ ! -L "$lcfvra_artifact" ] || {
    lc_formal_typed_error "$lcfvra_keyword artifact is absent or symbolic"
    return 1
  }
  lcfvra_line=$(lc_formal_receipt_line \
    "$lcfvra_receipt" "$lcfvra_keyword") || return 1
  set -- $lcfvra_line
  [ "$#" -eq 4 ] && [ "$1" = "$lcfvra_keyword" ] &&
    [ "$2" = "$lcfvra_expected_name" ] && [ "$3" = sha256 ] || {
    lc_formal_typed_error "$lcfvra_keyword record shape"
    return 1
  }
  printf '%s\n' "$4" | grep -Eq '^[0-9a-f]{64}$' || {
    lc_formal_typed_error "$lcfvra_keyword digest shape"
    return 1
  }
  [ "$(lc_evidence_sha256_file "$lcfvra_artifact")" = "$4" ] || {
    lc_formal_typed_error "$lcfvra_keyword digest mismatch"
    return 1
  }
}

lc_formal_verify_outputs_manifest() {
  [ "$#" -eq 1 ] || {
    lc_formal_typed_error "verify_outputs_manifest requires OUTPUT"
    return 1
  }
  lcfvom_output=$1
  lcfvom_manifest="$lcfvom_output/outputs.sha256"
  [ -d "$lcfvom_output" ] && [ ! -L "$lcfvom_output" ] || {
    lc_formal_typed_error "output root is absent, non-directory, or symbolic"
    return 1
  }
  lcfvom_unexpected=$(find "$lcfvom_output" -mindepth 1 \
    ! -type d ! -type f -print)
  [ -z "$lcfvom_unexpected" ] || {
    lc_formal_typed_error \
      "output contains a non-directory, non-regular entry"
    return 1
  }
  [ -f "$lcfvom_manifest" ] && [ ! -L "$lcfvom_manifest" ] || {
    lc_formal_typed_error "outputs.sha256 is absent or symbolic"
    return 1
  }
  lcfvom_count=0
  lcfvom_previous=
  while IFS= read -r lcfvom_line; do
    lcfvom_digest=${lcfvom_line%%  *}
    lcfvom_relative=${lcfvom_line#*  }
    [ "$lcfvom_relative" != "$lcfvom_line" ] &&
      printf '%s\n' "$lcfvom_digest" | grep -Eq '^[0-9a-f]{64}$' || {
      lc_formal_typed_error "invalid outputs.sha256 record"
      return 1
    }
    case "$lcfvom_relative" in
      ''|/*|.|..|../*|*/../*|*/..|*//* )
        lc_formal_typed_error "unsafe outputs.sha256 path"
        return 1
        ;;
    esac
    if [ -n "$lcfvom_previous" ] &&
      ! LC_ALL=C awk \
        -v previous="$lcfvom_previous" -v current="$lcfvom_relative" \
        'BEGIN { exit(("x" previous) < ("x" current) ? 0 : 1) }'; then
      lc_formal_typed_error "outputs.sha256 paths are not strictly sorted"
      return 1
    fi
    lcfvom_artifact="$lcfvom_output/$lcfvom_relative"
    [ -f "$lcfvom_artifact" ] && [ ! -L "$lcfvom_artifact" ] || {
      lc_formal_typed_error "outputs.sha256 artifact is absent or symbolic"
      return 1
    }
    [ "$(lc_evidence_sha256_file "$lcfvom_artifact")" = \
      "$lcfvom_digest" ] || {
      lc_formal_typed_error "outputs.sha256 artifact digest mismatch"
      return 1
    }
    lcfvom_previous=$lcfvom_relative
    lcfvom_count=$((lcfvom_count + 1))
  done <"$lcfvom_manifest"
  [ "$lcfvom_count" -gt 0 ] || {
    lc_formal_typed_error "outputs.sha256 is empty"
    return 1
  }
  lcfvom_inventory=$(mktemp -d \
    "${TMPDIR:-/tmp}/lunachip-formal-output-inventory.XXXXXX") || return 1
  (
    cd "$lcfvom_output"
    find . -type f ! -path './outputs.sha256' ! -path './result.lcfr' \
      ! -path './receipt.lcfe' -print | sed 's|^\./||' | LC_ALL=C sort
  ) >"$lcfvom_inventory/actual"
  awk '{ print $2 }' "$lcfvom_manifest" >"$lcfvom_inventory/declared"
  if ! cmp -s "$lcfvom_inventory/actual" "$lcfvom_inventory/declared"; then
    rm -rf "$lcfvom_inventory"
    lc_formal_typed_error "outputs.sha256 does not cover every output artifact"
    return 1
  fi
  rm -rf "$lcfvom_inventory"
}

lc_formal_verify_typed_artifacts() {
  [ "$#" -eq 4 ] || {
    lc_formal_typed_error \
      "verify_typed_artifacts requires ARTIFACT_CLI BUNDLE TASK OUTPUT"
    return 1
  }
  lcfvta_cli=$1
  lcfvta_bundle=$2
  lcfvta_task=$3
  lcfvta_output=$4
  lcfvta_result="$lcfvta_output/result.lcfr"
  lcfvta_receipt="$lcfvta_output/receipt.lcfe"
  [ -f "$lcfvta_cli" ] && [ ! -L "$lcfvta_cli" ] &&
    [ -x "$lcfvta_cli" ] || {
    lc_formal_typed_error "formal artifact CLI is absent, symbolic, or not executable"
    return 1
  }
  [ -f "$lcfvta_result" ] && [ ! -L "$lcfvta_result" ] &&
    [ -f "$lcfvta_receipt" ] && [ ! -L "$lcfvta_receipt" ] || {
    lc_formal_typed_error "typed result or receipt is absent or symbolic"
    return 1
  }
  [ "$(wc -l <"$lcfvta_receipt" | tr -d ' ')" -eq 10 ] || {
    lc_formal_typed_error "receipt line count"
    return 1
  }
  [ "$(sed -n '1p' "$lcfvta_receipt")" = \
    'LUNACHIP-PHASE4-FORMAL-RECEIPT 1' ] || {
    lc_formal_typed_error "receipt header"
    return 1
  }
  [ "$(tail -n 1 "$lcfvta_receipt")" = END ] || {
    lc_formal_typed_error "receipt END"
    return 1
  }
  [ "$(lc_formal_receipt_line "$lcfvta_receipt" RUNNER-EXIT)" = \
    'RUNNER-EXIT 0' ] || {
    lc_formal_typed_error "runner exit binding"
    return 1
  }

  lcfvta_execution=$(lc_formal_receipt_line \
    "$lcfvta_receipt" EXECUTION-MANIFEST) || return 1
  set -- $lcfvta_execution
  [ "$#" -eq 3 ] && [ "$1" = EXECUTION-MANIFEST ] &&
    [ "$2" = sha256 ] || {
    lc_formal_typed_error "execution binding shape"
    return 1
  }
  [ "$(lc_evidence_sha256_file "$lcfvta_bundle/$lcfvta_task.lcfg")" = \
    "$3" ] || {
    lc_formal_typed_error "execution manifest digest mismatch"
    return 1
  }

  lcfvta_result_line=$(lc_formal_receipt_line \
    "$lcfvta_receipt" RESULT) || return 1
  set -- $lcfvta_result_line
  [ "$#" -eq 3 ] && [ "$1" = RESULT ] && [ "$2" = sha256 ] || {
    lc_formal_typed_error "result binding shape"
    return 1
  }
  [ "$(lc_evidence_sha256_file "$lcfvta_result")" = "$3" ] || {
    lc_formal_typed_error "result digest mismatch"
    return 1
  }
  "$lcfvta_cli" verify-result \
    "$lcfvta_bundle" "$lcfvta_task" "$lcfvta_result" >/dev/null || {
    lc_formal_typed_error "result canonical grammar or task binding mismatch"
    return 1
  }

  lc_formal_verify_receipt_artifact "$lcfvta_receipt" STATUS sby/status \
    "$lcfvta_output/$lcfvta_task-work/status" || return 1
  lc_formal_verify_receipt_artifact "$lcfvta_receipt" TOOL-VERSIONS \
    tool-versions.txt "$lcfvta_output/tool-versions.txt" || return 1
  lc_formal_verify_receipt_artifact "$lcfvta_receipt" OUTPUT-DIGESTS \
    outputs.sha256 "$lcfvta_output/outputs.sha256" || return 1
  lc_formal_verify_receipt_artifact "$lcfvta_receipt" PROVENANCE \
    provenance.txt "$lcfvta_output/provenance.txt" || return 1
  lc_formal_verify_outputs_manifest "$lcfvta_output" || return 1
  if [ "$lcfvta_task" = valid-async-fifo-bmc ]; then
    command -v lc_async_fifo_verify_internal_shards >/dev/null 2>&1 || {
      lc_formal_typed_error "async-FIFO shard verifier is unavailable"
      return 1
    }
    lc_async_fifo_verify_internal_shards \
      "$lcfvta_bundle" "$lcfvta_task" "$lcfvta_output" || {
      lc_formal_typed_error "async-FIFO shard evidence mismatch"
      return 1
    }
  fi

  lcfvta_evidence=$(lc_formal_receipt_line \
    "$lcfvta_receipt" EVIDENCE) || return 1
  set -- $lcfvta_evidence
  lcfvta_result_artifacts=$(grep -Ec \
    '^(COUNTEREXAMPLE|WITNESS) artifact ' "$lcfvta_result")
  if [ "$#" -eq 2 ] && [ "$1" = EVIDENCE ] && [ "$2" = none ]; then
    [ "$lcfvta_result_artifacts" -eq 0 ] || {
      lc_formal_typed_error "result artifact lacks receipt binding"
      return 1
    }
  else
    [ "$#" -eq 4 ] && [ "$1" = EVIDENCE ] && [ "$3" = sha256 ] || {
      lc_formal_typed_error "evidence binding shape"
      return 1
    }
    lcfvta_evidence_name=$2
    case "$lcfvta_evidence_name" in
      ''|/*|.|..|../*|*/../*|*/..|*//* )
        lc_formal_typed_error "unsafe evidence path"
        return 1
        ;;
    esac
    lcfvta_evidence_file="$lcfvta_output/$lcfvta_task-work/$lcfvta_evidence_name"
    [ -f "$lcfvta_evidence_file" ] && [ ! -L "$lcfvta_evidence_file" ] || {
      lc_formal_typed_error "evidence artifact is absent or symbolic"
      return 1
    }
    [ "$(lc_evidence_sha256_file "$lcfvta_evidence_file")" = "$4" ] || {
      lc_formal_typed_error "evidence digest mismatch"
      return 1
    }
    [ "$lcfvta_result_artifacts" -eq 1 ] || {
      lc_formal_typed_error "result artifact count"
      return 1
    }
    lcfvta_result_digest=$(awk \
      '($1 == "COUNTEREXAMPLE" || $1 == "WITNESS") && $2 == "artifact" { print $5 }' \
      "$lcfvta_result")
    [ "$lcfvta_result_digest" = "$4" ] || {
      lc_formal_typed_error "result and receipt evidence digests differ"
      return 1
    }
  fi
}

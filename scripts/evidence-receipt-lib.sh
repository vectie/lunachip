#!/bin/sh
# Phase-neutral helpers for immutable LunaChip evidence. Source this file;
# functions return nonzero instead of exiting. Receipt fields use one real
# ASCII space; callers must encode values that need arbitrary bytes.

lc_evidence_error() {
  printf '%s\n' "evidence-receipt: $*" >&2
  return 1
}
lc_evidence_canonical_dir() {
  [ "$#" -eq 1 ] || {
    lc_evidence_error "canonical_dir requires one path"
    return 1
  }
  [ -d "$1" ] && [ ! -L "$1" ] || {
    lc_evidence_error "directory is absent or symbolic: $1"
    return 1
  }
  (CDPATH= cd -- "$1" && pwd -P)
}
lc_evidence_destination() {
  [ "$#" -eq 1 ] || {
    lc_evidence_error "destination requires one path"
    return 1
  }
  lced_parent=$(dirname -- "$1") || return 1
  lced_name=$(basename -- "$1") || return 1
  [ -n "$lced_name" ] && [ "$lced_name" != . ] &&
    [ "$lced_name" != .. ] || {
    lc_evidence_error "unsafe destination: $1"
    return 1
  }
  lced_parent=$(lc_evidence_canonical_dir "$lced_parent") || return 1
  printf '%s/%s\n' "$lced_parent" "$lced_name"
}
lc_evidence_token() {
  [ "$#" -eq 1 ] || return 1
  [ -n "$1" ] || return 1
  printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._:/=@,+-]*$'
}
lc_evidence_header() {
  [ "$#" -eq 1 ] || return 1
  printf '%s\n' "$1" | LC_ALL=C grep -Eq '^LUNACHIP-[A-Z0-9-]+-EVIDENCE [1-9][0-9]*$'
}
lc_evidence_record_list() {
  [ "$#" -eq 1 ] || return 1
  printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[A-Z][A-Z0-9_]*(,[A-Z][A-Z0-9_]*)*$'
}
lc_evidence_receipt_begin() {
  [ "$#" -eq 2 ] || {
    lc_evidence_error "receipt_begin requires RECEIPT HEADER"
    return 1
  }
  lcerb_receipt=$(lc_evidence_destination "$1") || return 1
  lcerb_header=$2
  lc_evidence_header "$lcerb_header" || {
    lc_evidence_error "invalid evidence header: $lcerb_header"
    return 1
  }
  [ ! -e "$lcerb_receipt" ] && [ ! -L "$lcerb_receipt" ] || {
    lc_evidence_error "refusing to overwrite receipt: $lcerb_receipt"
    return 1
  }
  lcerb_parent=$(dirname -- "$lcerb_receipt")
  lcerb_name=$(basename -- "$lcerb_receipt")
  lcerb_temp=$(mktemp "$lcerb_parent/.$lcerb_name.begin.XXXXXX") || return 1
  if printf '%s\n' "$lcerb_header" 'STATE incomplete' >"$lcerb_temp" &&
    ln "$lcerb_temp" "$lcerb_receipt"; then
    rm "$lcerb_temp"
  else
    lcerb_status=$?
    rm -f "$lcerb_temp"
    return "$lcerb_status"
  fi
}
lc_evidence_receipt_record() {
  [ "$#" -ge 2 ] || {
    lc_evidence_error "receipt_record requires RECEIPT RECORD [FIELD ...]"
    return 1
  }
  lcerr_receipt=$1
  shift
  [ -f "$lcerr_receipt" ] && [ ! -L "$lcerr_receipt" ] || {
    lc_evidence_error "receipt is absent or symbolic: $lcerr_receipt"
    return 1
  }
  [ "$(tail -n 1 "$lcerr_receipt")" != END ] || {
    lc_evidence_error "receipt is already sealed: $lcerr_receipt"
    return 1
  }
  for lcerr_field in "$@"; do
    lc_evidence_token "$lcerr_field" || {
      lc_evidence_error "invalid receipt token: $lcerr_field"
      return 1
    }
  done
  lcerr_old_ifs=$IFS
  IFS=' '
  printf '%s\n' "$*" >>"$lcerr_receipt"
  IFS=$lcerr_old_ifs
}
lc_evidence_run_logged() {
  [ "$#" -ge 4 ] || {
    lc_evidence_error "run_logged requires RECEIPT LOG LABEL COMMAND [ARG ...]"
    return 1
  }
  lcerl_receipt=$1
  lcerl_log=$2
  lcerl_label=$3
  shift 3
  lc_evidence_token "$lcerl_label" || {
    lc_evidence_error "invalid command label: $lcerl_label"
    return 1
  }
  [ ! -e "$lcerl_log" ] && [ ! -L "$lcerl_log" ] || {
    lc_evidence_error "refusing to overwrite command log: $lcerl_log"
    return 1
  }
  lcerl_log_parent=$(dirname -- "$lcerl_log")
  lc_evidence_canonical_dir "$lcerl_log_parent" >/dev/null || return 1
  if "$@" >"$lcerl_log" 2>&1; then
    lcerl_status=0
  else
    lcerl_status=$?
  fi
  lc_evidence_receipt_record \
    "$lcerl_receipt" COMMAND "$lcerl_label" "status=$lcerl_status" || return 1
  return "$lcerl_status"
}
lc_evidence_validate_receipt() {
  [ "$#" -eq 5 ] || {
    lc_evidence_error \
      "validate_receipt requires RECEIPT HEADER STATE ALLOWED REQUIRED"
    return 1
  }
  lcevr_receipt=$1
  lcevr_header=$2
  lcevr_state=$3
  lcevr_allowed=$4
  lcevr_required=$5
  lc_evidence_header "$lcevr_header" || {
    lc_evidence_error "invalid expected header"
    return 1
  }
  case "$lcevr_state" in pass|incomplete) ;; *)
    lc_evidence_error "invalid expected state: $lcevr_state"
    return 1 ;;
  esac
  lc_evidence_record_list "$lcevr_allowed" &&
    lc_evidence_record_list "$lcevr_required" || {
    lc_evidence_error "invalid allowed or required record list"
    return 1
  }
  [ -f "$lcevr_receipt" ] && [ ! -L "$lcevr_receipt" ] || {
    lc_evidence_error "receipt is absent or symbolic: $lcevr_receipt"
    return 1
  }
  LC_ALL=C awk -v header="$lcevr_header" -v state="$lcevr_state" \
    -v allowed="$lcevr_allowed" -v required="$lcevr_required" '
    BEGIN {
      states = 0; ends = 0; commands = 0; failed = 0
      count = split(allowed, records, ",")
      for (i = 1; i <= count; i++) {
        if (records[i] == "STATE" || records[i] == "END" ||
            allowed_record[records[i]]++) failed = 1
      }
      count = split(required, records, ",")
      for (i = 1; i <= count; i++) {
        if (!allowed_record[records[i]] || required_record[records[i]]++) failed = 1
      }
    }
    NR == 1 && $0 != header { failed = 1 }
    NR == 2 && $0 != "STATE " state { failed = 1 }
    {
      if ($0 == "" || $0 ~ /[[:cntrl:]]/ || $0 ~ /^ / ||
          $0 ~ / $/ || $0 ~ /  / || index($0, "\\") != 0) {
        failed = 1
      }
      if ($1 == "STATE") {
        states += 1
        if (NF != 2 || ($2 != "pass" && $2 != "incomplete")) failed = 1
      }
      if ($1 == "COMMAND") {
        commands += 1
        if (NF != 3 || $2 !~ /^[A-Za-z0-9][A-Za-z0-9._:+,@=\/-]*$/ ||
            $3 !~ /^status=[0-9]+$/ || seen_command[$2]++) failed = 1
      }
      if ($1 == "END") {
        ends += 1
        if (NF != 1) failed = 1
      } else if (NR > 2) {
        if (!allowed_record[$1]) failed = 1
        seen_record[$1] += 1
      }
      last = $0
    }
    END {
      for (record in required_record) {
        if (!seen_record[record]) failed = 1
      }
      if (NR < 3 || states != 1 || ends != 1 || last != "END") failed = 1
      exit(failed ? 1 : 0)
    }
  ' "$lcevr_receipt" || {
    lc_evidence_error "receipt grammar validation failed: $lcevr_receipt"
    return 1
  }
}
lc_evidence_receipt_seal() {
  [ "$#" -eq 4 ] || {
    lc_evidence_error "receipt_seal requires RECEIPT HEADER ALLOWED REQUIRED"
    return 1
  }
  lcers_receipt=$(lc_evidence_destination "$1") || return 1
  lcers_header=$2
  lcers_allowed=$3
  lcers_required=$4
  [ -f "$lcers_receipt" ] && [ ! -L "$lcers_receipt" ] || {
    lc_evidence_error "receipt is absent or symbolic: $lcers_receipt"
    return 1
  }
  [ "$(tail -n 1 "$lcers_receipt")" != END ] || {
    lc_evidence_error "receipt is already sealed: $lcers_receipt"
    return 1
  }
  lcers_parent=$(dirname -- "$lcers_receipt")
  lcers_name=$(basename -- "$lcers_receipt")
  lcers_temp=$(mktemp "$lcers_parent/.$lcers_name.seal.XXXXXX") || return 1
  if { sed -n '1,$p' "$lcers_receipt"; printf '%s\n' END; } >"$lcers_temp" &&
    lc_evidence_validate_receipt "$lcers_temp" "$lcers_header" incomplete \
      "$lcers_allowed" "$lcers_required"; then
    mv "$lcers_temp" "$lcers_receipt"
  else
    lcers_status=$?
    rm -f "$lcers_temp"
    return "$lcers_status"
  fi
}
lc_evidence_receipt_publish_pass() {
  [ "$#" -eq 5 ] || {
    lc_evidence_error \
      "receipt_publish_pass requires INCOMPLETE FINAL HEADER ALLOWED REQUIRED"
    return 1
  }
  lcerp_incomplete=$(lc_evidence_destination "$1") || return 1
  lcerp_final=$(lc_evidence_destination "$2") || return 1
  lcerp_header=$3
  lcerp_allowed=$4
  lcerp_required=$5
  [ "$(dirname -- "$lcerp_incomplete")" = "$(dirname -- "$lcerp_final")" ] || {
    lc_evidence_error "atomic pass publication requires one directory"
    return 1
  }
  [ ! -e "$lcerp_final" ] && [ ! -L "$lcerp_final" ] || {
    lc_evidence_error "refusing to overwrite final receipt: $lcerp_final"
    return 1
  }
  lc_evidence_validate_receipt \
    "$lcerp_incomplete" "$lcerp_header" incomplete \
    "$lcerp_allowed" "$lcerp_required" || return 1
  lcerp_parent=$(dirname -- "$lcerp_final")
  lcerp_name=$(basename -- "$lcerp_final")
  lcerp_temp=$(mktemp "$lcerp_parent/.$lcerp_name.pass.XXXXXX") || return 1
  if awk 'NR == 2 { print "STATE pass"; next } { print }' \
    "$lcerp_incomplete" >"$lcerp_temp" &&
    lc_evidence_validate_receipt "$lcerp_temp" "$lcerp_header" pass \
      "$lcerp_allowed" "$lcerp_required" &&
    ln "$lcerp_temp" "$lcerp_final"; then
    rm "$lcerp_temp"
    rm "$lcerp_incomplete"
  else
    lcerp_status=$?
    rm -f "$lcerp_temp"
    return "$lcerp_status"
  fi
}

#!/bin/sh
# Offline structural verification for one pinned SymbiYosys child execution.
# This validates the retained footprint; trust in the tool execution itself is
# established separately by the locked OCI provenance and gate snapshot.

lc_async_fifo_footprint_error() {
  printf '%s\n' "async-fifo-formal-footprint: $*" >&2
  return 1
}

lc_async_fifo_require_regular_nonempty() {
  [ "$#" -eq 2 ] || return 1
  lcafrre_path=$1
  lcafrre_role=$2
  if [ ! -f "$lcafrre_path" ] || [ -L "$lcafrre_path" ] ||
    [ ! -s "$lcafrre_path" ]; then
    lc_async_fifo_footprint_error \
      "$lcafrre_role is absent, empty, non-regular, or symbolic"
    return 1
  fi
}

lc_async_fifo_require_one_suffix() {
  [ "$#" -eq 3 ] || return 1
  lcafros_file=$1
  lcafros_suffix=$2
  lcafros_role=$3
  lcafros_count=$(awk -v suffix="$lcafros_suffix" \
    'length($0) >= length(suffix) && substr($0, length($0) - length(suffix) + 1) == suffix { count += 1 } END { print count + 0 }' \
    "$lcafros_file")
  if [ "$lcafros_count" -ne 1 ]; then
    lc_async_fifo_footprint_error \
      "$lcafros_role lacks one exact terminal marker: $lcafros_suffix"
    return 1
  fi
}

lc_async_fifo_verify_child_footprint() {
  [ "$#" -eq 4 ] || {
    lc_async_fifo_footprint_error \
      "verify child footprint requires GENERATED_SBY WORK_DIR SHARD_ID BOUND"
    return 1
  }
  lcafvcf_sby=$1
  lcafvcf_work=$2
  lcafvcf_id=$3
  lcafvcf_bound=$4
  case "$lcafvcf_bound" in
    128|204) ;;
    *)
      lc_async_fifo_footprint_error \
        "$lcafvcf_id has unsupported expected bound $lcafvcf_bound"
      return 1
      ;;
  esac
  lcafvcf_last_step=$((lcafvcf_bound - 1))
  lcafvcf_config="$lcafvcf_work/config.sby"
  lcafvcf_log="$lcafvcf_work/logfile.txt"
  lcafvcf_engine="$lcafvcf_work/engine_0/logfile.txt"
  lcafvcf_model="$lcafvcf_work/model/design_smt2.smt2"
  lc_async_fifo_require_regular_nonempty \
    "$lcafvcf_config" "$lcafvcf_id config.sby" || return 1
  lc_async_fifo_require_regular_nonempty \
    "$lcafvcf_log" "$lcafvcf_id logfile.txt" || return 1
  lc_async_fifo_require_regular_nonempty \
    "$lcafvcf_engine" "$lcafvcf_id engine logfile" || return 1
  lc_async_fifo_require_regular_nonempty \
    "$lcafvcf_model" "$lcafvcf_id SMT2 model" || return 1
  if ! cmp -s "$lcafvcf_sby" "$lcafvcf_config"; then
    lc_async_fifo_footprint_error \
      "$lcafvcf_id executed config differs from generated SBY"
    return 1
  fi
  lc_async_fifo_require_one_suffix "$lcafvcf_log" \
    'summary: engine_0 (smtbmc bitwuzla) returned pass' \
    "$lcafvcf_id summary" || return 1
  lc_async_fifo_require_one_suffix "$lcafvcf_log" \
    'summary: engine_0 did not produce any traces' \
    "$lcafvcf_id trace summary" || return 1
  lc_async_fifo_require_one_suffix "$lcafvcf_log" \
    'DONE (PASS, rc=0)' "$lcafvcf_id completion" || return 1
  lc_async_fifo_require_one_suffix "$lcafvcf_engine" \
    "Checking assertions in step $lcafvcf_last_step.." \
    "$lcafvcf_id terminal depth" || return 1
  lcafvcf_observed_last_step=$(awk \
    '$0 ~ /Checking assertions in step [0-9]+[.][.]$/ { line = $0; sub(/^.*Checking assertions in step /, "", line); sub(/[.][.]$/, "", line); if (line ~ /^[0-9]+$/) last = line } END { print last }' \
    "$lcafvcf_engine")
  if [ "$lcafvcf_observed_last_step" != "$lcafvcf_last_step" ]; then
    lc_async_fifo_footprint_error \
      "$lcafvcf_id final assertion step is $lcafvcf_observed_last_step, expected $lcafvcf_last_step"
    return 1
  fi
  lc_async_fifo_require_one_suffix "$lcafvcf_engine" 'Status: passed' \
    "$lcafvcf_id engine status" || return 1
  case "$(tail -n 1 "$lcafvcf_engine")" in
    *'Status: passed') ;;
    *)
      lc_async_fifo_footprint_error \
        "$lcafvcf_id engine pass marker is not the final line"
      return 1
      ;;
  esac
  case "$(tail -n 1 "$lcafvcf_log")" in
    *'DONE (PASS, rc=0)') ;;
    *)
      lc_async_fifo_footprint_error \
        "$lcafvcf_id SBY DONE marker is not the final line"
      return 1
      ;;
  esac
}

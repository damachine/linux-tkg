#!/usr/bin/env bash

# Generate optimization profiles for the running linux-tkg kernel.
# Usage: ./optimization/generate-profile.sh autofdo|propeller|bolt [seconds]

set -Eeuo pipefail

PROFILE_DIR="${PROFILE_DIR:-${HOME}/.config/frogminer}"
VMLINUX="${VMLINUX:-/lib/modules/$(uname -r)/build/vmlinux}"
RECORD_SECONDS="${RECORD_SECONDS:-600}"
AUTOFDO_DESKTOP_SECONDS="${AUTOFDO_DESKTOP_SECONDS:-${RECORD_SECONDS}}"
PROPELLER_SECONDS="${PROPELLER_SECONDS:-${RECORD_SECONDS}}"
BOLT_SECONDS="${BOLT_SECONDS:-${RECORD_SECONDS}}"

LLVM_PROFGEN="${LLVM_PROFGEN:-llvm-profgen}"
LLVM_PROFDATA="${LLVM_PROFDATA:-llvm-profdata}"
PROPELLER_PROFILER="${PROPELLER_PROFILER:-${CREATE_LLVM_PROF:-}}"
PERF2BOLT="${PERF2BOLT:-perf2bolt}"
LLVM_BOLT="${LLVM_BOLT:-llvm-bolt}"

work_dir=""
old_kptr=""
old_paranoid=""
sysctls_changed=false
propeller_profiler_kind=""
bolt_perf_data=""
bolt_preserve_data=false
converter_pgid=""

_msg() {
  printf '==> %s\n' "$*"
}

_die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

_usage() {
  cat <<EOF
Usage: $0 autofdo|propeller|bolt [seconds]

autofdo   Create ${PROFILE_DIR}/tkg.afdo
propeller Create ${PROFILE_DIR}/tkg-propeller_{cc,ld}_profile.txt
bolt      Create ${PROFILE_DIR}/tkg.fdata

seconds defaults to ${RECORD_SECONDS}.

Run as a normal user. See optimization/readme.md for the complete workflow.
EOF
}

_require_tool() {
  command -v "$1" >/dev/null 2>&1 || _die "Required tool not found: $1"
}

_positive_number() {
  [[ $1 =~ ^[1-9][0-9]*$ ]] || _die "$2 must be a positive number."
}

_select_propeller_profiler() {
  local help

  if [[ -n $PROPELLER_PROFILER ]]; then
    _require_tool "$PROPELLER_PROFILER"
  elif command -v generate_propeller_profiles >/dev/null 2>&1; then
    PROPELLER_PROFILER="generate_propeller_profiles"
  elif command -v create_llvm_prof >/dev/null 2>&1; then
    PROPELLER_PROFILER="create_llvm_prof"
  else
    _die "Required tool not found: generate_propeller_profiles or create_llvm_prof"
  fi

  help="$("$PROPELLER_PROFILER" --helpfull 2>&1 || true)"
  if [[ -z $help ]]; then
    _die "Could not inspect Propeller profiler: $PROPELLER_PROFILER"
  fi

  if [[ $help == *"--cc_profile"* && $help == *"--ld_profile"* ]]; then
    propeller_profiler_kind="modern"
  elif [[ $help == *"--format"* && $help == *"--out"* && \
    $help == *"--propeller_symorder"* ]]; then
    propeller_profiler_kind="legacy"
  else
    _die "Unsupported Propeller profiler interface: $PROPELLER_PROFILER"
  fi

  _msg "Using Propeller profiler: $PROPELLER_PROFILER ($propeller_profiler_kind interface)"
}

_restore_perf_access() {
  if [[ $sysctls_changed == true ]]; then
    _msg "Restoring perf sysctls"
    sudo sysctl -q -w "kernel.kptr_restrict=${old_kptr}" \
      "kernel.perf_event_paranoid=${old_paranoid}" >/dev/null ||
      printf 'WARNING: Could not restore the perf sysctls.\n' >&2
    sysctls_changed=false
  fi
}

_stop_converter_group() {
  [[ -n $converter_pgid ]] || return 0

  kill -TERM -- "-$converter_pgid" 2>/dev/null || true
  for _ in {1..20}; do
    kill -0 -- "-$converter_pgid" 2>/dev/null || break
    sleep 0.1
  done
  if kill -0 -- "-$converter_pgid" 2>/dev/null; then
    kill -KILL -- "-$converter_pgid" 2>/dev/null || true
  fi
  converter_pgid=""
}

_cleanup() {
  local status=$?

  trap - EXIT
  _stop_converter_group
  _restore_perf_access
  if [[ -n $work_dir && -d $work_dir ]]; then
    if [[ $bolt_preserve_data == true && -s $bolt_perf_data ]]; then
      rm -rf -- "$work_dir/perf2bolt-tmp" "$work_dir/tkg.fdata"
      printf 'WARNING: BOLT conversion failed; perf data preserved at %s\n' \
        "$bolt_perf_data" >&2
    else
      rm -rf -- "$work_dir"
    fi
  fi
  exit "$status"
}
trap _cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

_enable_perf_access() {
  old_kptr="$(< /proc/sys/kernel/kptr_restrict)"
  old_paranoid="$(< /proc/sys/kernel/perf_event_paranoid)"

  sudo -v
  sysctls_changed=true
  sudo sysctl -q -w kernel.kptr_restrict=0 kernel.perf_event_paranoid=0 >/dev/null
}

_default_perf_event() {
  local vendor
  vendor="$(awk -F ': *' '/^vendor_id/{ print $2; exit }' /proc/cpuinfo)"

  case "$vendor" in
    GenuineIntel)
      printf '%s\n' 'BR_INST_RETIRED.NEAR_TAKEN:k'
      ;;
    AuthenticAMD)
      grep -m 1 '^flags' /proc/cpuinfo | grep -Eq '(^| )(brs|amd_lbr_v2)( |$)' ||
        _die "This AMD CPU does not report BRS or amd_lbr_v2 support."
      grep -q -- '--pfm-events' < <(perf record -h 2>&1 || true) ||
        _die "AMD profiling requires perf built with libpfm support."
      printf '%s\n' 'RETIRED_TAKEN_BRANCH_INSTRUCTIONS:k'
      ;;
    *)
      _die "Unsupported CPU vendor: ${vendor:-unknown}"
      ;;
  esac
}

_record_perf() {
  local event="$1"
  local output="$2"
  shift 2
  local -a workload=("$@")
  local -a event_args=()

  if [[ $event == 'RETIRED_TAKEN_BRANCH_INSTRUCTIONS:k' ]]; then
    event_args=(--pfm-events "$event")
  else
    event_args=(-e "$event")
  fi

  _msg "Recording $(basename "$output"): ${workload[*]}"
  perf record "${event_args[@]}" -a -N -b -c 500009 \
    -o "$output" -- "${workload[@]}" ||
    _die "perf recording failed for event $event."
}

_convert_autofdo() {
  local datafile="$1"
  local outfile="${datafile%.data}.afdo"

  _msg "Converting $(basename "$datafile")"
  "$LLVM_PROFGEN" --kernel --binary="$VMLINUX" --perfdata="$datafile" \
    --format=extbinary -o "$outfile"
}

_install_profile() {
  local source="$1"
  local destination="$2"
  local backup

  [[ -s $source ]] || _die "Generated profile is empty: $source"
  if [[ -e $destination ]]; then
    backup="${destination}.bak.$(date +%Y%m%d-%H%M%S)"
    cp -a -- "$destination" "$backup"
    _msg "Previous profile backed up to $backup"
  fi
  install -m 0644 "$source" "$destination"
}

_check_running_kernel() {
  local mode="$1"
  local config
  config="$(dirname "$VMLINUX")/.config"

  [[ -r $VMLINUX ]] || _die "vmlinux not found: $VMLINUX"

  if [[ -r $config ]]; then
    case "$mode" in
      autofdo)
        grep -q '^CONFIG_AUTOFDO_CLANG=y' "$config" ||
          _die "The running kernel was not built with CONFIG_AUTOFDO_CLANG=y."
        ;;
      propeller)
        grep -q '^CONFIG_AUTOFDO_CLANG=y' "$config" ||
          _die "Propeller requires an AutoFDO Pass 2 kernel."
        grep -q '^CONFIG_PROPELLER_CLANG=y' "$config" ||
          _die "The running kernel was not built with CONFIG_PROPELLER_CLANG=y."
        ;;
      bolt)
        grep -q '^CONFIG_BOLT_CLANG=y' "$config" ||
          _die "The running kernel was not built with CONFIG_BOLT_CLANG=y."
        ;;
    esac
  fi
}

_prepare_run() {
  local mode="$1"

  (( EUID != 0 )) || _die "Run this script as your normal user, not with sudo."
  _require_tool sudo
  _check_running_kernel "$mode"
  mkdir -p "$PROFILE_DIR"
  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/tkg-profile.XXXXXX")"

  _require_tool perf
  _enable_perf_access
}

_do_autofdo() {
  local event
  local -a profiles=()

  _require_tool "$LLVM_PROFGEN"
  _require_tool "$LLVM_PROFDATA"
  _positive_number "$AUTOFDO_DESKTOP_SECONDS" AUTOFDO_DESKTOP_SECONDS
  _prepare_run autofdo

  event="${AUTOFDO_EVENT:-$(_default_perf_event)}"
  _record_perf "$event" "$work_dir/desktop.data" sleep "$AUTOFDO_DESKTOP_SECONDS"

  if [[ -n ${AUTOFDO_NATIVE_CMD:-} ]]; then
    read -r -a native_cmd <<< "$AUTOFDO_NATIVE_CMD"
    _record_perf "$event" "$work_dir/native.data" "${native_cmd[@]}"
  fi

  if [[ -n ${AUTOFDO_WINE_CMD:-} ]]; then
    read -r -a wine_cmd <<< "$AUTOFDO_WINE_CMD"
    _record_perf "$event" "$work_dir/wine.data" "${wine_cmd[@]}"
  fi

  for datafile in "$work_dir"/*.data; do
    _convert_autofdo "$datafile"
  done
  profiles=("$work_dir"/*.afdo)

  _msg "Merging AutoFDO profiles"
  "$LLVM_PROFDATA" merge --sample -o "$work_dir/tkg.afdo" "${profiles[@]}"
  _install_profile "$work_dir/tkg.afdo" "$PROFILE_DIR/tkg.afdo"
  _msg "AutoFDO profile ready: $PROFILE_DIR/tkg.afdo"
}

_do_propeller() {
  local event
  local cc_profile
  local ld_profile
  local -a workload=()

  _select_propeller_profiler
  _positive_number "$PROPELLER_SECONDS" PROPELLER_SECONDS
  _prepare_run propeller
  cc_profile="$work_dir/tkg-propeller_cc_profile.txt"
  ld_profile="$work_dir/tkg-propeller_ld_profile.txt"

  event="${PROPELLER_EVENT:-$(_default_perf_event)}"
  if [[ -n ${PROPELLER_CMD:-} ]]; then
    read -r -a workload <<< "$PROPELLER_CMD"
  else
    workload=(sleep "$PROPELLER_SECONDS")
  fi
  _record_perf "$event" "$work_dir/propeller.data" "${workload[@]}"

  _msg "Generating Propeller profiles"
  case "$propeller_profiler_kind" in
    modern)
      "$PROPELLER_PROFILER" --binary="$VMLINUX" \
        --profile="$work_dir/propeller.data" \
        --cc_profile="$cc_profile" --ld_profile="$ld_profile" \
        --propeller_options='output_module_name: true'
      ;;
    legacy)
      "$PROPELLER_PROFILER" --binary="$VMLINUX" \
        --profile="$work_dir/propeller.data" --format=propeller \
        --propeller_output_module_name --out="$cc_profile" \
        --propeller_symorder="$ld_profile"
      ;;
    *)
      _die "No compatible Propeller profiler interface selected."
      ;;
  esac

  _install_profile "$cc_profile" "$PROFILE_DIR/tkg-propeller_cc_profile.txt"
  _install_profile "$ld_profile" "$PROFILE_DIR/tkg-propeller_ld_profile.txt"
  _msg "Propeller profiles ready under $PROFILE_DIR"
}

_do_bolt() {
  local perf_data
  local bolt_profile
  local converter_tmp
  local converter_status
  local -a workload=()

  _require_tool "$PERF2BOLT"
  _require_tool "$LLVM_BOLT"
  _require_tool setsid
  _positive_number "$BOLT_SECONDS" BOLT_SECONDS
  _check_running_kernel bolt

  _msg "Checking whether llvm-bolt can parse the profiling kernel"
  if ! "$LLVM_BOLT" "$VMLINUX" -o /dev/null --lite; then
    _die "llvm-bolt cannot safely process $VMLINUX. Rebuild the BOLT Pass 1 kernel before recording."
  fi

  _prepare_run bolt
  perf_data="$work_dir/perf.data"
  bolt_profile="$work_dir/tkg.fdata"
  converter_tmp="$work_dir/perf2bolt-tmp"
  bolt_perf_data="$perf_data"

  if [[ -n ${BOLT_CMD:-} ]]; then
    read -r -a workload <<< "$BOLT_CMD"
  else
    workload=(sleep "$BOLT_SECONDS")
  fi

  _msg "Recording kernel branch data: ${workload[*]}"
  perf record -a -e cycles -j any,k -F "${BOLT_FREQUENCY:-5000}" \
    -o "$perf_data" -- "${workload[@]}" || {
      [[ ! -s $perf_data ]] || bolt_preserve_data=true
      _die "BOLT perf recording failed."
    }

  _msg "Converting perf data with perf2bolt"
  mkdir -p "$converter_tmp"
  set +e
  TMPDIR="$converter_tmp" setsid "$PERF2BOLT" \
    -p "$perf_data" -o "$bolt_profile" "$VMLINUX" &
  converter_pgid=$!
  wait "$converter_pgid"
  converter_status=$?
  _stop_converter_group
  set -e
  if (( converter_status != 0 )); then
    bolt_preserve_data=true
    _die "BOLT profile conversion failed."
  fi

  _install_profile "$bolt_profile" "$PROFILE_DIR/tkg.fdata"
  rm -rf -- "$converter_tmp"
  _msg "BOLT profile ready: $PROFILE_DIR/tkg.fdata"
}

mode="${1:-}"
duration="${2:-}"

(( $# <= 2 )) || _die "Too many arguments."
if [[ -n $duration ]]; then
  _positive_number "$duration" seconds
fi

case "$mode" in
  autofdo)
    [[ -z $duration ]] || AUTOFDO_DESKTOP_SECONDS="$duration"
    _do_autofdo
    ;;
  propeller)
    [[ -z $duration ]] || PROPELLER_SECONDS="$duration"
    _do_propeller
    ;;
  bolt)
    [[ -z $duration ]] || BOLT_SECONDS="$duration"
    _do_bolt
    ;;
  -h | --help)
    _usage
    ;;
  *)
    _usage >&2
    exit 2
    ;;
esac

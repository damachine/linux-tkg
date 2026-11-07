#!/usr/bin/env bash

# Optional training load for generate-profile.sh; does not collect profiles itself.
set -Eeuo pipefail

JOBS="${JOBS:-$(nproc)}"
WORKLOAD_DIR="${WORKLOAD_DIR:-${TMPDIR:-/tmp}}"
KERNEL_SOURCE="${KERNEL_SOURCE:-}"

work_dir=""
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

_msg() {
  printf '==> %s\n' "$*"
}

_die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

_cleanup() {
  [[ -z $work_dir ]] || rm -rf -- "$work_dir"
}
trap _cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
  cat <<EOF
Usage: $0

Run Git and file I/O training loads, plus Sysbench if installed.
Set KERNEL_SOURCE to a clean kernel source tree to also build vmlinux with LLVM.
JOBS defaults to $(nproc); WORKLOAD_DIR defaults to ${TMPDIR:-/tmp}.
All generated files are removed on exit. Nothing is installed or downloaded.
EOF
  exit 0
fi

(( $# == 0 )) || _die "Unexpected arguments. See --help."
(( EUID != 0 )) || _die "Run this script as your normal user, not with sudo."
[[ $JOBS =~ ^[1-9][0-9]*$ ]] || _die "JOBS must be a positive number."
command -v git >/dev/null 2>&1 || _die "Required tool not found: git"
git -C "$source_dir" rev-parse --git-dir >/dev/null

if [[ -n $KERNEL_SOURCE ]]; then
  KERNEL_SOURCE="$(realpath "$KERNEL_SOURCE")"
  [[ -f $KERNEL_SOURCE/Makefile && -d $KERNEL_SOURCE/kernel ]] ||
    _die "KERNEL_SOURCE must point to a kernel source tree."
  [[ ! -e $KERNEL_SOURCE/.config && ! -d $KERNEL_SOURCE/include/config ]] ||
    _die "KERNEL_SOURCE must be clean for an out-of-tree build. Use a separate source tree."
  for tool in make clang ld.lld; do
    command -v "$tool" >/dev/null 2>&1 || _die "Required tool not found: $tool"
  done
fi

mkdir -p "$WORKLOAD_DIR"
work_dir="$(mktemp -d "$WORKLOAD_DIR/tkg-workload.XXXXXX")"

_msg "Running Git and source file workloads"
git -C "$source_dir" log -n 200 --format=medium > "$work_dir/git.log"
git -C "$source_dir" diff --no-ext-diff --stat HEAD > "$work_dir/git.diff"
git -C "$source_dir" archive HEAD | tar -x -C "$work_dir"
find "$work_dir" -type f -exec cat -- {} + > /dev/null

_msg "Writing and reading a 256 MiB test file"
dd if=/dev/zero of="$work_dir/io.data" bs=1M count=256 conv=fsync status=none
dd if="$work_dir/io.data" of=/dev/null bs=1M status=none
rm -- "$work_dir/io.data"

if command -v sysbench >/dev/null 2>&1; then
  _msg "Running Sysbench CPU and memory workloads"
  sysbench --time=30 --threads="$JOBS" cpu --cpu-max-prime=50000 run
  sysbench --threads="$JOBS" memory --memory-block-size=1M --memory-total-size=1G run
  sysbench --threads="$JOBS" memory --memory-block-size=1M --memory-total-size=1G \
    --memory-oper=read run
else
  _msg "Sysbench is not installed; skipping CPU and memory workloads"
fi

if [[ -n $KERNEL_SOURCE ]]; then
  _msg "Building a defconfig kernel from $KERNEL_SOURCE with $JOBS jobs"
  make -C "$KERNEL_SOURCE" O="$work_dir/kernel-build" LLVM=1 defconfig
  make -C "$KERNEL_SOURCE" O="$work_dir/kernel-build" LLVM=1 -j"$JOBS" vmlinux
else
  _msg "KERNEL_SOURCE is unset; skipping the kernel build"
fi

_msg "Training load finished"

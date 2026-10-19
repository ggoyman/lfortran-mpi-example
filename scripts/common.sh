#!/usr/bin/env bash
# Shared paths and helpers; all generated files belong to this checkout.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/config/versions.env"
WORK_DIR="$PROJECT_ROOT/.work"
SOURCE_DIR="$WORK_DIR/src"
BUILD_DIR="$WORK_DIR/build"
LOG_DIR="$WORK_DIR/logs"
LF_SOURCE="$SOURCE_DIR/lfortran"
MPI_SOURCE="$SOURCE_DIR/mpich-$MPI_RELEASE"
FORTRAN_SOURCE="$SOURCE_DIR/mpich-fortran-$MPI_RELEASE"
LF_BUILD="$LF_SOURCE/build/llvm11"
LF_PREFIX="$WORK_DIR/install/lfortran"
MPI_PREFIX="$WORK_DIR/install/c-mpi"
FORTRAN_PREFIX="$WORK_DIR/install/fortran"
JOBS="${JOBS:-2}"
PIXI_BIN="${PIXI_BIN:-pixi}"
export JOBS PIXI_BIN
export PIXI_CACHE_DIR="${PIXI_CACHE_DIR:-$WORK_DIR/pixi-cache}"
export CMAKE_BUILD_PARALLEL_LEVEL="$JOBS"

die() { echo "Error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
check_host() {
    [[ "$(uname -s)" = Linux && "$(uname -m)" = x86_64 ]] ||
        die 'This recipe is tested on Linux x86_64 only.'
    [[ "$PROJECT_ROOT" != *[[:space:]]* ]] ||
        die 'Use a checkout path without whitespace (upstream Autotools limitation).'
    [[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || die 'JOBS must be a positive integer.'
    need "$PIXI_BIN"
}
prepare_dirs() { mkdir -p "$SOURCE_DIR" "$BUILD_DIR" "$LOG_DIR"; }
verify_sha256() {
    printf '%s  %s\n' "$2" "$1" | sha256sum --check --status - ||
        die "SHA256 verification failed: $1"
}
require_sources() {
    [[ -f "$LF_SOURCE/pixi.toml" && -x "$FORTRAN_SOURCE/configure" && -x "$MPI_SOURCE/configure" ]] ||
        die 'Run scripts/fetch.sh first.'
    [[ "$(git -C "$LF_SOURCE" rev-parse HEAD)" = "$LFORTRAN_COMMIT" ]] ||
        die 'LFortran checkout differs from the pinned commit; use a fresh .work directory.'
    verify_sha256 "$LF_SOURCE/pixi.lock" "$PIXI_LOCK_SHA256"
}
pixi_run() {
    "$PIXI_BIN" run --manifest-path "$LF_SOURCE/pixi.toml" -e llvm11 --locked "$@"
}
run_logged() {
    local label="$1" status
    shift
    echo "==> $label (log: .work/logs/$label.log)"
    if "$@" > "$LOG_DIR/$label.log" 2>&1; then
        echo "    $label: OK"
    else
        status=$?
        tail -n 35 "$LOG_DIR/$label.log" >&2
        echo "Failed: $label (exit $status); see $LOG_DIR/$label.log" >&2
        return "$status"
    fi
}

#!/usr/bin/env bash
# Shared paths; public entry points are setup.sh and test.sh.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/config/versions.env"
WORK_DIR="${MPI_WORK_DIR:-$PROJECT_ROOT/.work}"
WORK_DIR="${WORK_DIR%/}"
SOURCE_DIR="$WORK_DIR/src"
BUILD_DIR="$WORK_DIR/build"
LOG_DIR="$WORK_DIR/logs"
LF_SOURCE="$SOURCE_DIR/lfortran"
MPI_SOURCE="$SOURCE_DIR/mpich-$MPI_RELEASE"
FORTRAN_SOURCE="$SOURCE_DIR/mpich-fortran-$MPI_RELEASE"
LF_BUILD="$LF_SOURCE/build/llvm11"
LF_PREFIX="$WORK_DIR/install/lfortran"
MPI_PREFIX="$WORK_DIR/install/mpi"
MODE=pinned
[[ -z "${LFORTRAN:-}" ]] || MODE=external
LF_EXE="${LFORTRAN:-$LF_PREFIX/bin/lfortran}"
BACKEND_PREFIX="${MPI_BACKEND:-$MPI_PREFIX}"
EXTERNAL_BACKEND=0
[[ -z "${MPI_BACKEND:-}" ]] || EXTERNAL_BACKEND=1
BUILD_FCFLAGS='--cpp --implicit-interface --implicit-typing --separate-compilation'
USER_FCFLAGS='--cpp --separate-compilation'
JOBS="${JOBS:-2}"
PIXI_BIN="${PIXI_BIN:-pixi}"
export JOBS PIXI_BIN
export MPI_WORK_DIR="$WORK_DIR"
export PIXI_CACHE_DIR="${PIXI_CACHE_DIR:-$WORK_DIR/pixi-cache}"
export CMAKE_BUILD_PARALLEL_LEVEL="$JOBS"
export TMPDIR="${TMPDIR:-$WORK_DIR/tmp}"

die() { echo "Error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
check_host() {
    [[ "$(uname -s)" = Linux && "$(uname -m)" = x86_64 ]] ||
        die 'This recipe is tested on Linux x86_64 only.'
    [[ "$WORK_DIR" = /* && -n "$WORK_DIR" ]] || die 'MPI_WORK_DIR must be an absolute path.'
    for path in "$PROJECT_ROOT" "$WORK_DIR" "$LF_EXE" "$BACKEND_PREFIX"; do
        [[ "$path" != *[[:space:]]* ]] || die 'Use paths without whitespace (upstream Autotools limitation).'
    done
    [[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || die 'JOBS must be a positive integer.'
}
prepare_dirs() { mkdir -p "$SOURCE_DIR" "$BUILD_DIR" "$LOG_DIR" "$WORK_DIR/results" "$TMPDIR"; }
resolve_executable() {
    local executable
    executable=$(command -v "$1") || die "Required executable not found: $1"
    readlink -f "$executable"
}
verify_sha256() {
    printf '%s  %s\n' "$2" "$1" | sha256sum --check --status - ||
        die "SHA256 verification failed: $1"
}
pixi_run() {
    need "$PIXI_BIN"
    "$PIXI_BIN" run --manifest-path "$LF_SOURCE/pixi.toml" -e llvm11 --locked "$@"
}
run_toolchain() {
    if [[ "$MODE" = pinned ]]; then pixi_run "$@"; else "$@"; fi
}
load_setup() {
    [[ -f "$WORK_DIR/setup.env" && -f "$WORK_DIR/setup-complete" ]] || die 'Run scripts/setup.sh first.'
    source "$WORK_DIR/setup.env"
    [[ "$CONFIG_ROOT" = "$WORK_DIR" && "$CONFIG_RECIPE" = 2 && "$CONFIG_MPI_RELEASE" = "$MPI_RELEASE" ]] ||
        die 'Installation path or recipe changed; use a fresh MPI_WORK_DIR.'
    [[ -x "$LF_EXE" && -x "$MPI_PREFIX/bin/mpifort" && -x "$BACKEND_PREFIX/bin/mpiexec" ]] ||
        die 'An installed component is missing; rerun scripts/setup.sh with the same settings.'
}
mpi_libraries() {
    export LD_LIBRARY_PATH="$MPI_PREFIX/lib:$BACKEND_LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
}
run_logged() {
    local label="$1" status
    shift
    echo "==> $label (log: $LOG_DIR/$label.log)"
    if "$@" > "$LOG_DIR/$label.log" 2>&1; then
        echo "    $label: OK"
    else
        status=$?
        tail -n 35 "$LOG_DIR/$label.log" >&2
        echo "Failed: $label (exit $status); see $LOG_DIR/$label.log" >&2
        return "$status"
    fi
}

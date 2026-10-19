#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
load_setup
ranks="${MPI_TEST_PROCS:-2}"
timeout_seconds="${MPI_TEST_TIMEOUT:-60}"
[[ "$ranks" =~ ^[1-9][0-9]*$ ]] || die 'MPI_TEST_PROCS must be positive.'
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || die 'MPI_TEST_TIMEOUT must be positive.'
mpi_libraries
mkdir -p "$BUILD_DIR/tests" "$WORK_DIR/results"
cd "$BUILD_DIR/tests"
{
    printf 'Toolchain mode: %s\nCompiler: %s\nCFI headers: %s\nBackend: %s\n' \
        "$MODE" "$LF_EXE" "$LF_C_INCLUDE_DIR" "$BACKEND_PREFIX"
    if [[ "$MODE" = pinned ]]; then
        printf 'LFortran source: '
        git -C "$LF_SOURCE" rev-parse HEAD
        "$PIXI_BIN" --version
    fi
    "$CC_EXE" --version | head -1
    "$LF_EXE" --version
    if [[ -x "$BACKEND_PREFIX/bin/mpichversion" ]]; then
        "$BACKEND_PREFIX/bin/mpichversion"
    else
        "$BACKEND_PREFIX/bin/mpiexec" --version
    fi
    "$MPI_PREFIX/bin/mpifort" -show
} > "$WORK_DIR/results/versions.txt"
summary="$WORK_DIR/results/smoke.tsv"
[[ "${1:-}" != --extended ]] || summary="$WORK_DIR/results/extended.tsv"
printf 'test\tcompile\trun\tranks\n' > "$summary"
failures=0
run_case() {
    local name="$1" marker="$2" compile=FAIL run=SKIP observed status
    shift 2
    if run_logged "smoke-$name-compile" "$MPI_PREFIX/bin/mpifort" "$@" \
        "$PROJECT_ROOT/examples/$name.f90" -o "smoke-$name"; then
        compile=PASS
        if run_logged "smoke-$name-run" timeout "$timeout_seconds" \
            "$BACKEND_PREFIX/bin/mpiexec" -n "$ranks" "./smoke-$name"; then
            observed=$(grep -Ec "of[[:space:]]+$ranks[[:space:]]+$marker" "$LOG_DIR/smoke-$name-run.log" || true)
            if [[ "$observed" = "$ranks" ]]; then run=PASS; else run=FAIL; fi
        else
            status=$?
            run=FAIL
            [[ "$status" != 124 ]] || run=TIMEOUT
        fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$name" "$compile" "$run" "$ranks" >> "$summary"
    if [[ "$compile" != PASS || "$run" != PASS ]]; then failures=$((failures + 1)); fi
}
# Legacy bindings require implicit interfaces; mpi_f08 uses explicit interfaces.
run_case mpifh sum --implicit-interface
run_case mpi sum --implicit-interface
run_case mpi_f08 sum
run_case mpi_arrays 'array checks passed' --implicit-interface
if [[ "${1:-}" = --extended ]]; then
    run_case mpi_f08_arrays 'array checks passed'
fi
cat "$summary"
[[ "$failures" = 0 ]] || { echo "$failures test(s) failed; see $LOG_DIR." >&2; exit 1; }
echo 'All selected examples compiled and passed their MPI checks.'

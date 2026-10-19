#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
check_host
prepare_dirs
require_sources
case "${1:-lfortran}" in
    lfortran)
        if [[ -f "$LF_BUILD/CMakeCache.txt" ]]; then
            grep -Fqx "CMAKE_INSTALL_PREFIX:PATH=$LF_PREFIX" "$LF_BUILD/CMakeCache.txt" ||
                die 'Build prefix changed. Use a fresh .work directory after moving the checkout.'
            run_logged lfortran-build pixi_run rebuild
        else
            run_logged lfortran-build pixi_run build "-DCMAKE_INSTALL_PREFIX=$LF_PREFIX"
        fi
        run_logged lfortran-install pixi_run cmake --install "$LF_BUILD"
        run_logged lfortran-version pixi_run "$LF_PREFIX/bin/lfortran" --version
        ;;
    backend|bindings)
        [[ -x "$LF_PREFIX/bin/lfortran" ]] || die 'Build LFortran first.'
        pixi_run bash "$PROJECT_ROOT/scripts/build-mpi.sh" "$1"
        ;;
    *) die 'Usage: scripts/build.sh [lfortran|backend|bindings]' ;;
esac

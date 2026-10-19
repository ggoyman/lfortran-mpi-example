#!/usr/bin/env bash
# Functions sourced by setup-mpi.sh, before the expensive MPI build.
check_compiler() {
    local version
    version=$("$LF_EXE" --version) || return
    if [[ "$version" != *'LFortran version:'* ]]; then
        echo 'LFORTRAN does not identify itself as LFortran.' >&2
        return 1
    fi
    printf '%s\n' "$version"
    LF_C_INCLUDE_DIR="${LFORTRAN_C_INCLUDE_DIR:-}"
    if [[ -z "$LF_C_INCLUDE_DIR" ]]; then
        if ! LF_C_INCLUDE_DIR=$("$LF_EXE" --print-c-include-dir); then
            echo "Set LFORTRAN_C_INCLUDE_DIR to this compiler's CFI header directory." >&2
            return 1
        fi
    fi
    if [[ ! -f "$LF_C_INCLUDE_DIR/ISO_Fortran_binding.h" ]]; then
        echo 'LFortran CFI header not found.' >&2
        return 1
    fi
    LF_C_INCLUDE_DIR=$(cd "$LF_C_INCLUDE_DIR" && pwd -P)
    if [[ "$LF_C_INCLUDE_DIR" = *[[:space:]]* ]]; then
        echo 'Use a CFI header path without whitespace.' >&2
        return 1
    fi
    mkdir -p "$BUILD_DIR/compiler-check"
    cd "$BUILD_DIR/compiler-check"
    cat > module.f90 <<'EOF'
#define STEP 1
module check_module
contains
  subroutine increment(x)
    integer, intent(inout) :: x
    x = x + STEP
  end subroutine
end module
EOF
    cat > fixed.f <<'EOF'
      subroutine fixed_increment(x)
      integer x
      x = x + 1
      end
EOF
    cat > main.f90 <<'EOF'
program check
  use check_module
  implicit none
  integer :: x
  x = 40
  call increment(x)
  call fixed_increment(x)
  if (x /= 42) error stop 1
end program
EOF
    cat > header.c <<'EOF'
#include <ISO_Fortran_binding.h>
int check_descriptor(void) { return CFI_VERSION; }
EOF
    "$CC_EXE" -I"$LF_C_INCLUDE_DIR" -c header.c -o header.o || return
    # These flags belong to MPICH's source build, not the installed wrapper.
    "$LF_EXE" --cpp --implicit-interface --implicit-typing --separate-compilation -c module.f90 -o module.o || return
    "$LF_EXE" --cpp --implicit-interface --implicit-typing --separate-compilation --fixed-form -c fixed.f -o fixed.o || return
    "$LF_EXE" --cpp --implicit-interface --separate-compilation main.f90 module.o fixed.o -o check || return
    ./check || return
    printf 'CFI headers: %s\n' "$LF_C_INCLUDE_DIR"
    printf '%s\n' "$version" > "$WORK_DIR/results/lfortran-version.txt"
}

save_configuration() {
    local candidate="$WORK_DIR/setup.env.tmp" variable
    CONFIG_ROOT="$WORK_DIR"
    CONFIG_RECIPE=2
    CONFIG_LF_SHA256=$(sha256sum "$LF_EXE")
    CONFIG_LF_SHA256="${CONFIG_LF_SHA256%% *}"
    CONFIG_HEADER_SHA256=$(sha256sum "$LF_C_INCLUDE_DIR/ISO_Fortran_binding.h")
    CONFIG_HEADER_SHA256="${CONFIG_HEADER_SHA256%% *}"
    CONFIG_MPI_RELEASE="$MPI_RELEASE"
    for variable in CONFIG_ROOT CONFIG_RECIPE CONFIG_LF_SHA256 CONFIG_HEADER_SHA256 CONFIG_MPI_RELEASE \
        MODE LF_EXE LF_C_INCLUDE_DIR CC_EXE MPI_PREFIX BACKEND_PREFIX BACKEND_LIBDIR EXTERNAL_BACKEND \
        BUILD_FCFLAGS USER_FCFLAGS; do
        printf '%s=%q\n' "$variable" "${!variable}"
    done > "$candidate"
    if [[ -f "$WORK_DIR/setup.env" ]] && ! cmp -s "$candidate" "$WORK_DIR/setup.env"; then
        rm -f "$candidate"
        die 'Compiler, backend, or configuration changed. Use a fresh MPI_WORK_DIR; existing modules are compiler-specific.'
    fi
    mv "$candidate" "$WORK_DIR/setup.env"
}

check_backend() {
    if [[ ! -x "$BACKEND_PREFIX/bin/mpicc_abi" || ! -x "$BACKEND_PREFIX/bin/mpiexec" ]]; then
        echo 'Backend needs mpicc_abi and mpiexec; a native libmpi.so alone is insufficient.' >&2
        return 1
    fi
    mkdir -p "$BUILD_DIR/backend-check"
    cd "$BUILD_DIR/backend-check"
    cat > abi.c <<'EOF'
#include <mpi.h>
#if !defined(MPI_ABI_VERSION) || MPI_ABI_VERSION < 1
#error This example requires the MPI standard ABI
#endif
int main(void) {
    int rank, value;
    MPI_Init(0, 0);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Allreduce(&rank, &value, 1, MPI_INT, MPI_SUM, MPI_COMM_WORLD);
    MPI_Finalize();
    return value != 0;
}
EOF
    "$BACKEND_PREFIX/bin/mpicc_abi" abi.c -o abi || return
    LD_LIBRARY_PATH="$BACKEND_LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ./abi
}

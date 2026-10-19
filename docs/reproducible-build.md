# Reproducible build and advanced configuration

The short workflow is `scripts/setup.sh` followed by `scripts/test.sh`.
`scripts/reproduce.sh` combines them for the pinned source build. The scripts
under `scripts/internal/` implement the stages and are not additional public
entry points.

## Versions and dependencies

| Component | Pin |
| --- | --- |
| LFortran | `d9048e2e6e15b753c3da5e15d55c80f614cdba39` |
| Observed LFortran version | `0.67.0-965-gd9048e2e6e` |
| Upstream Pixi environment | `llvm11`, LLVM 11.1.0 |
| MPICH C backend | 5.1.0a1, MPI ABI 1:0:0 |
| Standalone Fortran bindings | 5.1.0a1 |
| Pixi used for validation | 0.82.0 |

Source pins and archive SHA256 hashes are in [versions.env](../config/versions.env).
The [dependency lock](../config/pixi.lock) is copied into the pinned LFortran
checkout, and Pixi runs with `--locked`. A changed manifest/lock combination fails
instead of resolving another toolchain. The full Git checkout includes the
history and tags needed for LFortran's version script. Archives come from the
official MPICH server and are checked before extraction. Their recorded hashes
identify the tested downloads; they are not signed publisher checksums.

The [MPICH release announcement](https://www.mpich.org/2026/10/11/mpich-5-1-0a1-released/)
describes the standalone library and standard-ABI requirement. This example
uses a C-only backend built from the matching archive.

## Installation and state

```text
.work/
  src/                 Verified source checkouts
  build/               Compiler checks, backend, bindings, and tests
  install/
    lfortran/          Pinned source-built compiler
    mpi/               C backend and standalone Fortran bindings
  setup.env            Recorded compiler/backend selection
  logs/                Phase and per-test logs
  results/             Versions, wrapper command, and TSV results
```

The MPI libraries share a prefix but remain separate builds. `mpi/bin/` contains
`mpicc_abi`, `mpifort`, and `mpiexec`; `mpi/include/` contains the C headers and
LFortran modules; `mpi/lib/` contains `libmpi_abi.so` and `libmpifort.a`.

Setup resumes the same build directories. It records the compiler executable
and CFI-header hashes and refuses to reuse the configuration for another
compiler or backend. Use a separate work directory for comparisons:

```bash
MPI_WORK_DIR="$PWD/.work/another-compiler" \
LFORTRAN=/path/to/another/lfortran ./scripts/setup.sh
MPI_WORK_DIR="$PWD/.work/another-compiler" ./scripts/test.sh
```

Do not move an installation or swap its compiler in place. For a compiler
rebuild, select a fresh work directory and rebuild its modules. To remove all
generated state, remove `.work/`; a subsequent setup downloads and builds again.

## Existing LFortran

`LFORTRAN=/path/to/lfortran` skips its source checkout, Pixi environment, and
compiler build. The caller supplies the active C toolchain, make, Python 3, and
the compiler's runtime environment. `CC` can select one C compiler executable.

Setup asks LFortran for its version and `--print-c-include-dir`. For a compiler
without the latter option, set `LFORTRAN_C_INCLUDE_DIR` to the directory holding
that compiler's `ISO_Fortran_binding.h`. It then compiles the C header, a
preprocessed module, and a fixed-form subroutine, links a separate main, and
runs the resulting program. These checks validate the flags used by the recipe;
they do not guarantee that the entire MPI library will compile.

Repeat the same `LFORTRAN`/`MPI_BACKEND` selections when rerunning setup. Tests
and helpers remember the selection. External components and their environment
are recorded rather than covered by the pinned LFortran dependency lock.

## Existing MPI backend

To skip the C backend build:

```bash
LFORTRAN=/path/to/lfortran MPI_BACKEND=/path/to/abi-mpi ./scripts/setup.sh
./scripts/test.sh
```

This optional adapter currently expects `bin/mpicc_abi`, `bin/mpiexec`, and a
shared `libmpi_abi.so` in `lib/` or `lib64/`. Setup compiles a C program requiring
`MPI_ABI_VERSION >= 1` with that wrapper and runs an MPI reduction before
building Fortran. These checks distinguish the standard ABI from a native MPI
installation; they do not establish compatibility with every ABI backend.

The external backend is read-only. New Fortran modules and bindings are installed
in this checkout's `.work/install/mpi/`, not into the external backend. Extra
backend library paths are needed in this mode. Do not reuse modules produced by
gfortran or another compiler.

## Build flags and user flags

| Setting | Why it is retained |
| --- | --- |
| Backend `--disable-fortran --disable-cxx --enable-mpi-abi` | Build the C standard-ABI backend independently |
| Backend `--with-device=ch3:sock` | Keep the previously validated simple TCP transport |
| Backend `--with-hwloc=embedded` | Keep topology-library selection controlled |
| Explicit `--libdir=.../lib` | Keep the merged installation's library path predictable |
| Bindings `--with-mpi=... --enable-mpi-abi` | Select the backend |
| `-DMPI_ABI` | Select the standard ABI in the C dispatcher header |
| Compiler's CFI include directory | Use the descriptor definitions matching LFortran |
| Build `--cpp --implicit-interface --implicit-typing --separate-compilation` | Compile MPICH's generated and legacy Fortran sources |
| Target-specific `FFLAGS += --fixed-form` | Parse only `mpif_h/setbotf.lo` as fixed form |
| Bindings `--disable-shared --enable-static` | Default shared linking fails on libtool's unsupported LFortran driver options |
| `--with-wrapper-dl-type=none` | Avoid the alpha configure's detected bare `-rpath` driver option |
| `main_top_srcdir=...` | Find bundled generators during the alpha package's out-of-tree build |

The fixed-form assignment is appended to the generated build Makefile after
configuration. It is not a global `FFLAGS` override or an upstream source patch.

`MPICH_MPIFORT_FCFLAGS` now contains only `--cpp --separate-compilation`.
`--implicit-typing` stays inside the binding build. The legacy examples pass
`--implicit-interface` explicitly; `mpi_f08` does not need it. Removing
`--separate-compilation` causes duplicate module-symbol definitions with these
pins, so it remains a user-wrapper flag too.

With a merged prefix, `mpifort` already supplies the library search directory.
The recipe adds a correctly forwarded `-Wl,-rpath,...` for `libmpi_abi.so`;
sharing a prefix does not remove the loader's need to find that shared library.
The external-backend mode also embeds its separate `-L` path. See the recorded
`.work/results/mpifort.txt` for the actual command.

Separate configure probes without the device/hwloc options succeeded, but the
default device changed to `ch4:ofi` and was not built or runtime-tested. These
settings remain explicit in the pinned recipe. See the
[validation report](validated-run.md) for the experiment results.

## Options and troubleshooting

| Variable | Default | Purpose |
| --- | --- | --- |
| `JOBS` | `2` | Parallel build jobs |
| `PIXI_BIN` | `pixi` | Pixi executable for the pinned mode |
| `PIXI_CACHE_DIR` | `.work/pixi-cache` | Package cache, optionally shared |
| `LFORTRAN` | Source-built pin | Use an existing compiler |
| `LFORTRAN_C_INCLUDE_DIR` | Compiler-reported | Override the CFI header directory |
| `MPI_BACKEND` | Source-built MPICH | Reuse an ABI backend read-only |
| `MPI_WORK_DIR` | Checkout's `.work/` | Absolute path for separate build state |
| `MPI_TEST_PROCS` | `2` | Local MPI ranks |
| `MPI_TEST_TIMEOUT` | `60` | Seconds per example |

If Pixi is outside PATH, use `PIXI_BIN=/path/to/pixi ./scripts/setup.sh`, and set
the same variable for tests and helpers. First-time pinned builds need network
access to GitHub, conda-forge, and mpich.org. Compiler phases run through the
upstream Pixi build/rebuild tasks. Local MPI execution needs process launching
and sockets permitted by the host/container.

On failure, inspect the printed phase log. Tests continue through the selected
examples, write their compile/run statuses, and return nonzero if any fail.
`test.sh --extended` includes the known failing `mpi_f08` array diagnostic.
Other operating systems, shared Fortran bindings, and multi-node execution
remain outside the validated configuration.

Temporary files default to `.work/tmp/` unless `TMPDIR` is already set. If the
host's temporary directory is full or quota-limited, use an absolute writable
directory, for example `TMPDIR="$PWD/.work/tmp" ./scripts/setup.sh`.

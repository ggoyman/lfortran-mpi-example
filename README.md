# LFortran + standalone MPICH Fortran bindings

Build a source version of LFortran, a C-only MPI backend, and MPICH's separate
Fortran binding library. Then compile and run the same two-rank reduction
through `mpif.h`, `use mpi`, and `use mpi_f08`.

Everything is installed inside the checkout. Pixi supplies the compiler build
dependencies; the scripts use the pinned LFortran repository's own build tasks.

## Quick start

Use **Linux x86_64 with glibc 2.28 or newer**, a checkout path without whitespace,
and these commands
available on PATH:

- Bash, Git, curl, tar, sha256sum, grep, and GNU timeout (normally coreutils).
- [Pixi](https://pixi.prefix.dev/latest/installation/), tested with version 0.82.0.

Allow about 15 GB of disk space for sources, dependency cache, and builds.
16 GB of RAM is recommended. The default is two build jobs; the first run
downloads dependencies and compiles the toolchain, so allow tens of minutes.
Internet access to GitHub, conda-forge, and mpich.org is needed for the first run.

After cloning or unpacking this repository:

```bash
cd lfortran-mpi-example
JOBS=2 ./scripts/reproduce.sh
```

The workflow fetches verified sources, builds and installs all three components,
and runs the MPI tests. Expect a final summary like:

```text
interface  compile  run   ranks
mpifh      PASS     PASS  2
mpi        PASS     PASS  2
mpi_f08    PASS     PASS  2
```

The programs check the reduction result themselves and return a nonzero status
if it is incorrect. The runner also checks the reported communicator size and
number of rank reports. Individual phase logs are in `.work/logs/`; exact versions
and test results are in `.work/results/`.

See the [validated run](docs/validated-run.md) for the tested host, versions,
and results from a fresh build and a complete workflow rerun.

If Pixi is installed outside PATH, set its executable explicitly:

```bash
PIXI_BIN=/path/to/pixi JOBS=2 ./scripts/reproduce.sh
```

## Compile your own program

The helpers activate the same Pixi environment used for the build:

```bash
./bin/lfortran --version
./bin/mpifort examples/mpi_f08.f90 -o .work/my-mpi-program
./bin/mpiexec -n 2 .work/my-mpi-program
```

You can also use `examples/mpi.f90` or `examples/mpifh.f90`. Run these commands
from the repository root. Do not move a built checkout: its compiler modules,
wrappers, and library paths refer to its installation prefix. Build again in a
fresh checkout when changing that path.

## What is pinned

| Component | Version |
| --- | --- |
| LFortran source | `d9048e2e6e15b753c3da5e15d55c80f614cdba39` |
| LFortran version from that checkout | `0.67.0-965-gd9048e2e6e` |
| LLVM environment | LFortran's Pixi `llvm11` environment, LLVM 11.1.0 |
| C-only MPICH backend | 5.1.0a1, MPI-5 standard ABI |
| Standalone MPICH Fortran bindings | 5.1.0a1 |

[config/versions.env](config/versions.env) records source pins and SHA256
checksums. [config/pixi.lock](config/pixi.lock) records the dependency solution
used for the working build. The scripts copy it into the pinned LFortran
checkout and invoke Pixi with `--locked`, so a changed manifest/lock combination
fails instead of silently resolving a different toolchain.

The MPI archives are verified against recorded download hashes. These hashes
identify the tested archives; they are not independently signed publisher
checksums. The complete LFortran Git checkout is fetched so its version script
can use the upstream tags.

MPICH 5.1.0a1 is an **alpha release**. Its separate bindings target MPI-5
ABI-compatible backends, as described in the
[release announcement](https://www.mpich.org/2026/10/11/mpich-5-1-0a1-released/).
This example tests one such backend: a separate C-only MPICH build. Compatibility
with arbitrary older MPI installations is not implied.

## Build one stage at a time

```bash
./scripts/fetch.sh
./scripts/build.sh lfortran
./scripts/build.sh backend
./scripts/build.sh bindings
./scripts/test.sh
```

The LFortran stage configures once and uses its incremental Pixi rebuild task
on subsequent runs. The backend stage reuses its configured build directory.
The bindings stage regenerates the Fortran interfaces during configuration.
Rerunning the workflow is supported for these same pins; source checkouts are
not reset or cleaned by the scripts.

Options:

| Variable | Default | Purpose |
| --- | --- | --- |
| `JOBS` | `2` | Parallel build jobs; use `1` on a memory-constrained host |
| `PIXI_BIN` | `pixi` | Pixi executable |
| `PIXI_CACHE_DIR` | `.work/pixi-cache` | Optional shared package cache |
| `MPI_TEST_PROCS` | `2` | Number of local MPI ranks in the smoke tests |
| `MPI_TEST_TIMEOUT` | `60` | Runtime limit per test, in seconds |

For example:

```bash
MPI_TEST_PROCS=4 ./scripts/test.sh
```

## Why these configuration settings matter

The detailed recipe is in [scripts/build-mpi.sh](scripts/build-mpi.sh).

| Setting | Reason |
| --- | --- |
| Backend `--disable-fortran --disable-cxx --enable-mpi-abi` | Builds a C MPI backend separately from the Fortran library |
| Backend `--with-device=ch3:sock` | Uses a simple local TCP transport for the example |
| Backend `--with-hwloc=embedded` | Uses the topology library shipped in the pinned MPI archive |
| Explicit `--libdir=.../lib` | Gives both components a predictable library directory |
| Binding `--with-mpi=... --enable-mpi-abi` | Selects the installed standard-ABI backend |
| `-DMPI_ABI` | Selects the ABI interface in MPICH's dispatcher header |
| `-I.../lfortran/include/lfortran` | Uses LFortran's C descriptor header when compiling the binding's C sources |
| `--cpp` | Enables preprocessing explicitly |
| `--implicit-interface --implicit-typing` | Enables the legacy calling conventions used by the bindings |
| `--separate-compilation` | Emits module procedures into objects for the static Fortran library |
| `--fixed-form` in make's `FFLAGS` | Parses the legacy `mpif_h/setbotf.f` source; free-form `FCFLAGS` remain unchanged |
| Binding `--disable-shared --enable-static` | Produces a static `libmpifort.a`; the C ABI backend is a shared library |
| `--with-wrapper-dl-type=none` | Avoids the alpha package's detected bare `-rpath` driver option |
| `MPICH_MPIFORT_FCFLAGS` / `MPICH_MPIFORT_LDFLAGS` | Embeds the tested flags and correctly forwarded backend rpath in `mpifort` |
| `main_top_srcdir=...` | Lets the standalone alpha configure find its bundled generators in an out-of-tree build |

No LFortran or MPICH source patch is applied. LFortran is configured with this
checkout's install prefix through the upstream Pixi build task; installation
therefore needs no system-wide write access or staging workaround.

## Layout

```text
bin/                  Pixi-aware lfortran, mpifort, and mpiexec helpers
config/               Source pins and dependency lock
examples/             One smoke program for each Fortran MPI interface
scripts/              Fetch, build, and test entry points
docs/                 Validation notes
.work/                Generated sources, builds, installations, logs, and results
```

`.work/` is ignored by Git. Remove it to discard generated state; a new run
will fetch and build again. Keep a built checkout at its original path.

## Troubleshooting and scope

- **A phase fails:** the script prints the relevant log path and its last
  lines. Full output is retained in `.work/logs/`.
- **Out of memory:** rerun with `JOBS=1`; the LFortran stage resumes its build.
- **MPI launch/socket errors:** local process launching and sockets must be
  permitted by the host or container. Run the tests on a host that provides
  these facilities. They are independent of successful compilation.
- **Wrong compiler's modules/header:** use the provided helpers and the installed
  LFortran CFI include path. Fortran `.mod` files and descriptor layouts are
  compiler-specific.
- **Changing versions:** use a fresh checkout/build state, update the source pins
  and dependency lock together, and rerun all stages. The scripts deliberately
  reject an existing LFortran checkout at a different commit.

This is a reproducible configuration and smoke-test example. The full MPI test
suite, other operating systems, other C MPI backends, multi-node execution, and
shared Fortran bindings are outside the validated scope.

## License and upstream projects

The example scripts and programs are available under the [MIT license](LICENSE).
Downloaded projects and packages retain their own licenses. See
[upstream and dependency notes](docs/upstream.md).

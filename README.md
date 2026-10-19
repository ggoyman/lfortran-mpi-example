# LFortran + MPICH Fortran bindings

Build MPICH's standalone Fortran bindings with LFortran, compile an MPI program,
and run it. The C MPI backend and Fortran bindings are built independently and
installed together in `.work/install/mpi/`.

## Set up and test

Use Linux x86_64 with glibc 2.28 or newer, a path without whitespace, and
[Pixi](https://pixi.prefix.dev/latest/installation/) on PATH. Bash, Git, curl,
tar, sha256sum, readlink, grep, cmp, and GNU timeout are also required.

```bash
git clone https://github.com/ggoyman/lfortran-mpi-example.git
cd lfortran-mpi-example
./scripts/setup.sh
./scripts/test.sh
```

By default, setup builds the pinned LFortran, a C-only MPICH backend supporting
the MPI standard ABI, and the standalone bindings. Pixi supplies the build
environment. Allow roughly 15 GB of disk space and tens of minutes for the first
build; two parallel jobs are used by default. Set `JOBS=1` for less memory use.

Already have a recent LFortran? Keep its environment active and skip building it:

```bash
LFORTRAN=/path/to/lfortran ./scripts/setup.sh
./scripts/test.sh
```

This mode uses your active C toolchain, make, and Python 3. It checks the compiler
version, its CFI header, preprocessing, fixed-form parsing, and separate module
compilation before building MPI. It neither downloads nor builds LFortran.
Use a fresh checkout or `MPI_WORK_DIR` when changing compiler or backend.

## Compile your program

```bash
./bin/mpifort examples/mpi_f08.f90 -o .work/hello
./bin/mpiexec -n 2 .work/hello
```

The helpers select the setup's environment. For the default source build, they
activate Pixi automatically. With an existing compiler, keep that compiler's
environment active. The underlying MPI tools are in `.work/install/mpi/bin/`.

For the legacy `mpif.h` and `use mpi` examples, add `--implicit-interface`:

```bash
./bin/mpifort --implicit-interface examples/mpi_arrays.f90 -o .work/arrays
./bin/mpiexec -n 2 .work/arrays
```

The installed wrapper does not enable implicit typing or implicit interfaces
globally. It supplies `--cpp --separate-compilation` and the library paths.
For fixed-form user sources, also pass `--fixed-form`. Code relying on implicit
typing must request `--implicit-typing` explicitly.

## What the examples cover

| Example | Check |
| --- | --- |
| `mpifh.f90` | Scalar reduction through `include 'mpif.h'` |
| `mpi.f90` | Scalar reduction through `use mpi` |
| `mpi_f08.f90` | Scalar reduction through `use mpi_f08` |
| `mpi_arrays.f90` | Contiguous-array broadcast and reduction through `use mpi` |

Each program validates its result. The runner also checks the number of rank
reports and communicator size. Logs are in `.work/logs/`, and compiler versions,
the wrapper command, and TSV results are in `.work/results/`.

**Known limitation:** the pinned combination crashes on the additional
`mpi_f08` array test with two ranks, including a contiguous-array broadcast.
The scalar smoke tests do not establish working array-descriptor support.
To run that diagnostic as well:

```bash
./scripts/test.sh --extended
```

It reports the failure and exits nonzero. See the [validation report](docs/validated-run.md)
for evidence and the [array reproducer](docs/array-blocker.md). These are smoke
tests; the full MPICH suite and multi-node execution are outside their scope.

## Reproduce the pinned build

The source versions remain LFortran `d9048e2e6e15b753c3da5e15d55c80f614cdba39`
and MPICH/backend bindings `5.1.0a1`. MPICH 5.1.0a1 is an alpha release.
The standalone library requires an MPI standard-ABI backend; an arbitrary
system `libmpi.so` or another compiler's `.mod` files will not suffice.

The original one-command entry point is retained:

```bash
JOBS=2 ./scripts/reproduce.sh
```

It runs setup and the normal tests using the source pins. Detailed flags,
dependency locking, optional existing-backend support, and troubleshooting are
in [reproducible-build.md](docs/reproducible-build.md).

Do not move a built checkout: modules and wrappers contain installation paths.
All generated data is under `.work/` and ignored by Git. Source projects retain
their licenses; the example is [MIT licensed](LICENSE). See [upstream notes](docs/upstream.md).

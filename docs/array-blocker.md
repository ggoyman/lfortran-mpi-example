# Known mpi_f08 array failure

The pinned LFortran/MPICH combination passes the three scalar smoke programs
but fails when broadcasting a contiguous integer array through `mpi_f08` with
two ranks. This was reproduced with the original three-prefix build, before
the setup simplifications. Removing the user-wrapper legacy flags did not
change the failure. The root cause has not been assigned to a component.

## Reproduce

Build the pinned setup, then compile the [small reproducer](../reproducers/mpi_f08_bcast.f90):

```bash
./scripts/setup.sh
./bin/mpifort reproducers/mpi_f08_bcast.f90 -o .work/f08-bcast
./bin/mpiexec -n 2 .work/f08-bcast
```

Expected: each rank receives `[11, 22, 33, 44]` and exits successfully.
Observed: a segmentation fault during broadcast. The smaller diagnostic also
works with one rank, which does not exercise communication of the array.

The two-rank debugger backtrace for the original installation includes:

```text
vector_m2m
MPII_Segment_manipulate
MPIR_Segment_pack
MPIR_Typerep_ipack
MPIR_Typerep_pack
do_localcopy
MPIR_Localcopy
MPIR_Bcast_intra_binomial
MPIR_Bcast_allcomm_auto
MPIR_Bcast_impl
PMPI_Bcast
MPIR_Bcast_cdesc
mpi_bcast_f08ts
```

This shows that the failure reaches the descriptor bridge and datatype-packing
path. It does not by itself identify whether the compiler's descriptor,
the bindings, or the backend is responsible.

## Automated diagnostic

```bash
./scripts/test.sh --extended
```

This runs the normal examples and `examples/mpi_f08_arrays.f90`. The latter
contains contiguous broadcast/reduction and a strided array section; with the
pin it fails at the contiguous broadcast before reaching the later checks.
The runner records FAIL and returns nonzero. No expected-failure conversion
turns that failure into a passing result.

Contiguous broadcast and reduction through `use mpi` are covered separately by
the normal array example. Strided arguments through the legacy `use mpi` path
also failed an exploratory check, so they are not included in its passing
coverage. Passing a scalar or a legacy contiguous array does not establish
working `mpi_f08` array-descriptor support.

program mpi_array_smoke
  use mpi_f08
  implicit none
  integer, parameter :: n = 4
  integer :: ierr, rank, nprocs, rank_sum
  integer :: values(n), totals(n), expected(n), storage(2*n)

  call MPI_Init(ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
  call MPI_Comm_size(MPI_COMM_WORLD, nprocs, ierr)

  values = -1
  if (rank == 0) values = [11, 22, 33, 44]
  call MPI_Bcast(values, n, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)
  if (any(values /= [11, 22, 33, 44])) call MPI_Abort(MPI_COMM_WORLD, 1, ierr)

  values = rank + [1, 2, 3, 4]
  call MPI_Allreduce(values, totals, n, MPI_INTEGER, MPI_SUM, MPI_COMM_WORLD, ierr)
  rank_sum = nprocs * (nprocs - 1) / 2
  expected = rank_sum + nprocs * [1, 2, 3, 4]
  if (any(totals /= expected)) call MPI_Abort(MPI_COMM_WORLD, 2, ierr)

  storage = -9
  if (rank == 0) storage(1:2*n:2) = [11, 22, 33, 44]
  call MPI_Bcast(storage(1:2*n:2), n, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)
  if (any(storage(1:2*n:2) /= [11, 22, 33, 44])) call MPI_Abort(MPI_COMM_WORLD, 3, ierr)
  if (any(storage(2:2*n:2) /= -9)) call MPI_Abort(MPI_COMM_WORLD, 4, ierr)

  print *, 'rank', rank, 'of', nprocs, 'array checks passed'
  call MPI_Finalize(ierr)
end program

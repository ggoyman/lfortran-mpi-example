program mpi_smoke
  implicit none
  include 'mpif.h'
  integer :: ierr, rank, nprocs, total, expected
  call MPI_Init(ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
  call MPI_Comm_size(MPI_COMM_WORLD, nprocs, ierr)
  call MPI_Allreduce(rank, total, 1, MPI_INTEGER, MPI_SUM, MPI_COMM_WORLD, ierr)
  expected = nprocs * (nprocs - 1) / 2
  if (total /= expected) stop 1
  print *, 'rank', rank, 'of', nprocs, 'sum', total
  call MPI_Finalize(ierr)
end program

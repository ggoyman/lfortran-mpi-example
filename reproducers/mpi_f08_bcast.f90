program array_bcast
  use mpi_f08
  implicit none
  integer :: ierr, rank, a(4)
  call MPI_Init(ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
  a = -1
  if (rank == 0) a = [11, 22, 33, 44]
  call MPI_Bcast(a, 4, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)
  if (any(a /= [11, 22, 33, 44])) call MPI_Abort(MPI_COMM_WORLD, 1, ierr)
  print *, 'rank', rank, 'array broadcast passed'
  call MPI_Finalize(ierr)
end program

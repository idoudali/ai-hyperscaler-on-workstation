/*
 * MPI Hello World
 *
 * Simple MPI program that prints rank and hostname from each process.
 * Demonstrates basic MPI initialization and multi-node execution.
 *
 * Compile: mpicc -o hello hello.c
 * Run: mpirun -np 4 ./hello
 */

#include <mpi.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

#define MAX_HOSTNAME_LEN 256

int main(int argc, char** argv) {
    int world_size;  // Total number of processes
    int world_rank;  // Rank of this process
    char hostname[MAX_HOSTNAME_LEN];
    char processor_name[MPI_MAX_PROCESSOR_NAME];
    int name_len;

    // Initialize MPI environment
    MPI_Init(&argc, &argv);

    // Get total number of processes
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    // Get rank of current process
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    // Get processor name (hostname)
    MPI_Get_processor_name(processor_name, &name_len);

    // Also get hostname via system call for comparison
    if (gethostname(hostname, MAX_HOSTNAME_LEN) != 0) {
        strncpy(hostname, "unknown", MAX_HOSTNAME_LEN);
    }

    // Print message from each process
    printf("Hello from rank %d of %d processes on host %s (MPI processor: %s)\n",
           world_rank, world_size, hostname, processor_name);

    // Synchronize all processes
    MPI_Barrier(MPI_COMM_WORLD);

    // Rank 0 prints summary
    if (world_rank == 0) {
        printf("\n");
        printf("========================================\n");
        printf("MPI Hello World Summary\n");
        printf("========================================\n");
        printf("Total processes: %d\n", world_size);
        printf("Master rank: %d (on %s)\n", world_rank, hostname);
        printf("========================================\n");
    }

    // Finalize MPI environment
    MPI_Finalize();

    return 0;
}

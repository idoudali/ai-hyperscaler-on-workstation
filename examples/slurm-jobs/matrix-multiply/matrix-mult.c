/*
 * Parallel Matrix Multiplication using MPI
 *
 * Multiplies two square matrices using row-wise decomposition.
 * Demonstrates:
 * - Data distribution with MPI_Scatter
 * - Matrix operations
 * - Result gathering with MPI_Gather
 * - Memory-intensive parallel workload
 *
 * Algorithm: C = A × B
 * - Matrix A is distributed row-wise across processes
 * - Matrix B is broadcast to all processes
 * - Each process computes its assigned rows of C
 *
 * Compile: mpicc -o matrix-mult matrix-mult.c -lm
 * Run: mpirun -np 4 ./matrix-mult 1000
 */

#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// Initialize matrix with random values
void initialize_matrix(double *matrix, int rows, int cols, int rank) {
    srand(time(NULL) + rank);
    for (int i = 0; i < rows * cols; i++) {
        matrix[i] = (double)(rand() % 100) / 10.0;  // Values 0.0 to 9.9
    }
}

// Print matrix (for small matrices only)
void print_matrix(double *matrix, int rows, int cols, const char *name) {
    printf("\n%s (%dx%d):\n", name, rows, cols);
    if (rows > 10 || cols > 10) {
        printf("(Matrix too large to display - showing first 5x5)\n");
        rows = (rows < 5) ? rows : 5;
        cols = (cols < 5) ? cols : 5;
    }
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            printf("%6.2f ", matrix[i * cols + j]);
        }
        printf("\n");
    }
}

// Multiply matrices: C_local = A_local × B
void multiply_matrices(double *A_local, double *B, double *C_local,
                      int local_rows, int n) {
    for (int i = 0; i < local_rows; i++) {
        for (int j = 0; j < n; j++) {
            C_local[i * n + j] = 0.0;
            for (int k = 0; k < n; k++) {
                C_local[i * n + j] += A_local[i * n + k] * B[k * n + j];
            }
        }
    }
}

int main(int argc, char** argv) {
    int world_size, world_rank;
    int n;  // Matrix dimension (n×n matrices)
    double *A = NULL, *B = NULL, *C = NULL;  // Full matrices (rank 0 only)
    double *A_local, *B_local, *C_local;     // Local portions
    int local_rows;
    double start_time, end_time;

    // Initialize MPI
    MPI_Init(&argc, &argv);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    // Get matrix size from command line
    if (argc > 1) {
        n = atoi(argv[1]);
    } else {
        n = 100;  // Default size
    }

    // Validate matrix size
    if (n < world_size) {
        if (world_rank == 0) {
            printf("Error: Matrix size (%d) must be >= number of processes (%d)\n",
                   n, world_size);
        }
        MPI_Finalize();
        return 1;
    }

    if (n % world_size != 0) {
        if (world_rank == 0) {
            printf("Error: Matrix size (%d) must be divisible by number of processes (%d)\n",
                   n, world_size);
        }
        MPI_Finalize();
        return 1;
    }

    // Calculate local rows per process
    local_rows = n / world_size;

    // Print configuration
    if (world_rank == 0) {
        printf("========================================\n");
        printf("Parallel Matrix Multiplication\n");
        printf("========================================\n");
        printf("Matrix size: %d x %d\n", n, n);
        printf("Number of processes: %d\n", world_size);
        printf("Rows per process: %d\n", local_rows);
        printf("Total elements: %d\n", n * n);
        printf("Memory per matrix: %.2f MB\n", (n * n * sizeof(double)) / (1024.0 * 1024.0));
        printf("========================================\n");
        printf("\n");
    }

    // Allocate local arrays
    A_local = (double*)malloc(local_rows * n * sizeof(double));
    B_local = (double*)malloc(n * n * sizeof(double));  // Full B needed by all
    C_local = (double*)malloc(local_rows * n * sizeof(double));

    if (!A_local || !B_local || !C_local) {
        printf("Rank %d: Memory allocation failed\n", world_rank);
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    // Rank 0 initializes matrices
    if (world_rank == 0) {
        printf("Initializing matrices...\n");
        A = (double*)malloc(n * n * sizeof(double));
        B = (double*)malloc(n * n * sizeof(double));
        C = (double*)malloc(n * n * sizeof(double));

        if (!A || !B || !C) {
            printf("Memory allocation failed for full matrices\n");
            MPI_Abort(MPI_COMM_WORLD, 1);
        }

        initialize_matrix(A, n, n, world_rank);
        initialize_matrix(B, n, n, world_rank + 1);

        // Print small matrices for verification
        if (n <= 10) {
            print_matrix(A, n, n, "Matrix A");
            print_matrix(B, n, n, "Matrix B");
        }
        printf("\n");
    }

    // Start timing
    MPI_Barrier(MPI_COMM_WORLD);
    start_time = MPI_Wtime();

    // Distribute rows of A to all processes
    if (world_rank == 0) {
        printf("Distributing matrix A...\n");
    }
    MPI_Scatter(A, local_rows * n, MPI_DOUBLE,
                A_local, local_rows * n, MPI_DOUBLE,
                0, MPI_COMM_WORLD);

    // Broadcast matrix B to all processes
    if (world_rank == 0) {
        printf("Broadcasting matrix B...\n");
    }
    if (world_rank == 0) {
        // Copy B to B_local for rank 0
        for (int i = 0; i < n * n; i++) {
            B_local[i] = B[i];
        }
    }
    MPI_Bcast(B_local, n * n, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    // Each process computes its portion of C
    if (world_rank == 0) {
        printf("Computing matrix multiplication...\n");
    }
    multiply_matrices(A_local, B_local, C_local, local_rows, n);

    // Gather results back to rank 0
    if (world_rank == 0) {
        printf("Gathering results...\n");
    }
    MPI_Gather(C_local, local_rows * n, MPI_DOUBLE,
               C, local_rows * n, MPI_DOUBLE,
               0, MPI_COMM_WORLD);

    // Stop timing
    MPI_Barrier(MPI_COMM_WORLD);
    end_time = MPI_Wtime();

    // Print results
    if (world_rank == 0) {
        if (n <= 10) {
            print_matrix(C, n, n, "Result Matrix C");
        }

        printf("\n");
        printf("========================================\n");
        printf("Results\n");
        printf("========================================\n");
        printf("Computation time: %.3f seconds\n", end_time - start_time);

        // Calculate FLOPS (2*n^3 operations for matrix multiplication)
        double flops = 2.0 * n * n * n;
        double gflops = flops / (end_time - start_time) / 1e9;
        printf("Operations: %.2e FLOPS\n", flops);
        printf("Performance: %.2f GFLOPS\n", gflops);
        printf("========================================\n");
    }

    // Cleanup
    free(A_local);
    free(B_local);
    free(C_local);
    if (world_rank == 0) {
        free(A);
        free(B);
        free(C);
    }

    // Finalize MPI
    MPI_Finalize();

    return 0;
}

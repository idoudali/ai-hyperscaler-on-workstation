/*
 * Parallel Monte Carlo Pi Estimation using MPI
 *
 * Estimates the value of π using random sampling in a unit square.
 * Counts how many random points fall inside a quarter circle.
 *
 * π ≈ 4 * (points inside circle / total points)
 *
 * Demonstrates:
 * - Parallel random number generation
 * - Work distribution across processes
 * - MPI reduction for aggregating results
 * - Scaling with more processes
 *
 * Compile: mpicc -o pi-monte-carlo pi-monte-carlo.c -lm
 * Run: mpirun -np 4 ./pi-monte-carlo 10000000
 */

#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

// Default number of samples if not specified
#define DEFAULT_SAMPLES 10000000

// Monte Carlo estimation of Pi
long long count_circle_points(long long num_samples, int rank) {
    long long count = 0;
    double x, y, distance;

    // Seed random number generator with rank and time
    // This ensures each process generates different random numbers
    unsigned int seed = (unsigned int)(time(NULL) + rank);

    for (long long i = 0; i < num_samples; i++) {
        // Generate random point in unit square [0,1] x [0,1]
        x = (double)rand_r(&seed) / RAND_MAX;
        y = (double)rand_r(&seed) / RAND_MAX;

        // Check if point is inside unit circle
        distance = x * x + y * y;
        if (distance <= 1.0) {
            count++;
        }
    }

    return count;
}

int main(int argc, char** argv) {
    int world_size, world_rank;
    long long total_samples;
    long long samples_per_proc;
    long long local_count, global_count;
    double pi_estimate;
    double start_time, end_time;

    // Initialize MPI
    MPI_Init(&argc, &argv);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    // Get number of samples from command line or use default
    if (argc > 1) {
        total_samples = atoll(argv[1]);
    } else {
        total_samples = DEFAULT_SAMPLES;
    }

    // Ensure minimum samples per process
    if (total_samples < world_size) {
        if (world_rank == 0) {
            printf("Error: Total samples (%lld) must be >= number of processes (%d)\n",
                   total_samples, world_size);
        }
        MPI_Finalize();
        return 1;
    }

    // Divide work among processes
    samples_per_proc = total_samples / world_size;

    // Print configuration from rank 0
    if (world_rank == 0) {
        printf("========================================\n");
        printf("Parallel Monte Carlo Pi Estimation\n");
        printf("========================================\n");
        printf("Total samples: %lld\n", total_samples);
        printf("Number of processes: %d\n", world_size);
        printf("Samples per process: %lld\n", samples_per_proc);
        printf("========================================\n");
        printf("\n");
        fflush(stdout);
    }

    // Synchronize before starting computation
    MPI_Barrier(MPI_COMM_WORLD);
    start_time = MPI_Wtime();

    // Each process computes its portion
    local_count = count_circle_points(samples_per_proc, world_rank);

    // Print local results (optional - can be noisy with many processes)
    // printf("Rank %d: Local count = %lld (%.2f%% inside circle)\n",
    //        world_rank, local_count, 100.0 * local_count / samples_per_proc);

    // Reduce all local counts to global count on rank 0
    MPI_Reduce(&local_count, &global_count, 1, MPI_LONG_LONG,
               MPI_SUM, 0, MPI_COMM_WORLD);

    // Synchronize and measure time
    MPI_Barrier(MPI_COMM_WORLD);
    end_time = MPI_Wtime();

    // Rank 0 calculates and prints results
    if (world_rank == 0) {
        // Calculate pi estimate
        double actual_total = (double)(samples_per_proc * world_size);
        pi_estimate = 4.0 * global_count / actual_total;

        // Calculate error
        double pi_actual = M_PI;
        double error = fabs(pi_estimate - pi_actual);
        double percent_error = 100.0 * error / pi_actual;

        // Print results
        printf("========================================\n");
        printf("Results\n");
        printf("========================================\n");
        printf("Points inside circle: %lld\n", global_count);
        printf("Total points: %.0f\n", actual_total);
        printf("Pi estimate: %.10f\n", pi_estimate);
        printf("Actual Pi: %.10f\n", pi_actual);
        printf("Absolute error: %.10f\n", error);
        printf("Relative error: %.6f%%\n", percent_error);
        printf("========================================\n");
        printf("\n");

        printf("========================================\n");
        printf("Performance\n");
        printf("========================================\n");
        printf("Execution time: %.3f seconds\n", end_time - start_time);
        printf("Samples/second: %.2e\n", actual_total / (end_time - start_time));
        printf("Samples/second/process: %.2e\n",
               (actual_total / world_size) / (end_time - start_time));
        printf("========================================\n");
    }

    // Finalize MPI
    MPI_Finalize();

    return 0;
}

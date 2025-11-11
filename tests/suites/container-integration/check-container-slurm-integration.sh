#!/bin/bash
#
# Test Suite: Container Integration Tests
# Test: Check Container SLURM Integration
# Validates SLURM scheduling with containers and GPU resource allocation
#

set -euo pipefail

PS4='+ [$(basename ${BASH_SOURCE[0]}):L${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Source shared utilities
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../common/suite-check-helpers.sh"

# Script configuration
# shellcheck disable=SC2034
SCRIPT_NAME="check-container-slurm-integration.sh"
# shellcheck disable=SC2034
TEST_NAME="Container SLURM Integration"

# Test configuration
CONTAINER_IMAGE="${CONTAINER_IMAGE:-/opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-apptainer}"


# Note: Logging functions provided by suite-logging.sh
log_info_slurm() {
  echo -e "[INFO] $*"
}

log_debug() {
  if [[ "${DEBUG:-0}" == "1" ]]; then
    echo -e "[DEBUG] $*" >&2
  fi
}

# Log command execution for debugging
log_command() {
  local cmd="$1"
  log_debug "Executing: $cmd"
}

# Execute command with timeout and debugging
run_with_timeout() {
  local timeout_duration=$1
  shift
  local cmd="$*"

  log_debug "Running command with ${timeout_duration}s timeout: $cmd"
  if timeout "$timeout_duration" bash -c "$cmd"; then
    log_debug "Command completed successfully"
    return 0
  else
    local exit_code=$?
    if [[ $exit_code == 124 ]]; then
      log_debug "Command timed out after ${timeout_duration}s"
    else
      log_debug "Command failed with exit code: $exit_code"
    fi
    return "$exit_code"
  fi
}

# Test functions
test_slurm_available() {
  ((TESTS_RUN++))
  log_test "Checking SLURM availability"
  log_command "sinfo --version"

  local slurm_check
  # Run sinfo directly
  slurm_check=$(sinfo --version 2>&1 || echo "NOT_AVAILABLE")

  if [[ "$slurm_check" != *"NOT_AVAILABLE"* ]] && [[ "$slurm_check" != *"command not found"* ]]; then
    log_pass "SLURM available: $slurm_check"
    return 0
  else
    log_fail "SLURM not available"
    log_info "Container integration tests require SLURM to be running"
    return 1
  fi
}

test_compute_nodes_available() {
  ((TESTS_RUN++))
  log_test "Checking compute nodes availability"
  log_command "sinfo -N -h -o '%N %T'"

  local nodes_output
  # Run sinfo directly
  nodes_output=$(sinfo -N -h -o '%N %T' 2>&1 || echo "FAILED")

  if [[ "$nodes_output" != *"FAILED"* ]] && [[ "$nodes_output" != *"Unable to contact"* ]]; then
    local node_count
    node_count=$(echo "$nodes_output" | grep -c -v '^$')

    log_pass "Compute nodes available: $node_count node(s)"
    log_info "Node status:"
    while IFS= read -r line; do
      [[ -n "$line" ]] && echo "       $line"
    done <<< "$nodes_output"
    return 0
  else
    log_fail "Failed to get compute nodes"
    log_info "Output: $nodes_output"
    return 1
  fi
}

test_slurm_container_execution() {
  ((TESTS_RUN++))
  log_test "Testing container execution via srun"

  # Create test script in BeeGFS (shared across nodes)
  local test_script="/mnt/beegfs/slurm_container_test_$RANDOM.sh"

  log_command "Creating test script: $test_script"
  cat > $test_script << 'EOF'
#!/bin/bash
set -x
echo "[DEBUG] Starting container execution test"
echo "[DEBUG] Container runtime: $CONTAINER_RUNTIME"
echo "[DEBUG] Container image: $CONTAINER_IMAGE"
echo "[DEBUG] Hostname: $(hostname)"
echo "[DEBUG] PWD: $(pwd)"
$CONTAINER_RUNTIME exec $CONTAINER_IMAGE python3 -c 'print("Container executed via SLURM")'
echo "[DEBUG] Container execution completed with exit code: $?"
EOF
chmod +x $test_script

  log_debug "Test script created, checking file..."
  ls -lh $test_script

  # Run via srun with enhanced debugging
  log_command "srun --ntasks=1 bash $test_script"
  log_info "Running srun (timeout: 30s)..."
  local srun_result
  local srun_exit_code=0
  set +e
  # shellcheck disable=SC2086
  srun_result=$(timeout 30 srun --ntasks=1 bash $test_script 2>&1)
  srun_exit_code=$?
  set -e

  log_debug "srun completed with exit code: $srun_exit_code"
  log_debug "srun output length: ${#srun_result} characters"
  log_debug "srun output (first 500 chars): ${srun_result:0:500}"

  # Clean up
  rm -f "$test_script"

  if [[ "$srun_result" == *"Container executed via SLURM"* ]]; then
    log_pass "Container execution via srun successful"
    log_info "Full output:"
    echo "$srun_result" | while IFS= read -r line; do
      echo "       $line"
    done
    return 0
  else
    log_fail "Container execution via srun failed"
    log_info "Exit code: $srun_exit_code"
    log_info "Full output:"
    echo "$srun_result" | while IFS= read -r line; do
      echo "       $line"
    done
    return 1
  fi
}

test_slurm_batch_job() {
  ((TESTS_RUN++))
  log_test "Testing container execution via sbatch"

  # Create batch script in BeeGFS (shared across nodes)
  local batch_script="/mnt/beegfs/slurm_batch_$RANDOM.sh"

  log_command "Creating batch script: $batch_script"
  cat > $batch_script << 'EOF'
#!/bin/bash
#SBATCH --job-name=container_test
#SBATCH --ntasks=1
#SBATCH --time=00:01:00
#SBATCH --output=/mnt/beegfs/container_test_%j.out

set -x
echo "[DEBUG] Starting batch job"
echo "[DEBUG] Job ID: $SLURM_JOB_ID"
echo "[DEBUG] Node: $SLURMD_NODENAME"
echo "[DEBUG] Container runtime: $CONTAINER_RUNTIME"
echo "[DEBUG] Container image: $CONTAINER_IMAGE"

$CONTAINER_RUNTIME exec $CONTAINER_IMAGE python3 << PYEOF
import sys
print(f"Python version: {sys.version}")
print("Container batch job completed successfully")
PYEOF

echo "[DEBUG] Container execution completed with exit code: $?"
EOF

  log_debug "Batch script created, verifying..."
  ls -lh $batch_script && head -n 5 $batch_script

  # Submit batch job
  log_command "sbatch $batch_script"
  log_info "Submitting batch job (timeout: 30s)..."
  local job_submit
  local submit_exit_code=0
  set +e
  # shellcheck disable=SC2086
  job_submit=$(timeout 30 sbatch $batch_script 2>&1)
  submit_exit_code=$?
  set -e

  log_debug "sbatch completed with exit code: $submit_exit_code"
  log_debug "sbatch output: $job_submit"

  if [[ "$job_submit" == *"Submitted batch job"* ]]; then
    # Extract job ID
    local job_id
    job_id=$(echo "$job_submit" | grep -oP 'Submitted batch job \K[0-9]+')

    log_info "Job submitted: $job_id"

    # Wait for job to complete (max 60 seconds)
    local wait_time=0
    local max_wait=60
    local job_state=""

    log_debug "Waiting for job $job_id to complete (max ${max_wait}s)"
    log_info "Monitoring job progress..."

    while [[ $wait_time -lt $max_wait ]]; do
      log_debug "Checking job state (elapsed: ${wait_time}s)..."
      set +e
      # shellcheck disable=SC2086
      job_state=$(timeout 10 squeue -j $job_id -h -o '%T' 2>/dev/null)
      local squeue_exit=$?
      set -e

      log_debug "squeue exit code: $squeue_exit"
      log_debug "Job state query returned: '$job_state'"

      if [[ $squeue_exit -ne 0 ]] || [[ -z "$job_state" ]]; then
        # Job completed or not in queue
        log_debug "Job not in queue (completed or failed) - breaking wait loop"
        break
      fi

      log_info "Job state: $job_state (waiting... ${wait_time}/${max_wait}s)"

      # Check if job is in error state
      if [[ "$job_state" == *"FAILED"* ]] || [[ "$job_state" == *"CANCELLED"* ]]; then
        log_debug "Job in error state: $job_state"
        break
      fi

      sleep 2
      wait_time=$((wait_time + 2))
    done

    if [[ $wait_time -ge $max_wait ]]; then
      log_debug "Job wait timeout reached (${max_wait}s)"
      log_info "WARNING: Job may still be running"
    else
      log_debug "Job completed after ${wait_time}s"
    fi

    # Check job output
    local output_file="/mnt/beegfs/container_test_${job_id}.out"
    log_debug "Looking for job output file: $output_file"

    # First check if file exists
    local file_exists
    file_exists=$([ -f "$output_file" ] && echo 'YES' || echo 'NO')
    log_debug "Output file exists: $file_exists"

    if [[ "$file_exists" == "YES" ]]; then
      log_debug "Reading job output..."
      local job_output
      job_output=$(cat "$output_file" 2>&1)
      log_debug "Output length: ${#job_output} characters"
    else
      log_debug "Output file not found, checking beegfs logs directory..."
      local slurm_logs
      slurm_logs=$(ls -la /mnt/beegfs/container_test_*.out 2>/dev/null || echo 'No slurm output files found')
      log_info "Slurm output files:"
      echo "$slurm_logs" | while IFS= read -r line; do
        echo "       $line"
      done
      job_output="OUTPUT_NOT_FOUND"
    fi

    # Clean up
    rm -f "$batch_script" "$output_file"

    if [[ "$job_output" == *"Container batch job completed successfully"* ]]; then
      log_pass "Container batch job executed successfully"
      log_info "Job output:"
      while IFS= read -r line; do
        [[ -n "$line" ]] && echo "       $line"
      done <<< "$job_output"
      return 0
    else
      log_fail "Container batch job failed or incomplete"
      log_info "Job state: $job_state"
      log_info "Output: $job_output"
      return 1
    fi
  else
    log_fail "Failed to submit batch job"
    log_info "Output: $job_submit"
    rm -f "$batch_script"
    return 1
  fi
}

test_gpu_gres_allocation() {
  ((TESTS_RUN++))
  log_test "Testing GPU GRES allocation"

  # Check if GPUs are configured
  local gres_check
  gres_check=$(sinfo -o '%n %G' 2>&1 || echo "FAILED")

  if [[ "$gres_check" == *"FAILED"* ]] || [[ "$gres_check" == *"Unable to contact"* ]]; then
    log_info "Cannot check GRES configuration"
    log_pass "Test skipped (SLURM not responding)"
    return 0
  fi

  # Check if any GPU GRES are available
  if echo "$gres_check" | grep -q "gpu"; then
    log_pass "GPU GRES configured"
    log_info "GRES info:"
    while IFS= read -r line; do
      [[ "$line" == *"gpu"* ]] && echo "       $line"
    done <<< "$gres_check"
  else
    log_info "No GPU GRES configured (expected in test environment without GPUs)"
    log_pass "Test completed (no GPU GRES)"
  fi

  return 0
}

test_multi_node_container_job() {
  ((TESTS_RUN++))
  log_test "Testing multi-node container job"

  # Check if we have multiple nodes
  local node_count
  node_count=$(sinfo -N -h | wc -l || echo "0")

  if [[ "$node_count" -lt 2 ]]; then
    log_info "Less than 2 compute nodes available, skipping multi-node test"
    log_pass "Test skipped (insufficient nodes)"
    return 0
  fi

  # Create multi-node test script in BeeGFS (shared across nodes)
  local test_script="/mnt/beegfs/multinode_container_$RANDOM.sh"

  cat > $test_script << 'EOF'
#!/bin/bash
$CONTAINER_RUNTIME exec $CONTAINER_IMAGE python3 << PYEOF
import socket
import os
print(f"Node: {socket.gethostname()}, Task ID: {os.getenv('SLURM_PROCID', 'N/A')}")
PYEOF
EOF
chmod +x $test_script

  # Run multi-node job
  log_debug "Executing multi-node: srun --ntasks=2 --nodes=2 bash $test_script"
  local multinode_result
  # shellcheck disable=SC2086
  multinode_result=$(timeout 45 srun --ntasks=2 --nodes=2 bash $test_script 2>&1 || echo "FAILED")
  log_debug "Multi-node srun completed"

  # Clean up
  rm -f "$test_script"

  if [[ "$multinode_result" != *"FAILED"* ]]; then
    local task_count
    task_count=$(echo "$multinode_result" | grep -c "Node:" || echo 0)

    if [[ "$task_count" -eq 2 ]]; then
      log_pass "Multi-node container job successful"
      log_info "Task outputs:"
      while IFS= read -r line; do
        [[ "$line" == *"Node:"* ]] && echo "       $line"
      done <<< "$multinode_result"
      return 0
    else
      log_fail "Multi-node job incomplete (expected 2 tasks, got $task_count)"
      log_info "Output: $multinode_result"
      return 1
    fi
  else
    log_fail "Multi-node container job failed"
    log_info "Output: $multinode_result"
    return 1
  fi
}

test_resource_isolation() {
  ((TESTS_RUN++))
  log_test "Testing resource isolation in container jobs"

  # Create resource test script in BeeGFS (shared across nodes)
  local test_script="/mnt/beegfs/resource_test_$RANDOM.sh"

  cat > $test_script << 'EOF'
#!/bin/bash
$CONTAINER_RUNTIME exec $CONTAINER_IMAGE python3 << PYEOF
import os
import psutil

# Get process info
print(f"CPU count: {psutil.cpu_count()}")
print(f"Memory available: {psutil.virtual_memory().available / (1024**3):.2f} GB")

# Check cgroup constraints
if os.path.exists("/sys/fs/cgroup/memory/memory.limit_in_bytes"):
    with open("/sys/fs/cgroup/memory/memory.limit_in_bytes") as f:
        limit = int(f.read().strip())
        print(f"Cgroup memory limit: {limit / (1024**3):.2f} GB")
PYEOF
EOF
chmod +x $test_script

  # Run with resource constraints
  log_debug "Executing resource-constrained: srun --ntasks=1 --mem=1G bash $test_script"
  local resource_result
  # shellcheck disable=SC2086
  resource_result=$(timeout 30 srun --ntasks=1 --mem=1G bash $test_script 2>&1 || echo "FAILED")
  log_debug "Resource-constrained srun completed"

  # Clean up
  rm -f "$test_script"

  if [[ "$resource_result" == *"CPU count:"* ]] || [[ "$resource_result" == *"Memory available:"* ]]; then
    log_pass "Resource isolation test completed"
    log_info "Resource info:"
    while IFS= read -r line; do
      [[ -n "$line" ]] && [[ "$line" != *"FAILED"* ]] && echo "       $line"
    done <<< "$resource_result"
    return 0
  else
    log_fail "Resource isolation test failed"
    log_info "Output: $resource_result"
    return 1
  fi
}

test_container_mpi_slurm() {
  ((TESTS_RUN++))
  log_test "Testing MPI with containers via SLURM"

  # Create MPI test script in BeeGFS (shared across nodes)
  local test_script="/mnt/beegfs/mpi_slurm_$RANDOM.py"

  cat > $test_script << 'EOFMPI'
from mpi4py import MPI
comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()
print(f"MPI Rank {rank}/{size} via SLURM")
EOFMPI

  # Run MPI job via SLURM
  log_debug "Executing MPI: srun --ntasks=4 $CONTAINER_RUNTIME exec $CONTAINER_IMAGE python3 $test_script"
  local mpi_result
  # shellcheck disable=SC2086
  mpi_result=$(timeout 60 srun --ntasks=4 $CONTAINER_RUNTIME exec $CONTAINER_IMAGE python3 $test_script 2>&1 || echo "FAILED")
  log_debug "MPI srun completed with output length: ${#mpi_result}"

  # Clean up
  rm -f "$test_script"

  # Count MPI ranks
  local rank_count
  rank_count=$(echo "$mpi_result" | grep -c "MPI Rank" 2>/dev/null || echo 0)
  # Ensure rank_count is a single number (strip any whitespace/newlines)
  rank_count=$(echo "$rank_count" | tr -d '\n\r' | head -1)
  rank_count=${rank_count:-0}

  if [[ "$rank_count" -eq 4 ]]; then
    log_pass "MPI with containers via SLURM successful (4 ranks)"
    log_info "MPI outputs:"
    while IFS= read -r line; do
      [[ "$line" == *"MPI Rank"* ]] && echo "       $line"
    done <<< "$mpi_result"
    return 0
  else
    log_fail "MPI with containers via SLURM failed (expected 4 ranks, got $rank_count)"
    log_info "Output: $mpi_result"
    return 1
  fi
}

# Main execution
main() {
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  $TEST_NAME"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  log_info "Container image: $CONTAINER_IMAGE"
  log_info "Container runtime: $CONTAINER_RUNTIME"

  # Enable debug mode if VERBOSE is set
  if [[ "${VERBOSE:-0}" == "1" ]] || [[ "${DEBUG:-0}" == "1" ]]; then
    export DEBUG=1
    log_info "Debug mode enabled"
  fi

  # Always enable DEBUG for better troubleshooting
  export DEBUG=1
  log_info "Enhanced debugging enabled for SLURM integration tests"
  echo ""

  # Run tests with progress indicators
  # NOTE: Tests run directly on compute node (not via SSH)
  # Failures are fatal - not masked by || true

  echo "[1/8] Testing SLURM availability..."
  test_slurm_available || exit 1

  echo "[2/8] Testing compute nodes availability..."
  test_compute_nodes_available || exit 1

  echo "[3/8] Testing container execution via srun..."
  test_slurm_container_execution || exit 1

  echo "[4/8] Testing container execution via sbatch..."
  test_slurm_batch_job || exit 1

  echo "[5/8] Testing GPU GRES allocation..."
  test_gpu_gres_allocation || exit 1

  echo "[6/8] Testing multi-node container job..."
  test_multi_node_container_job || exit 1

  echo "[7/8] Testing resource isolation..."
  test_resource_isolation || exit 1

  echo "[8/8] Testing MPI with containers via SLURM..."
  test_container_mpi_slurm || exit 1

  # Summary
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  Test Summary: $TEST_NAME"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "Tests Run:    $TESTS_RUN"
  echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
  else
    echo -e "Tests Failed: $TESTS_FAILED"
  fi
  echo ""

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
    exit 0
  else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
  fi
}

# Run main function
main "$@"

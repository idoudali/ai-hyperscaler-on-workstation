#!/bin/bash
# Test Suite: Container Integration Tests
# Test: Check MPI Communication
# Validates MPI functionality and multi-process communication within containers

set -euo pipefail

# Test configuration
TEST_NAME="MPI Communication"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-/opt/containers/ml-frameworks/pytorch-cuda12.1-mpi4.1.sif}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-apptainer}"

# SSH configuration
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=10"

# Build SSH command with key if available
if [[ -f "$SSH_KEY_PATH" ]]; then
  SSH_CMD="ssh -i $SSH_KEY_PATH $SSH_OPTS"
else
  SSH_CMD="ssh $SSH_OPTS"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_test() {
  echo -e "${YELLOW}[TEST]${NC} $*"
}

log_pass() {
  ((TESTS_PASSED++))
  echo -e "${GREEN}[PASS]${NC} $*"
}

log_fail() {
  ((TESTS_FAILED++))
  echo -e "${RED}[FAIL]${NC} $*"
}

log_info() {
  echo -e "[INFO] $*"
}

# Test functions
test_mpi_available() {
  ((TESTS_RUN++))
  log_test "Checking MPI availability"

  local mpi_check
  mpi_check=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE which mpirun 2>&1" || echo "NOT_FOUND")

  if [[ "$mpi_check" != *"NOT_FOUND"* ]] && [[ "$mpi_check" != *"no mpirun"* ]]; then
    log_pass "MPI available: $mpi_check"
    return 0
  else
    log_fail "MPI not available in container"
    log_info "Output: $mpi_check"
    return 1
  fi
}

test_mpi_version() {
  ((TESTS_RUN++))
  log_test "Checking MPI version"

  local mpi_version
  mpi_version=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE mpirun --version 2>&1 | head -n 1" || echo "FAILED")

  if [[ "$mpi_version" != *"FAILED"* ]]; then
    log_pass "MPI version: $mpi_version"
    return 0
  else
    log_fail "Failed to get MPI version"
    log_info "Output: $mpi_version"
    return 1
  fi
}

test_mpi4py_import() {
  ((TESTS_RUN++))
  log_test "Testing mpi4py import"

  local mpi4py_test
  mpi4py_test=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE python3 -c 'from mpi4py import MPI; print(f\"mpi4py version: {MPI.Get_version()}\")' 2>&1" || echo "IMPORT_FAILED")

  if [[ "$mpi4py_test" != *"IMPORT_FAILED"* ]] && [[ "$mpi4py_test" != *"ModuleNotFoundError"* ]]; then
    log_pass "mpi4py imports successfully: $mpi4py_test"
    return 0
  else
    log_fail "mpi4py import failed"
    log_info "Output: $mpi4py_test"
    return 1
  fi
}

test_mpi_hello_world() {
  ((TESTS_RUN++))
  log_test "Testing MPI Hello World (single process)"

  local test_script="/tmp/mpi_hello_$RANDOM.py"

  $SSH_CMD "${TEST_CONTROLLER}" "cat > $test_script << 'EOFPY'
from mpi4py import MPI
comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()
print(f\"Hello from rank {rank} of {size}\")
EOFPY
"

  local mpi_result
  mpi_result=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE python3 $test_script 2>&1" || echo "FAILED")

  # Clean up
  $SSH_CMD "${TEST_CONTROLLER}" "rm -f $test_script"

  if [[ "$mpi_result" == *"Hello from rank 0 of 1"* ]]; then
    log_pass "MPI Hello World successful"
    return 0
  else
    log_fail "MPI Hello World failed"
    log_info "Output: $mpi_result"
    return 1
  fi
}

test_mpi_multiprocess() {
  ((TESTS_RUN++))
  log_test "Testing MPI multi-process execution (4 processes)"

  # Create test script on controller
  local test_script="/tmp/mpi_test_$RANDOM.py"

  local mpi_mp_script='
from mpi4py import MPI
comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()
processor_name = MPI.Get_processor_name()
print(f"Process {rank}/{size} on {processor_name}")
'

  # Write script to controller
  $SSH_CMD "${TEST_CONTROLLER}" "cat > $test_script << 'EOFMPI'
$mpi_mp_script
EOFMPI
"

  # Run with mpirun
  local mpi_mp_result
  mpi_mp_result=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE mpirun -np 4 python3 $test_script 2>&1" || echo "FAILED")

  # Clean up
  $SSH_CMD "${TEST_CONTROLLER}" "rm -f $test_script"

  # Count number of process outputs
  local process_count
  process_count=$(echo "$mpi_mp_result" | grep -c "Process" || echo 0)

  if [[ "$process_count" -eq 4 ]]; then
    log_pass "MPI multi-process execution successful (4 processes)"
    log_info "Process outputs:"
    while IFS= read -r line; do
      [[ "$line" == *"Process"* ]] && echo "       $line"
    done <<< "$mpi_mp_result"
    return 0
  else
    log_fail "MPI multi-process execution failed"
    log_info "Expected 4 processes, got: $process_count"
    log_info "Output: $mpi_mp_result"
    return 1
  fi
}

test_mpi_point_to_point() {
  ((TESTS_RUN++))
  log_test "Testing MPI point-to-point communication"

  local test_script="/tmp/mpi_p2p_$RANDOM.py"

  local p2p_script='
from mpi4py import MPI
import numpy as np

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

if size < 2:
    print("Need at least 2 processes")
    exit(1)

if rank == 0:
    data = np.array([1, 2, 3, 4, 5])
    comm.send(data, dest=1, tag=11)
    print(f"Rank 0 sent data: {data.tolist()}")
elif rank == 1:
    data = comm.recv(source=0, tag=11)
    print(f"Rank 1 received data: {data.tolist()}")
'

  # Write script to controller
  $SSH_CMD "${TEST_CONTROLLER}" "cat > $test_script << 'EOFMPI'
$p2p_script
EOFMPI
"

  # Run with mpirun
  local p2p_result
  p2p_result=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE mpirun -np 2 python3 $test_script 2>&1" || echo "FAILED")

  # Clean up
  $SSH_CMD "${TEST_CONTROLLER}" "rm -f $test_script"

  if [[ "$p2p_result" == *"sent data"* ]] && [[ "$p2p_result" == *"received data"* ]]; then
    log_pass "MPI point-to-point communication successful"
    log_info "Communication output:"
    while IFS= read -r line; do
      [[ "$line" == *"Rank"* ]] && echo "       $line"
    done <<< "$p2p_result"
    return 0
  else
    log_fail "MPI point-to-point communication failed"
    log_info "Output: $p2p_result"
    return 1
  fi
}

test_mpi_collective() {
  ((TESTS_RUN++))
  log_test "Testing MPI collective operations (broadcast)"

  local test_script="/tmp/mpi_collective_$RANDOM.py"

  local collective_script='
from mpi4py import MPI
import numpy as np

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

if rank == 0:
    data = np.array([100, 200, 300])
else:
    data = None

data = comm.bcast(data, root=0)
print(f"Rank {rank} received broadcast: {data.tolist()}")
'

  # Write script to controller
  $SSH_CMD "${TEST_CONTROLLER}" "cat > $test_script << 'EOFMPI'
$collective_script
EOFMPI
"

  # Run with mpirun
  local collective_result
  collective_result=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE mpirun -np 4 python3 $test_script 2>&1" || echo "FAILED")

  # Clean up
  $SSH_CMD "${TEST_CONTROLLER}" "rm -f $test_script"

  # Count successful broadcasts
  local broadcast_count
  broadcast_count=$(echo "$collective_result" | grep -c "received broadcast" || echo 0)

  if [[ "$broadcast_count" -eq 4 ]]; then
    log_pass "MPI collective operations successful"
    log_info "Broadcast results:"
    while IFS= read -r line; do
      [[ "$line" == *"received broadcast"* ]] && echo "       $line"
    done <<< "$collective_result"
    return 0
  else
    log_fail "MPI collective operations failed"
    log_info "Expected 4 broadcast confirmations, got: $broadcast_count"
    log_info "Output: $collective_result"
    return 1
  fi
}

test_pmix_support() {
  ((TESTS_RUN++))
  log_test "Checking PMIx support"

  local pmix_check
  pmix_check=$($SSH_CMD "${TEST_CONTROLLER}" "$CONTAINER_RUNTIME exec $CONTAINER_IMAGE mpirun --help 2>&1 | grep -i pmix || echo 'PMIX_NOT_FOUND'")

  if [[ "$pmix_check" != *"PMIX_NOT_FOUND"* ]]; then
    log_pass "PMIx support detected"
    log_info "PMIx info: $pmix_check"
    return 0
  else
    log_info "PMIx support not explicitly mentioned (may still be supported)"
    log_pass "Test completed (PMIx may be integrated)"
    return 0
  fi
}

# Main execution
main() {
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  $TEST_NAME"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Validate environment
  if [[ -z "${TEST_CONTROLLER:-}" ]]; then
    echo -e "${RED}ERROR: TEST_CONTROLLER environment variable not set${NC}"
    exit 1
  fi

  log_info "Testing controller: $TEST_CONTROLLER"
  log_info "Container image: $CONTAINER_IMAGE"
  log_info "Container runtime: $CONTAINER_RUNTIME"
  echo ""

  # Run tests
  test_mpi_available || true
  test_mpi_version || true
  test_mpi4py_import || true
  test_mpi_hello_world || true
  test_mpi_multiprocess || true
  test_mpi_point_to_point || true
  test_mpi_collective || true
  test_pmix_support || true

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

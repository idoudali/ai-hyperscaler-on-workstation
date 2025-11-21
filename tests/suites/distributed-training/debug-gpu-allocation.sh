#!/bin/bash
# Debug SLURM GPU allocation failures
# Helps identify why GPU resource requests fail

set -euo pipefail

# Initialize test result variables
single_gpu_test_passed=false
multi_node_test_passed=false

echo "=========================================="
echo "SLURM GPU Allocation Debugging Tool"
echo "=========================================="
echo ""

# 1. Check SLURM cluster status
echo "1. SLURM Cluster Status:"
echo "-----------------------"
if command -v sinfo >/dev/null 2>&1; then
    sinfo
else
    echo "✗ sinfo command not available"
    exit 1
fi
echo ""

# 2. Detailed node information with GPU resources
echo "2. Node Details with GPU Resources:"
echo "------------------------------------"
echo "Format: NodeName | State | CPUs | Memory | GRES (GPUs)"
sinfo -o "%N %t %C %m %G" -N
echo ""

# 3. Check each compute node individually
echo "3. Individual Node GPU Configuration:"
echo "--------------------------------------"
if command -v scontrol >/dev/null 2>&1; then
    # Get all compute nodes
    nodes=$(sinfo -h -o "%N" -t idle,alloc,mixed,down,drain 2>/dev/null | tr ',' '\n' | sort -u)

    if [ -z "$nodes" ]; then
        echo "✗ No compute nodes found"
    else
        for node in $nodes; do
            echo ""
            echo "Node: $node"
            echo "---"
            if node_info=$(scontrol show node "$node" 2>&1); then
                # Extract key information
                echo "$node_info" | grep -E "^(NodeName|State|CPUTot|RealMemory|Gres|AllocTRES|CfgTRES)" || true
            else
                echo "✗ Failed to get node info: $node_info"
            fi
        done
    fi
else
    echo "✗ scontrol command not available"
fi
echo ""

# 4. Check GRES configuration
echo "4. GRES Configuration Check:"
echo "---------------------------"
if [ -f /etc/slurm/gres.conf ]; then
    echo "✓ gres.conf exists:"
    cat /etc/slurm/gres.conf
else
    echo "✗ gres.conf not found at /etc/slurm/gres.conf"
    echo "  Checking alternative locations..."
    for path in /usr/local/etc/slurm/gres.conf /opt/slurm/etc/gres.conf; do
        if [ -f "$path" ]; then
            echo "  Found at: $path"
            cat "$path"
            break
        fi
    done
fi
echo ""

# 5. Check slurm.conf for GresTypes
echo "5. SLURM Configuration (GresTypes):"
echo "-----------------------------------"
if [ -f /etc/slurm/slurm.conf ]; then
    echo "Checking for GresTypes in slurm.conf:"
    grep -i "GresTypes" /etc/slurm/slurm.conf || echo "✗ GresTypes not configured in slurm.conf"
else
    echo "✗ slurm.conf not found at /etc/slurm/slurm.conf"
fi
echo ""

# 6. Test single GPU allocation
echo "6. Testing Single GPU Allocation:"
echo "---------------------------------"
echo "Attempting: srun --nodes=1 --gres=gpu:1 --time=5 hostname"
set +e  # Allow commands to fail without exiting
if srun --nodes=1 --gres=gpu:1 --time=5 hostname 2>&1; then
    echo "✓ Single GPU allocation successful"
    single_gpu_test_passed=true
else
    exit_code=$?
    echo "✗ Single GPU allocation failed (exit code: $exit_code)"
    echo ""
    echo "Debugging single GPU allocation..."
    echo "  - Checking if any nodes have GPUs available..."
    sinfo -N -o "%N %G" 2>/dev/null | grep -vi "null" | grep -v "NODELIST" | sort -u || echo "    No nodes with GPU GRES found"
    single_gpu_test_passed=false
fi
set -e  # Re-enable exit on error
echo ""

# 7. Test multi-node allocation (what's failing)
echo "7. Testing Multi-Node GPU Allocation:"
echo "-------------------------------------"
echo "Attempting: srun --nodes=2 --ntasks=2 --gres=gpu:1 --time=5 hostname"
set +e  # Allow commands to fail without exiting
if srun --nodes=2 --ntasks=2 --gres=gpu:1 --time=5 hostname 2>&1; then
    echo "✓ Multi-node GPU allocation successful"
    multi_node_test_passed=true
else
    exit_code=$?
    echo "✗ Multi-node GPU allocation failed (exit code: $exit_code)"
    echo ""
    echo "Analyzing failure reason..."

    # Count UNIQUE nodes with GPU resources (nodes appear in multiple partitions)
    gpu_nodes_count=$(sinfo -h -N -o "%N %G" 2>/dev/null | grep -vi "null" | grep -i "gpu" | awk '{print $1}' | sort -u | wc -l)
    echo "  - Nodes with GPU GRES configured: $gpu_nodes_count"

    # Count available UNIQUE nodes
    available_nodes_count=$(sinfo -h -N -t idle,alloc,mixed -o "%N" 2>/dev/null | sort -u | wc -l)
    echo "  - Available nodes (idle/alloc/mixed): $available_nodes_count"

    # Check if we have enough nodes
    if [ "$available_nodes_count" -lt 2 ]; then
        echo "  ✗ Insufficient nodes: Need 2, have $available_nodes_count"
    fi

    # Check if nodes have GPUs
    echo "  - Checking GPU availability per node..."
    sinfo -o "%N %G %t" -N 2>/dev/null | grep -v "NODELIST" | while read -r line; do
        node=$(echo "$line" | awk '{print $1}')
        gres=$(echo "$line" | awk '{print $2}')
        state=$(echo "$line" | awk '{print $3}')
        if echo "$gres" | grep -qi "gpu"; then
            echo "    ✓ $node: $gres (state: $state)"
        else
            echo "    ✗ $node: No GPU GRES (gres: $gres, state: $state)"
        fi
    done
    multi_node_test_passed=false
fi
set -e  # Re-enable exit on error
echo ""

# 8. Check partition configuration
echo "8. Partition Configuration:"
echo "---------------------------"
if command -v scontrol >/dev/null 2>&1; then
    scontrol show partition 2>/dev/null | head -20
else
    echo "✗ scontrol command not available"
fi
echo ""

# 9. Check for running/pending jobs
echo "9. Current Job Queue:"
echo "---------------------"
if command -v squeue >/dev/null 2>&1; then
    echo "Format: JobID | Partition | Name | User | State | Nodes | GRES"
    squeue -o "%.18i %.9P %.20j %.8u %.2t %.6D %b" 2>/dev/null | head -10
    job_count=$(squeue -h 2>/dev/null | wc -l)
    echo "Total jobs in queue: $job_count"
else
    echo "✗ squeue command not available"
fi
echo ""

# 10. Physical GPU detection (on compute nodes)
echo "10. Physical GPU Detection (if on compute node):"
echo "-----------------------------------------------"
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "✓ nvidia-smi available:"
    nvidia-smi --query-gpu=index,name,driver_version,memory.total --format=csv,noheader 2>/dev/null || echo "  No GPUs detected or driver not loaded"
elif [ -d /dev ]; then
    nvidia_devices=$(find /dev -maxdepth 1 -name "nvidia*" 2>/dev/null | wc -l)
    if [ "$nvidia_devices" -gt 0 ]; then
        echo "✓ NVIDIA devices found: $nvidia_devices"
        find /dev -maxdepth 1 -name "nvidia*" -exec ls -la {} + 2>/dev/null | head -5
    else
        echo "✗ No /dev/nvidia* devices found"
    fi
else
    echo "⚠ Cannot check physical GPUs (not on compute node or nvidia-smi not available)"
fi
echo ""

# 11. Summary and recommendations
# Always run summary, even if earlier tests failed
set +e  # Disable exit on error for summary section
echo "=========================================="
echo "Summary and Recommendations:"
echo "=========================================="
echo ""

# Count resources (handle potential failures gracefully)
# Note: nodes appear multiple times in partitions, so we count unique node names
total_nodes=$(sinfo -h -N -o "%N" 2>/dev/null | sort -u | wc -l || echo "0")
# Count UNIQUE nodes with GPUs (nodes appear multiple times in partitions)
gpu_nodes=$(sinfo -h -N -o "%N %G" 2>/dev/null | grep -vi "null" | grep -i "gpu" | awk '{print $1}' | sort -u | wc -l || echo "0")
available_nodes=$(sinfo -h -N -t idle,alloc,mixed -o "%N" 2>/dev/null | sort -u | wc -l || echo "0")

# Ensure values are numeric
total_nodes=$((total_nodes + 0))
gpu_nodes=$((gpu_nodes + 0))
available_nodes=$((available_nodes + 0))

echo "Cluster Summary:"
echo "  - Total nodes: $total_nodes"
echo "  - Nodes with GPU GRES: $gpu_nodes"
echo "  - Available nodes: $available_nodes"
echo ""

# Test results summary
if [ "${single_gpu_test_passed:-false}" = "true" ]; then
    echo "✓ Single GPU allocation test: PASSED"
else
    echo "✗ Single GPU allocation test: FAILED"
fi

if [ "${multi_node_test_passed:-false}" = "true" ]; then
    echo "✓ Multi-node GPU allocation test: PASSED"
else
    echo "✗ Multi-node GPU allocation test: FAILED"
fi
echo ""

# Problem diagnosis and solutions
if [ "$gpu_nodes" -eq 0 ]; then
    echo "✗ PROBLEM: No nodes have GPU GRES configured"
    echo ""
    echo "ROOT CAUSE:"
    echo "  - gres.conf file is missing or not configured on compute nodes"
    echo "  - SLURM cannot allocate GPU resources without GRES configuration"
    echo ""
    echo "SOLUTION:"
    echo "  1. Create /etc/slurm/gres.conf on each compute node with GPU devices"
    echo "     Example:"
    echo "       NodeName=compute-01 Name=gpu Type=gpu File=/dev/nvidia0"
    echo "       NodeName=compute-02 Name=gpu Type=gpu File=/dev/nvidia0"
    echo ""
    echo "  2. Ensure GresTypes=gpu is in /etc/slurm/slurm.conf (already configured ✓)"
    echo ""
    echo "  3. Restart slurmd on compute nodes:"
    echo "     sudo systemctl restart slurmd"
    echo ""
    echo "  4. Restart slurmctld on controller:"
    echo "     sudo systemctl restart slurmctld"
    echo ""
    echo "  5. Verify configuration:"
    echo "     sinfo -o '%N %G'"
    echo "     scontrol show node <node-name> | grep Gres"
    echo ""
    echo "QUICK FIX:"
    echo "  Run the fix script: ./tests/suites/distributed-training/fix-gpu-gres.sh"
elif [ "$available_nodes" -lt 2 ]; then
    echo "✗ PROBLEM: Insufficient available nodes for multi-node job"
    echo "  Need: 2 nodes, Available: $available_nodes"
    echo ""
    echo "SOLUTION:"
    echo "  1. Check node states: sinfo -Nel"
    echo "  2. If nodes are DOWN/DRAIN, investigate and bring them up:"
    echo "     sudo scontrol update NodeName=<node> State=RESUME"
    echo "  3. Wait for running jobs to complete"
    echo "  4. Check for resource conflicts"
elif [ "$gpu_nodes" -lt 2 ]; then
    echo "✗ PROBLEM: Not enough nodes have GPU GRES configured"
    echo "  Need: 2 nodes with GPUs, Configured: $gpu_nodes"
    echo ""
    echo "SOLUTION:"
    echo "  1. Configure GPU GRES on more compute nodes"
    echo "  2. Check /etc/slurm/gres.conf on each compute node"
    echo "  3. Ensure GPU devices exist: ls -la /dev/nvidia*"
    echo "  4. Restart slurmd after configuration changes:"
    echo "     sudo systemctl restart slurmd"
else
    echo "✓ Cluster appears to have sufficient GPU resources"
    echo "  - $gpu_nodes nodes with GPU GRES configured"
    echo "  - $available_nodes nodes available"
    echo ""
    if [ "${multi_node_test_passed:-false}" != "true" ]; then
        echo "⚠ However, multi-node allocation test failed"
        echo ""
        echo "Possible causes:"
        echo "  1. All GPUs may be allocated to other jobs"
        echo "  2. Node states may be DRAIN or DOWN"
        echo "  3. Partition configuration may restrict access"
        echo "  4. Check for job conflicts: squeue"
        echo ""
        echo "Debugging steps:"
        echo "  1. Check detailed node info: scontrol show node <node-name>"
        echo "  2. Check partition config: scontrol show partition"
        echo "  3. Run with verbose flag: srun --verbose --nodes=2 --gres=gpu:1 hostname"
    fi
fi
echo ""

echo "=========================================="
echo "Debugging Complete"
echo "=========================================="
set -e  # Re-enable exit on error

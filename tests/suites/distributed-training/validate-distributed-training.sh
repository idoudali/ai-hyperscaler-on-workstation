#!/bin/bash
# Validate distributed training functionality
# TASK-054: NCCL Multi-GPU Validation

set -e

echo "=== Distributed Training Validation ==="
echo "TASK-054: NCCL Multi-GPU Validation"
echo ""

# Configuration
# Allow override of container path via $CONTAINER environment variable
CONTAINER="${CONTAINER:-/mnt/beegfs/containers/pytorch-cuda12.1-mpi4.1.sif}"
TRAINING_SCRIPT="/mnt/beegfs/training/scripts/mnist_ddp.py"
SBATCH_SCRIPT="/mnt/beegfs/jobs/mnist-ddp.sbatch"

# Check environment
echo "1. Checking PyTorch environment in container..."
if [ ! -f "$CONTAINER" ]; then
    echo "✗ ERROR: Container not found: $CONTAINER"
    echo "   Please complete TASK-053 first to build and deploy the container."
    exit 1
fi

echo "   Container: $CONTAINER"
apptainer exec "$CONTAINER" python3 -c "
import torch
import torch.distributed as dist
print(f'  ✓ PyTorch {torch.__version__}')
print(f'  ✓ CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'  ✓ GPUs: {torch.cuda.device_count()}')
    if torch.cuda.device_count() > 0:
        try:
            # nccl.is_available(0) requires a device index
            print(f'  ✓ NCCL available: {torch.cuda.nccl.is_available(0)}')
        except Exception as e:
            print(f'  ✗ NCCL check failed: {e}')
    else:
        print('  - NCCL available: N/A (no GPUs detected)')
"

# Check training script
echo ""
echo "2. Checking training script..."
if [ ! -f "$TRAINING_SCRIPT" ]; then
    echo "✗ ERROR: Training script not found: $TRAINING_SCRIPT"
    exit 1
fi
echo "   ✓ Training script: $TRAINING_SCRIPT"

# Check SLURM script
echo ""
echo "3. Checking SLURM job script..."
if [ ! -f "$SBATCH_SCRIPT" ]; then
    echo "✗ ERROR: SLURM script not found: $SBATCH_SCRIPT"
    exit 1
fi
echo "   ✓ SLURM script: $SBATCH_SCRIPT"

# Submit test job
echo ""
echo "4. Submitting MNIST DDP test job..."
if JOB_ID=$(sbatch --parsable "$SBATCH_SCRIPT" 2>&1) && [ -n "$JOB_ID" ]; then
    echo "   ✓ Job submitted: $JOB_ID"
else
    echo "   ✗ Job submission failed: $JOB_ID"
    exit 1
fi

# Monitor job
echo ""
echo "5. Monitoring job progress..."
echo "   Job ID: $JOB_ID"
echo "   Status: $(squeue -j "$JOB_ID" -h -o '%T' 2>/dev/null || echo 'COMPLETED')"
echo ""
echo "   To monitor manually:"
# Use default path if JOB_ID is set
LOG_FILE="/mnt/beegfs/logs/mnist-ddp-${JOB_ID}.out"
echo "     tail -f $LOG_FILE"
echo "     squeue -j $JOB_ID"
echo ""

# Wait for completion (optional)
if [ "${WAIT_FOR_JOB:-false}" = "true" ]; then
    echo "   Waiting for job completion (max 10 minutes)..."
    TIMEOUT=600
    ELAPSED=0
    while [ $ELAPSED -lt $TIMEOUT ]; do
        JOB_STATE=$(squeue -j "$JOB_ID" -h -o "%T" 2>/dev/null || echo "COMPLETED")
        if [ "$JOB_STATE" = "COMPLETED" ] || [ -z "$JOB_STATE" ]; then
            echo "   ✓ Job completed"
            break
        elif [ "$JOB_STATE" = "FAILED" ] || [ "$JOB_STATE" = "CANCELLED" ] || [ "$JOB_STATE" = "NODE_FAIL" ]; then
            echo "   ✗ Job failed with state: $JOB_STATE"
            exit 1
        fi
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done

    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "   ✗ Job timeout"
        exit 1
    fi

    # Check results
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "6. Checking training results..."
        if grep -q "Training Complete" "$LOG_FILE"; then
            echo "   ✓ Training completed successfully"
        else
            echo "   ✗ Training did not complete"
            exit 1
        fi

        # Extract accuracy
        ACCURACY=$(grep -oP 'Accuracy: \K[0-9.]+' "$LOG_FILE" | tail -1)
        if [ -n "$ACCURACY" ]; then
            echo "   ✓ Final accuracy: ${ACCURACY}%"
        fi
    fi
fi

echo ""
echo "=== Validation Script Complete ==="
echo "Job ID: $JOB_ID"
echo "Log file: $LOG_FILE"
echo ""
echo "To check results after completion:"
echo "  cat $LOG_FILE"

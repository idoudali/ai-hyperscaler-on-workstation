# Distributed Training Framework

This directory contains documentation and tutorials for the distributed training infrastructure. The system provides a
robust environment for multi-node deep learning using PyTorch, with integrated monitoring and validation tools.

## Overview

The distributed training platform is built on top of:

- **SLURM**: For job scheduling and resource management.
- **Apptainer**: For containerized environments (PyTorch + CUDA + MPI).
- **BeeGFS**: For high-performance shared storage.
- **Monitoring Stack**: TensorBoard, Aim, and MLflow for experiment tracking.

## Getting Started with SLURM

For details on submitting and managing jobs, please refer to our SLURM tutorials:

- [SLURM Basics](../slurm/08-slurm-basics.md): Introduction to jobs, partitions, and basic commands.
- [Intermediate SLURM](../slurm/09-slurm-intermediate.md): Arrays, dependencies, and complex resource requests.
- [Advanced SLURM](../slurm/10-slurm-advanced.md): Multi-node jobs, GPU affinity, and optimization.
- [Debugging Jobs](../slurm/11-slurm-debugging.md): Troubleshooting failed jobs and inspecting logs.

## Distributed Training Components

### 1. NCCL Multi-GPU Validation

We provide tools to validate NCCL (NVIDIA Collective Communications Library) functionality, which is critical for
distributed training performance. The `nccl-communication.py` script validates fundamental distributed primitives
(All-Reduce, Broadcast, All-Gather) across multiple GPUs and nodes.

### 2. Monitoring Infrastructure

A centralized monitoring stack is deployed on BeeGFS to track experiments across the cluster.

#### TensorBoard

[TensorBoard](https://www.tensorflow.org/tensorboard) is a visualization toolkit for machine learning experimentation.
It provides tools for tracking metrics like loss and accuracy, visualizing the model graph, and viewing histograms of
weights and biases.

- **How it works**: TensorBoard reads event files written by the training script (using `torch.utils.tensorboard` or
  TensorFlow summaries) from a log directory and serves a web interface to visualize them.
- **Our Usage**: We use TensorBoard to track real-time training metrics (loss, accuracy) in our distributed training jobs.
- **Code Examples**:
  - **Training Integration**: See `examples/slurm-jobs/mnist-ddp/mnist_ddp.py` for `SummaryWriter` usage.
  - **Server Deployment**: See `examples/slurm-jobs/monitoring/tensorboard-server.sbatch` for launching the server.

#### Aim

[Aim](https://aimstack.io/) is an open-source, self-hosted experiment tracker designed to handle thousands of runs.
It excels at comparing hyperparameters and metrics across many distributed experiments. For comprehensive
documentation, see the [Aim Documentation](https://aimstack.readthedocs.io/en/latest/index.html).

- **How it works**: Aim logs training metadata and metrics to a local `.aim` repository. The Aim UI server reads
  this repository to provide powerful comparison and visualization features.
- **Our Usage**: Aim is used for comparing performance across different distributed runs (e.g., varying node counts
  or batch sizes).
- **Code Examples**:
  - **Training Integration**: See `examples/slurm-jobs/mnist-ddp/mnist_ddp.py` for `Run` and `track` usage.
  - **Server Deployment**: See `examples/slurm-jobs/monitoring/aim-server.sbatch` for launching the server.

##### Aim Configuration and Usage

**1. Remote Server Configuration**

Aim supports remote tracking servers for centralized experiment logging across multiple compute nodes:

- **Server Setup**: [Track experiments with Aim Remote Server](https://aimstack.readthedocs.io/en/latest/using/remote_tracking.html)
- **Client Configuration**: Configure training scripts to push data to a remote Aim server instead of local storage
- **SSL Support**: Secure remote connections with SSL/TLS encryption
- **Use Case**: Ideal for distributed training where multiple nodes need to log to a central repository

**2. HPC Environment with Shared Storage**

Our HPC cluster uses BeeGFS shared storage (`/mnt/beegfs`) for Aim repositories, enabling:

- **Shared Repository**: All compute nodes write to the same `.aim` repository on BeeGFS
- **Centralized Access**: Single Aim UI server can visualize all runs from all nodes
- **High Performance**: BeeGFS provides parallel I/O for efficient metadata writes
- **Configuration**: Aim repositories are stored at `/mnt/beegfs/monitoring/aim/.aim` by default

**Example for Shared Storage:**

```python
from aim import Run

# All nodes write to the same shared repository
run = Run(
    repo='/mnt/beegfs/monitoring/aim/.aim',
    experiment='distributed-training'
)
```

**3. MLflow Integration**

While Aim and MLflow are separate tools, they can be used together:

- **Aim**: Focus on experiment comparison, hyperparameter search, and visualization
- **MLflow**: Model registry, deployment tracking, and lifecycle management
- **Best Practice**: Use Aim for experiment tracking during development, MLflow for production model management
- **Integration**: Both can log to the same shared storage, allowing cross-tool analysis

**4. Tracking Training Logs**

Aim provides comprehensive logging capabilities for training processes:

- **Log Messages**: [Log messages during training process](https://aimstack.readthedocs.io/en/latest/using/logging.html)
- **Terminal Output**: Capture and track terminal logs automatically
- **Structured Logging**: Log metrics, hyperparameters, system resources, and custom data
- **Real-time Monitoring**: View logs in real-time through the Aim UI

**Example Logging:**

```python
from aim import Run

run = Run()
# Log hyperparameters
run['hparams'] = {'learning_rate': 0.001, 'batch_size': 64}

# Log metrics during training
for epoch in range(epochs):
    loss = train_step()
    run.track(loss, name='loss', step=epoch)
    
# Log terminal output
run.capture_logs()  # Captures stdout/stderr
```

**5. Tracking Different Experiments**

Organize runs into experiments for better management and comparison:

- **Experiment Organization**: [Configure runs - Organizing Runs in Experiments](https://aimstack.readthedocs.io/en/latest/using/configure_runs.html#organizing-runs-in-experiments)
- **Experiment Names**: Group related runs by specifying experiment names
- **Query Language**: Use Aim's query language to filter and compare runs across experiments
- **Tags and Parameters**: Add tags and custom parameters for advanced filtering

**Example:**

```python
# Group runs by experiment
run1 = Run(experiment='baseline', repo='/mnt/beegfs/monitoring/aim/.aim')
run2 = Run(experiment='optimized', repo='/mnt/beegfs/monitoring/aim/.aim')

# Add tags for additional organization
run1['tags'] = ['multi-node', 'gpu-4']
run2['tags'] = ['multi-node', 'gpu-8']
```

**6. Identifying Training Failures in Distributed Systems**

Aim provides tools to detect and diagnose failures in distributed training:

- **System Resource Tracking**: Monitor CPU, memory, and GPU usage to detect resource-related failures
- **Failure Notifications**: [Notify on failed/stuck runs](https://aimstack.readthedocs.io/en/latest/using/training_monitoring.html)
- **Progress Reporting**: Track training progress and detect stuck runs
- **Log Analysis**: Review captured logs to identify failure patterns
- **Metric Anomalies**: Detect unusual metric patterns that indicate failures

**Example Failure Detection:**

```python
from aim import Run

# Enable system tracking to monitor resource usage
run = Run(system_tracking_interval=10)  # Track every 10 seconds

# Track metrics that can indicate failures
run.track(gpu_utilization, name='gpu_util', step=step)
run.track(memory_usage, name='memory', step=step)

# Log errors for later analysis
if training_error:
    run.log_error(f"Training failed at step {step}: {error_message}")
```

**7. Tracking Training Checkpoints and Restarting**

Aim supports artifact logging for model checkpoints, enabling checkpoint management and training resumption:

- **Artifact Logging**: [Logging artifacts with Aim](https://aimstack.readthedocs.io/en/latest/using/artifacts.html)
- **Checkpoint Storage**: Store checkpoints in Aim's artifact storage (local or remote)
- **Continue Runs**: [Continue runs](https://aimstack.readthedocs.io/en/latest/using/manage_runs.html#continue-runs)
to resume training from checkpoints
- **Storage Backends**: Support for local filesystem, S3, and other storage backends

**Example Checkpoint Tracking:**

```python
from aim import Run
import torch

run = Run(repo='/mnt/beegfs/monitoring/aim/.aim')

# Set artifact storage path
run.set_artifacts_path('/mnt/beegfs/experiments/checkpoints/')

# Save and log checkpoint
checkpoint = {
    'epoch': epoch,
    'model_state_dict': model.state_dict(),
    'optimizer_state_dict': optimizer.state_dict(),
}
checkpoint_path = f'/mnt/beegfs/experiments/checkpoints/checkpoint_epoch_{epoch}.pth'
torch.save(checkpoint, checkpoint_path)

# Log checkpoint as artifact
run.track_artifact(checkpoint_path, name='model_checkpoint')

# Resume from checkpoint
def resume_training(run_hash, checkpoint_name):
    # Retrieve checkpoint path from Aim
    checkpoint_info = run.get_artifact(checkpoint_name)
    checkpoint = torch.load(checkpoint_info.path)
    model.load_state_dict(checkpoint['model_state_dict'])
    optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
    return checkpoint['epoch']
```

**Additional Resources:**

- [Aim Quick Start Guide](https://aimstack.readthedocs.io/en/latest/quick_start/setup.html)
- [Aim CLI Reference](https://aimstack.readthedocs.io/en/latest/refs/cli.html)
- [Aim SDK Reference](https://aimstack.readthedocs.io/en/latest/refs/sdk.html)
- [Aim Documentation Index](https://aimstack.readthedocs.io/en/latest/index.html) (for query language and other features)

#### MLflow

[MLflow](https://mlflow.org/) is an open-source platform for the complete machine learning lifecycle. It includes
experiment tracking, code packaging, and model deployment.

- **How it works**: MLflow Tracking logs parameters, code versions, metrics, and output files to a tracking server
  or local file store.
- **Our Usage**: MLflow is available for general experiment tracking and model registry capabilities within the cluster.
- **Code Examples**:
  - **Integration Check**: See `tests/suites/distributed-training/monitoring-integration.py`.
  - **Server Deployment**: See `examples/slurm-jobs/monitoring/mlflow-server.sbatch` for launching the tracking server.

**Server Management:**
Scripts are provided to launch and manage monitoring servers as SLURM jobs using `scripts/manage-monitoring-servers.sh`.

**Viewing Test Logs:**
Since Aim logs are stored per-test in `/mnt/beegfs/tests/<test-id>/monitoring-logs/aim/`, you can spin up a dedicated
Aim server for a specific test:

```bash
# View Aim logs for a specific test run
./scripts/manage-monitoring-servers.sh view-test <test-id> aim
```

Replace `<test-id>` with the directory name found in `/mnt/beegfs/tests/`.

## Verification and Testing

For information on how the infrastructure is verified and how to run the automated validation suites, please refer
to the [Test Suite Documentation](../../../tests/suites/distributed-training/README.md).

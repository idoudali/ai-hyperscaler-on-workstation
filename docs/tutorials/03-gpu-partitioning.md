# Tutorial: GPU Partitioning with MIG

**Status:** Draft
**Last Updated:** 2025-12-04
**Related Tasks:** TASK-DOC-2.3

## Goal

This tutorial guides you through partitioning an NVIDIA Ampere GPU (A100/A30) into multiple smaller instances using
MIG (Multi-Instance GPU). This allows you to run multiple isolated workloads (e.g., 7 small inference jobs) on a
single physical card.

## Prerequisites

-   **Hardware:** NVIDIA A100 or A30 GPU.
-   **OS:** Debian 11/12 (Host or GPU-Passthrough VM).
-   **Drivers:** NVIDIA Driver 470+ installed.
-   **Privileges:** Root access (`sudo`).

## Step 1: Check Current Status

First, verify your GPU supports MIG and check its current mode.

```bash
nvidia-smi
```

Look for the "MIG" section in the output. If it says `N/A`, your GPU might not support it, or you need to enable the mode.

## Step 2: Enable MIG Mode

1.  Enable MIG mode (Persistent):

    ```bash
    sudo nvidia-smi -i 0 -mig 1
    ```

    *(Replace `-i 0` with your GPU index if different)*

2.  **Reboot** or Reset the GPU to apply changes:

    ```bash
    sudo reboot
    ```

3.  Verify after reboot:

    ```bash
    nvidia-smi
    ```

    The output should now show "MIG: Enabled".

## Step 3: Choose a Partition Profile

List the available profiles for your GPU:

```bash
nvidia-smi mig --list-gpu-instance-profiles
```

**Common Scenarios:**

| Scenario | Profile ID (A100) | Description |
| :--- | :--- | :--- |
| **Max Density** | 19 (1g.5gb) | 7 instances, 5GB memory each. Good for small inference. |
| **Balanced** | 14 (2g.10gb) | 3 instances, 10GB memory each. Good for small training/fine-tuning. |
| **High Performance** | 9 (3g.20gb) | 2 instances, 20GB memory each. |

## Step 4: Create Partitions

We will create 7 instances of `1g.5gb` (Profile ID 19).

```bash
# -cgi 19: Create GPU Instance (Profile 19)
# -C: Also create Compute Instance (required for execution)
sudo nvidia-smi mig -i 0 -cgi 19,19,19,19,19,19,19 -C
```

*Tip: You can use `sudo nvidia-smi mig -i 0 -cgi 19 -C` repeatedly or list IDs separated by commas.*

Verify the instances:

```bash
nvidia-smi -L
```

You should see 7 unique UUIDs, e.g., `MIG-GPU-xxxx-xxxx...`.

## Step 5: Run a Workload on a Partition

To use a specific partition, use the `CUDA_VISIBLE_DEVICES` environment variable with the MIG UUID.

1.  **Get the UUID** of the first instance:

    ```bash
    export MIG_UUID=$(nvidia-smi -L | grep "MIG 1g.5gb" | head -n 1 | awk '{print $NF}' | tr -d ')')
    echo $MIG_UUID
    ```

2.  **Run a test command** (e.g., `nvidia-smi` inside the slice):

    ```bash
    export CUDA_VISIBLE_DEVICES=$MIG_UUID
    nvidia-smi
    ```

    You will see *only* that 1g.5gb slice as "GPU 0". The application is isolated to that slice.

## Step 6: Cleanup (Destroy Partitions)

To return the GPU to a single full device:

1.  Destroy all instances:

    ```bash
    sudo nvidia-smi mig -i 0 -dgi
    ```

2.  (Optional) Disable MIG mode:

    ```bash
    sudo nvidia-smi -i 0 -mig 0
    sudo reboot
    ```

## Next Steps

-   **SLURM Users:** Configure `gres.conf` to manage these slices automatically. See
    [MIG Configuration Guide](../guides/gpu/mig-configuration.md).
-   **Docker:** Use the NVIDIA Container Toolkit to pass MIG devices to containers:

    ```bash
    docker run --gpus '"device=0:0"' nvidia/cuda:11.0-base nvidia-smi
    ```

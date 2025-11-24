#!/usr/bin/env python3
"""
MNIST Distributed Data Parallel Training
Validates multi-node, multi-GPU setup with NCCL

This script trains a simple CNN on MNIST using PyTorch DDP.
It is designed to run inside the PyTorch container deployed in TASK-053.
"""

import os
import time
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader
from torch.utils.data.distributed import DistributedSampler
from torchvision import datasets, transforms

class SimpleCNN(nn.Module):
    """Simple CNN for MNIST classification"""
    def __init__(self):
        super(SimpleCNN, self).__init__()
        self.conv1 = nn.Conv2d(1, 32, 3, 1)
        self.conv2 = nn.Conv2d(32, 64, 3, 1)
        self.dropout1 = nn.Dropout(0.25)
        self.dropout2 = nn.Dropout(0.5)

        # Dynamically compute the input size for fc1 based on the output of conv/pool layers
        # This avoids magic numbers like 9216 and makes the architecture robust to changes
        with torch.no_grad():
            dummy_input = torch.zeros(1, 1, 28, 28)
            x = self.conv1(dummy_input)
            x = F.relu(x)
            x = self.conv2(x)
            x = F.relu(x)
            x = F.max_pool2d(x, 2)
            x = self.dropout1(x)
            x = torch.flatten(x, 1)
            fc1_input_features = x.shape[1]

        self.fc1 = nn.Linear(fc1_input_features, 128)
        self.fc2 = nn.Linear(128, 10)

    def forward(self, x):
        x = self.conv1(x)
        x = F.relu(x)
        x = self.conv2(x)
        x = F.relu(x)
        x = F.max_pool2d(x, 2)
        x = self.dropout1(x)
        x = torch.flatten(x, 1)
        x = self.fc1(x)
        x = F.relu(x)
        x = self.dropout2(x)
        x = self.fc2(x)
        return F.log_softmax(x, dim=1)

def setup_distributed():
    """Initialize distributed training"""
    rank = int(os.environ.get('SLURM_PROCID', 0))
    world_size = int(os.environ.get('SLURM_NTASKS', 1))
    local_rank = int(os.environ.get('SLURM_LOCALID', 0))

    master_addr = os.environ.get('MASTER_ADDR', 'localhost')
    master_port = os.environ.get('MASTER_PORT', '29500')

    try:
        dist.init_process_group(
            backend='nccl',
            init_method=f'tcp://{master_addr}:{master_port}',
            world_size=world_size,
            rank=rank
        )
    except Exception as e:
        print("ERROR: Failed to initialize the distributed process group.")
        print(f"  SLURM_PROCID: {os.environ.get('SLURM_PROCID')}")
        print(f"  SLURM_NTASKS: {os.environ.get('SLURM_NTASKS')}")
        print(f"  SLURM_LOCALID: {os.environ.get('SLURM_LOCALID')}")
        print(f"  MASTER_ADDR: {master_addr}")
        print(f"  MASTER_PORT: {master_port}")
        print(f"  Exception: {e}")
        raise

    torch.cuda.set_device(local_rank)

    return rank, world_size, local_rank

def train(model, device, train_loader, optimizer, epoch, rank):
    """Training loop"""
    model.train()
    total_loss = 0
    correct = 0
    total = 0

    start_time = time.time()

    for batch_idx, (data, target) in enumerate(train_loader):
        data, target = data.to(device), target.to(device)

        optimizer.zero_grad()
        output = model(data)
        loss = F.nll_loss(output, target)
        loss.backward()
        optimizer.step()

        # Statistics
        total_loss += loss.item()
        pred = output.argmax(dim=1, keepdim=True)
        correct += pred.eq(target.view_as(pred)).sum().item()
        total += target.size(0)

        if batch_idx % 10 == 0 and rank == 0:
            print(f'Epoch {epoch}, Batch {batch_idx}/{len(train_loader)}, '
                  f'Loss: {loss.item():.4f}, '
                  f'Accuracy: {100. * correct / total:.2f}%')

    epoch_time = time.time() - start_time
    avg_loss = total_loss / len(train_loader)
    accuracy = 100. * correct / total

    if rank == 0:
        print(f'\nEpoch {epoch} Summary:')
        print(f'  Average Loss: {avg_loss:.4f}')
        print(f'  Accuracy: {accuracy:.2f}%')
        print(f'  Time: {epoch_time:.2f}s')
        print(f'  Throughput: {len(train_loader.dataset) / epoch_time:.2f} samples/sec\n')

    return avg_loss, accuracy

def test(model, device, test_loader, rank):
    """Testing loop"""
    model.eval()
    test_loss = 0
    correct = 0

    with torch.no_grad():
        for data, target in test_loader:
            data, target = data.to(device), target.to(device)
            output = model(data)
            test_loss += F.nll_loss(output, target, reduction='sum').item()
            pred = output.argmax(dim=1, keepdim=True)
            correct += pred.eq(target.view_as(pred)).sum().item()

    test_loss /= len(test_loader.dataset)
    accuracy = 100. * correct / len(test_loader.dataset)

    if rank == 0:
        print(f'\nTest Results:')
        print(f'  Average Loss: {test_loss:.4f}')
        print(f'  Accuracy: {accuracy:.2f}%\n')

    return test_loss, accuracy

def main():
    # Setup distributed training
    rank, world_size, local_rank = setup_distributed()
    device = torch.device(f'cuda:{local_rank}')

    # Output node information for verification
    # This format is expected by the test suite (verify_multi_node)
    try:
        hostname = os.uname().nodename
        print(f"Node: {hostname} (Rank: {rank})")
    except Exception:
        print(f"Node: Unknown (Rank: {rank})")

    if rank == 0:
        print("=" * 50)
        print("MNIST Distributed Training - Validation Run")
        print("=" * 50)
        print(f"World Size: {world_size}")
        print(f"Rank: {rank}")
        print(f"Local Rank: {local_rank}")
        print(f"Device: {device}")
        print("=" * 50)

    try:
        # Hyperparameters
        batch_size = 64
        epochs = 5
        learning_rate = 0.001

        # Data transforms
        transform = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize((0.1307,), (0.3081,))
        ])

        # Load datasets
        # Use /mnt/beegfs/data/mnist for shared storage
        data_dir = os.environ.get('MNIST_DATA_DIR', '/mnt/beegfs/data/mnist')

        # Only rank 0 downloads the dataset, others wait for download to complete
        # This prevents race conditions and file corruption
        if rank == 0:
            train_dataset = datasets.MNIST(
                data_dir,
                train=True,
                download=True,
                transform=transform
            )

        # Synchronize after download to ensure dataset exists for all ranks
        dist.barrier()

        if rank != 0:
            train_dataset = datasets.MNIST(
                data_dir,
                train=True,
                download=False,
                transform=transform
            )

        # Only rank 0 downloads the test dataset, others wait for download to complete
        if rank == 0:
            test_dataset = datasets.MNIST(
                data_dir,
                train=False,
                download=True, # Download test dataset (already downloaded by rank 0, but download=True ensures dataset exists)
                transform=transform
            )

        dist.barrier()

        if rank != 0:
            test_dataset = datasets.MNIST(
                data_dir,
                train=False,
                download=False,
                transform=transform
            )

        # Create distributed samplers
        train_sampler = DistributedSampler(
            train_dataset,
            num_replicas=world_size,
            rank=rank,
            shuffle=True
        )

        # Create data loaders
        train_loader = DataLoader(
            train_dataset,
            batch_size=batch_size,
            sampler=train_sampler,
            num_workers=4,
            pin_memory=True
        )

        test_loader = DataLoader(
            test_dataset,
            batch_size=batch_size,
            shuffle=False,
            num_workers=4,
            pin_memory=True
        )

        # Create model
        model = SimpleCNN().to(device)
        model = DDP(model, device_ids=[local_rank])

        # Optimizer
        optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)

        # Training loop
        if rank == 0:
            print(f"\nStarting training for {epochs} epochs...")

        for epoch in range(1, epochs + 1):
            train_sampler.set_epoch(epoch)
            train(model, device, train_loader, optimizer, epoch, rank)
            test_loss, test_acc = test(model, device, test_loader, rank)

            if rank == 0:
                print(f"Epoch {epoch}: Test Loss: {test_loss:.4f}, Test Accuracy: {test_acc:.2f}%")

        if rank == 0:
            print("=" * 50)
            print("Training Complete!")
            print("=" * 50)

    finally:
        # Cleanup distributed process group
        # This ensures resources are released even if an exception occurs
        if dist.is_initialized():
            dist.destroy_process_group()

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
MNIST Distributed Data Parallel Training
Validates multi-node, multi-GPU setup with NCCL

This script trains a simple CNN on MNIST using PyTorch DDP.
It includes optional monitoring with TensorBoard and Aim.
"""

import os
import time
import argparse
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader
from torch.utils.data.distributed import DistributedSampler
from torchvision import datasets, transforms

# Optional imports for monitoring
try:
    from torch.utils.tensorboard import SummaryWriter
    TENSORBOARD_AVAILABLE = True
except ImportError:
    TENSORBOARD_AVAILABLE = False

try:
    from aim import Run
    AIM_AVAILABLE = True
except ImportError:
    AIM_AVAILABLE = False

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

def train(model, device, train_loader, optimizer, epoch, rank, tb_writer=None, aim_run=None):
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

            global_step = epoch * len(train_loader) + batch_idx

            # Monitoring
            if tb_writer:
                tb_writer.add_scalar('Loss/train', loss.item(), global_step)
                tb_writer.add_scalar('Accuracy/train', 100. * correct / total, global_step)

            if aim_run:
                aim_run.track(loss.item(), name='loss', step=global_step, context={'subset': 'train'})
                aim_run.track(100. * correct / total, name='accuracy', step=global_step, context={'subset': 'train'})

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

def parse_args():
    parser = argparse.ArgumentParser(description='MNIST DDP Training')
    parser.add_argument('--epochs', type=int, default=5, help='number of epochs to train (default: 5)')
    parser.add_argument('--batch-size', type=int, default=64, help='input batch size for training (default: 64)')
    parser.add_argument('--lr', type=float, default=0.001, help='learning rate (default: 0.001)')
    parser.add_argument('--monitor', action='store_true', help='Enable monitoring (TensorBoard/Aim)')
    parser.add_argument('--log-dir', type=str, default=None, help='Log directory for TensorBoard')
    parser.add_argument('--aim-repo', type=str, default='/mnt/beegfs/monitoring/aim/.aim', help='Aim repository path')
    return parser.parse_args()

def main():
    args = parse_args()

    # Setup distributed training
    rank, world_size, local_rank = setup_distributed()
    device = torch.device(f'cuda:{local_rank}')

    # Output node information for verification
    try:
        hostname = os.uname().nodename
        print(f"Node: {hostname} (Rank: {rank})")
    except Exception:
        print(f"Node: Unknown (Rank: {rank})")

    if rank == 0:
        print("=" * 50)
        print("MNIST Distributed Training")
        print("=" * 50)
        print(f"World Size: {world_size}")
        print(f"Rank: {rank}")
        print(f"Local Rank: {local_rank}")
        print(f"Device: {device}")
        print(f"Monitoring: {'Enabled' if args.monitor else 'Disabled'}")
        print("=" * 50)

    # Initialize monitoring (only on rank 0)
    tb_writer = None
    aim_run = None

    if args.monitor and rank == 0:
        if TENSORBOARD_AVAILABLE:
            log_dir = args.log_dir or f'/mnt/beegfs/experiments/logs/mnist-ddp-{time.strftime("%Y%m%d-%H%M%S")}'
            os.makedirs(log_dir, exist_ok=True)
            tb_writer = SummaryWriter(log_dir=log_dir)
            print(f"TensorBoard logging to: {log_dir}")
        else:
            print("Warning: TensorBoard not available")

        if AIM_AVAILABLE:
            aim_repo = args.aim_repo
            # Ensure parent directory exists before initializing Aim
            aim_parent = os.path.dirname(aim_repo) if aim_repo else None
            if aim_parent:
                try:
                    os.makedirs(aim_parent, exist_ok=True)
                    aim_run = Run(repo=aim_repo, experiment='mnist-distributed')
                    aim_run['hparams'] = {
                        'batch_size': args.batch_size,
                        'learning_rate': args.lr,
                        'epochs': args.epochs,
                        'world_size': world_size
                    }
                    print(f"Aim logging to: {aim_repo}")
                except Exception as e:
                    print(f"Warning: Failed to initialize Aim: {e}")
            else:
                print(f"Warning: Invalid Aim repository path: {aim_repo}")
        else:
            print("Warning: Aim not available")

    try:
        # Hyperparameters
        batch_size = args.batch_size
        epochs = args.epochs
        learning_rate = args.lr

        # Data transforms
        transform = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize((0.1307,), (0.3081,))
        ])

        # Load datasets
        data_dir = os.environ.get('MNIST_DATA_DIR', '/mnt/beegfs/data/mnist')

        if rank == 0:
            train_dataset = datasets.MNIST(data_dir, train=True, download=True, transform=transform)

        dist.barrier()

        if rank != 0:
            train_dataset = datasets.MNIST(data_dir, train=True, download=False, transform=transform)

        if rank == 0:
            test_dataset = datasets.MNIST(data_dir, train=False, download=True, transform=transform)

        dist.barrier()

        if rank != 0:
            test_dataset = datasets.MNIST(data_dir, train=False, download=False, transform=transform)

        # Create distributed samplers
        train_sampler = DistributedSampler(train_dataset, num_replicas=world_size, rank=rank, shuffle=True)

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
            train(model, device, train_loader, optimizer, epoch, rank, tb_writer, aim_run)
            test_loss, test_acc = test(model, device, test_loader, rank)

            if rank == 0:
                print(f"Epoch {epoch}: Test Loss: {test_loss:.4f}, Test Accuracy: {test_acc:.2f}%")

                # Monitoring
                if tb_writer:
                    tb_writer.add_scalar('Loss/test', test_loss, epoch)
                    tb_writer.add_scalar('Accuracy/test', test_acc, epoch)
                if aim_run:
                    aim_run.track(test_loss, name='loss', step=epoch, context={'subset': 'test'})
                    aim_run.track(test_acc, name='accuracy', step=epoch, context={'subset': 'test'})

        if rank == 0:
            print("=" * 50)
            print("Training Complete!")
            print("=" * 50)

        # Cleanup monitoring
        if rank == 0:
            if tb_writer:
                tb_writer.close()
            if aim_run:
                aim_run.close()

    finally:
        if dist.is_initialized():
            dist.destroy_process_group()

if __name__ == '__main__':
    main()

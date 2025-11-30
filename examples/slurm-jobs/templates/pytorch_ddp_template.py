#!/usr/bin/env python3
"""
PyTorch Distributed Data Parallel (DDP) Template
Supports multi-node, multi-GPU training on SLURM clusters
"""

import os
import torch
import torch.distributed as dist
from torch.utils.data import DataLoader
from torch.utils.data.distributed import DistributedSampler

def setup_distributed():
    """Initialize distributed training environment"""
    # Get SLURM environment variables
    rank = int(os.environ.get('SLURM_PROCID', 0))
    world_size = int(os.environ.get('SLURM_NTASKS', 1))
    local_rank = int(os.environ.get('SLURM_LOCALID', 0))

    # Get master node address
    master_addr = os.environ.get('MASTER_ADDR', 'localhost')
    master_port = os.environ.get('MASTER_PORT', '29500')

    # Initialize process group
    dist.init_process_group(
        backend='nccl',  # Use NCCL for GPU communication
        init_method=f'tcp://{master_addr}:{master_port}',
        world_size=world_size,
        rank=rank
    )

    # Set device
    torch.cuda.set_device(local_rank)

    if rank == 0:
        print(f"Distributed training initialized:")
        print(f"  World size: {world_size}")
        print(f"  Rank: {rank}")
        print(f"  Local rank: {local_rank}")
        print(f"  Master: {master_addr}:{master_port}")

    return rank, world_size, local_rank

def cleanup_distributed():
    """Clean up distributed training"""
    dist.destroy_process_group()

def create_dataloader(dataset, batch_size, rank, world_size):
    """Create distributed dataloader"""
    sampler = DistributedSampler(
        dataset,
        num_replicas=world_size,
        rank=rank,
        shuffle=True
    )

    loader = DataLoader(
        dataset,
        batch_size=batch_size,
        sampler=sampler,
        num_workers=4,
        pin_memory=True
    )

    return loader, sampler

def main():
    # Initialize distributed training
    rank, world_size, local_rank = setup_distributed()
    print(f"Process running with rank: {rank}, world_size: {world_size}, local_rank: {local_rank}")
    torch.cuda.set_device(local_rank)

    # Create model and move to GPU
    # model = YourModel()  # Replace with your model
    # model = model.cuda(local_rank)

    # Wrap model with DDP
    # from torch.nn.parallel import DistributedDataParallel as DDP
    # model = DDP(model, device_ids=[local_rank])

    # Create optimizer
    # optimizer = torch.optim.Adam(model.parameters(), lr=0.001)

    # Create distributed dataloader
    # train_dataset = YourDataset()  # Replace with your dataset
    # train_loader, train_sampler = create_dataloader(
    #     train_dataset,
    #     batch_size=64,
    #     rank=rank,
    #     world_size=world_size
    # )

    # Training loop
    # num_epochs = 10
    # for epoch in range(num_epochs):
    #     # Set epoch for proper shuffling
    #     train_sampler.set_epoch(epoch)
    #
    #     model.train()
    #     for batch_idx, (data, target) in enumerate(train_loader):
    #         data, target = data.cuda(), target.cuda()
    #
    #         optimizer.zero_grad()
    #         output = model(data)
    #         loss = criterion(output, target)
    #         loss.backward()
    #         optimizer.step()
    #
    #         if batch_idx % 10 == 0 and rank == 0:
    #             print(f'Epoch {epoch}, Batch {batch_idx}, Loss: {loss.item():.4f}')

    # Cleanup
    cleanup_distributed()

if __name__ == '__main__':
    main()

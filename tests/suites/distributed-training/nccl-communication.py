#!/usr/bin/env python3
"""
Unit test for NCCL communication
Tests basic distributed operations without full training

This script validates NCCL backend functionality for distributed training.
It should be run via SLURM with multiple nodes/GPUs.
"""

import os
import sys
import torch
import torch.distributed as dist

def test_nccl_init():
    """Test NCCL process group initialization"""
    try:
        rank = int(os.environ.get('SLURM_PROCID', 0))
        world_size = int(os.environ.get('SLURM_NTASKS', 1))
        local_rank = int(os.environ.get('SLURM_LOCALID', 0))

        master_addr = os.environ.get('MASTER_ADDR', 'localhost')
        master_port = os.environ.get('MASTER_PORT', '29500')

        dist.init_process_group(
            backend='nccl',
            init_method=f'tcp://{master_addr}:{master_port}',
            world_size=world_size,
            rank=rank
        )

        torch.cuda.set_device(local_rank)

        print(f"✓ PASS: NCCL initialized (rank={rank}, world_size={world_size})")
        return True
    except Exception as e:
        print(f"✗ FAIL: NCCL initialization failed: {e}")
        return False

def test_all_reduce():
    """Test NCCL all-reduce operation"""
    try:
        rank = dist.get_rank()
        tensor = torch.ones(1).cuda() * rank

        dist.all_reduce(tensor, op=dist.ReduceOp.SUM)

        expected = sum(range(dist.get_world_size()))
        if tensor.item() == expected:
            print(f"✓ PASS: All-reduce operation successful (result={tensor.item()})")
            return True
        else:
            print(f"✗ FAIL: All-reduce incorrect (expected={expected}, got={tensor.item()})")
            return False
    except Exception as e:
        print(f"✗ FAIL: All-reduce failed: {e}")
        return False

def test_broadcast():
    """Test NCCL broadcast operation"""
    try:
        rank = dist.get_rank()
        tensor = torch.zeros(1).cuda() if rank != 0 else torch.ones(1).cuda() * 42

        dist.broadcast(tensor, src=0)

        if tensor.item() == 42:
            print(f"✓ PASS: Broadcast operation successful")
            return True
        else:
            print(f"✗ FAIL: Broadcast incorrect (got={tensor.item()})")
            return False
    except Exception as e:
        print(f"✗ FAIL: Broadcast failed: {e}")
        return False

def test_all_gather():
    """Test NCCL all-gather operation"""
    try:
        rank = dist.get_rank()
        world_size = dist.get_world_size()

        # Each rank creates a tensor with its rank value
        tensor = torch.ones(1).cuda() * rank
        gather_list = [torch.zeros(1).cuda() for _ in range(world_size)]

        dist.all_gather(gather_list, tensor)

        # Verify all ranks received correct values
        success = True
        for i, gathered_tensor in enumerate(gather_list):
            if gathered_tensor.item() != i:
                success = False
                break

        if success:
            print(f"✓ PASS: All-gather operation successful")
            return True
        else:
            print(f"✗ FAIL: All-gather incorrect")
            return False
    except Exception as e:
        print(f"✗ FAIL: All-gather failed: {e}")
        return False

def cleanup():
    """Cleanup distributed training"""
    try:
        if dist.is_initialized():
            dist.destroy_process_group()
            print("✓ PASS: Process group destroyed")
        return True
    except Exception as e:
        print(f"✗ FAIL: Cleanup failed: {e}")
        return False

if __name__ == '__main__':
    print("=== NCCL Communication Test ===")
    print(f"Rank: {os.environ.get('SLURM_PROCID', 'N/A')}")
    print(f"World Size: {os.environ.get('SLURM_NTASKS', 'N/A')}")
    print(f"Local Rank: {os.environ.get('SLURM_LOCALID', 'N/A')}")
    print()

    tests = [
        ("NCCL Initialization", test_nccl_init),
        ("All-Reduce Operation", test_all_reduce),
        ("Broadcast Operation", test_broadcast),
        ("All-Gather Operation", test_all_gather)
    ]

    failed = 0
    try:
        # Verify CUDA is available before running tests
        if not torch.cuda.is_available():
            raise RuntimeError("CUDA not available")

        for name, test_func in tests:
            print(f"Test: {name}")
            if not test_func():
                failed += 1
            print()
    except Exception as e:
        print(f"✗ FAIL: Test suite execution failed: {e}")
        failed += 1
    finally:
        # Always attempt cleanup, even if tests fail or an exception occurs
        cleanup()

    print("="*50)
    if failed == 0:
        print("✓ All NCCL communication tests passed")
        sys.exit(0)
    else:
        print(f"✗ {failed} test(s) failed")
        sys.exit(1)

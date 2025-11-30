#!/usr/bin/env python3
"""
Test monitoring integration with training code
"""

import sys
from pathlib import Path

# Add path for imports if needed
# sys.path.insert(0, '/beegfs/shared')

def test_tensorboard_import():
    """Test TensorBoard import and basic functionality"""
    try:
        from torch.utils.tensorboard import SummaryWriter

        # Create test writer
        test_dir = '/tmp/test-tensorboard'
        Path(test_dir).mkdir(parents=True, exist_ok=True)

        writer = SummaryWriter(log_dir=test_dir)
        writer.add_scalar('test/loss', 0.5, 0)
        writer.close()

        # Verify log file created
        # TensorBoard creates files starting with events.out.tfevents
        if any(Path(test_dir).glob('events.out.tfevents.*')):
            print("✓ PASS: TensorBoard logging functional")
            return True
        else:
            print("✗ FAIL: TensorBoard log file not created")
            return False
    except Exception as e:
        print(f"✗ FAIL: TensorBoard test failed: {e}")
        return False

def test_aim_import():
    """Test Aim import and basic functionality"""
    try:
        from aim import Run

        # Create test run
        test_repo = '/tmp/test-aim'
        Path(test_repo).mkdir(parents=True, exist_ok=True)

        # Initialize repo if needed (Aim usually handles this or needs aim init)
        # We'll rely on Run creating what it needs or failing if init required
        # Note: aim init usually required in directory.

        # For test, we might need to handle initialization or skip if intricate setup needed
        try:
            run = Run(repo=test_repo, experiment='test')
            run.track(0.5, name='loss', step=0)
            run.close()

            # Verify Aim repo created
            if (Path(test_repo) / '.aim').exists():
                print("✓ PASS: Aim logging functional")
                return True
            else:
                print("✗ FAIL: Aim repository not created")
                return False
        except Exception as inner_e:
             # Aim might require 'aim init' first
             print(f"⚠ WARNING: Aim run creation failed (might need init): {inner_e}")
             return False

    except Exception as e:
        print(f"✗ FAIL: Aim test failed: {e}")
        return False

def test_mlflow_import():
    """Test MLflow import"""
    try:
        import mlflow
        print(f"✓ PASS: MLflow version {mlflow.__version__}")
        return True
    except Exception as e:
        print(f"✗ FAIL: MLflow import failed: {e}")
        return False

if __name__ == '__main__':
    print("=== Monitoring Integration Tests ===\n")

    tests = [
        ("TensorBoard Integration", test_tensorboard_import),
        ("Aim Integration", test_aim_import),
        ("MLflow Import", test_mlflow_import)
    ]

    failed = 0
    for name, test_func in tests:
        print(f"Test: {name}")
        if not test_func():
            failed += 1
        print()

    if failed == 0:
        print("✓ All monitoring integration tests passed")
        sys.exit(0)
    else:
        print(f"✗ {failed} test(s) failed")
        sys.exit(1)

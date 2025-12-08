"""
DockerWrapper extension for PyTorch + CUDA + MPI container.

This module extends the docker-wrapper library with HPC-specific
functionality for PyTorch distributed training workloads.

Multi-stage build with:
- Base stage: PyTorch + CUDA 12.8 + MPI 4.1
- Oumi stage: Base + Oumi Framework
"""

import hashlib
import logging
import os
from typing import List

import docker_wrapper


class PyTorchCudaMpiImage(docker_wrapper.DockerImage):
    """Base PyTorch + CUDA + MPI Docker image (target: pytorch-cuda12.1-mpi4.1)."""

    NAME = "pytorch-cuda12.1-mpi4.1"
    BUILD_TARGET = "pytorch-cuda12.1-mpi4.1"

    def __init__(self, **kwargs) -> None:
        """Initialize PyTorch CUDA MPI base image."""
        super().__init__(**kwargs)
        self.name = PyTorchCudaMpiImage.NAME
        self.docker_folder = os.path.realpath(
            os.path.join(os.path.dirname(os.path.realpath(__file__)), "Docker")
        )
        self.cuda_version = "12.8.0"
        self.pytorch_version = "2.4.0"
        self.mpi_version = "4.1.4"

    @property
    def image_hash(self) -> str:
        """
        Compute the hash of the base image.

        Returns:
            str: SHA1 hash of the Docker folder contents
        """
        hash_value = self.folder_hash(self.docker_folder)
        logging.debug(f"Base image hash: {hash_value}")
        return hash_value

    def build_image(self, force_build: bool = False) -> None:
        """
        Build the base PyTorch image using --target base.

        Args:
            force_build: Force rebuild even if image exists
        """
        image_url = self.image_url
        if self.image_exists(image_url) and not force_build:
            logging.info(f"Image: {image_url} already exists, not rebuilding")
            return

        cmd = [
            "docker",
            "build",
            "--target",
            self.BUILD_TARGET,
            "-f",
            os.path.join(self.docker_folder, "Dockerfile"),
            "-t",
            image_url,
            self.docker_folder,
        ]
        logging.info(f"Building base image with target: {self.BUILD_TARGET}")
        self._exec_cmd(cmd)

    def get_docker_run_args(self) -> List[str]:
        """
        Get Docker run arguments for base PyTorch image.

        Returns:
            List of Docker run arguments
        """
        return [
            "--gpus",
            "all",
            "--ipc=host",
            "--ulimit",
            "memlock=-1",
            "--ulimit",
            "stack=67108864",
            "-e",
            "PYTHONUNBUFFERED=1",
            "-e",
            "OMP_NUM_THREADS=1",
        ]

    def test_pytorch_cuda(self) -> str:
        """Get test command for PyTorch CUDA functionality."""
        return """python3 -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA Available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA Version: {torch.version.cuda}')
    print(f'GPU Count: {torch.cuda.device_count()}')
    print(f'GPU Name: {torch.cuda.get_device_name(0)}')
"
"""

    def test_mpi(self) -> str:
        """Get test command for MPI functionality."""
        return """python3 -c "
from mpi4py import MPI
comm = MPI.COMM_WORLD
print(f'MPI Rank: {comm.Get_rank()}')
print(f'MPI Size: {comm.Get_size()}')
"
"""


class PyTorchCudaMpiOumiImage(docker_wrapper.DockerImage):
    """Oumi Framework extension for PyTorch HPC image (target: pytorch-cuda12.1-mpi4.1-oumi)."""

    NAME = "pytorch-cuda12.1-mpi4.1-oumi"
    BUILD_TARGET = "pytorch-cuda12.1-mpi4.1-oumi"

    def __init__(self, **kwargs) -> None:
        """Initialize Oumi PyTorch HPC image."""
        super().__init__(**kwargs)
        self.parent = PyTorchCudaMpiImage()
        self.name = PyTorchCudaMpiOumiImage.NAME
        self.docker_folder = os.path.realpath(
            os.path.join(os.path.dirname(os.path.realpath(__file__)), "Docker")
        )

    @property
    def image_hash(self) -> str:
        """
        Compute the hash of the Oumi image.

        Combines the parent image hash with this image's Docker folder hash
        to capture any changes in either the base or Oumi layers.

        Returns:
            str: Combined SHA1 hash
        """
        parent_image_hash = self.parent.image_hash
        logging.debug(f"Parent hash: {parent_image_hash}")
        this_image_hash = self.folder_hash(self.docker_folder)
        logging.debug(f"This image hash: {this_image_hash}")
        hash_object = hashlib.sha1(
            parent_image_hash.encode("utf8") + this_image_hash.encode("utf8")
        ).hexdigest()
        return hash_object

    def build_image(self, force_build: bool = False) -> None:
        """
        Build the Oumi image using --target oumi.

        This will first ensure the parent base image is built,
        then build the Oumi layer on top of it.

        Args:
            force_build: Force rebuild even if image exists
        """
        image_url = self.image_url
        if self.image_exists(image_url) and not force_build:
            logging.info(f"Image: {image_url} already exists, not rebuilding")
            return

        # Ensure parent base image is built first
        self.parent.build_image()

        cmd = [
            "docker",
            "build",
            "--target",
            self.BUILD_TARGET,
            "-f",
            os.path.join(self.docker_folder, "Dockerfile"),
            "-t",
            image_url,
            self.docker_folder,
        ]
        logging.info(f"Building Oumi image with target: {self.BUILD_TARGET}")
        self._exec_cmd(cmd)

    def get_docker_run_args(self) -> List[str]:
        """
        Get Docker run arguments for Oumi image.

        Inherits base GPU settings and adds Oumi-specific environment.

        Returns:
            List of Docker run arguments
        """
        return [
            "--gpus",
            "all",
            "--ipc=host",
            "--ulimit",
            "memlock=-1",
            "--ulimit",
            "stack=67108864",
            "-e",
            "PYTHONUNBUFFERED=1",
            "-e",
            "OMP_NUM_THREADS=1",
            "-e",
            "OUMI_ENABLED=1",
        ]

    def test_oumi(self) -> str:
        """Get test command for Oumi framework functionality."""
        return """python3 -c "
import oumi
print(f'Oumi: {oumi.__version__}')
from oumi.core.configs import TrainingConfig, ModelParams
from oumi.core.trainers import Trainer
print('Oumi core imports: OK')
"
"""

    def test_oumi_dependencies(self) -> str:
        """Get test command for Oumi dependencies."""
        return """python3 -c "
import transformers
import datasets
import accelerate
import peft
print(f'Transformers: {transformers.__version__}')
print(f'Datasets: {datasets.__version__}')
print(f'Accelerate: {accelerate.__version__}')
print(f'PEFT: {peft.__version__}')
"
"""


# Configuration for base variant
BASE_CONTAINER_CONFIG = {
    "name": "pytorch-cuda12.1-mpi4.1",
    "dockerfile": "Dockerfile",
    "dockerfile_dir": "Docker",
    "build_target": "pytorch-cuda12.1-mpi4.1",
    "tag": "latest",
    "description": "PyTorch + CUDA 12.8 + MPI 4.1 for HPC",
    "requires_gpu": True,
    "test_commands": [
        "python3 --version",
        "python3 -c 'import torch; print(torch.__version__)'",
        "mpirun --version",
    ],
}

# Configuration for Oumi variant
OUMI_CONTAINER_CONFIG = {
    "name": "pytorch-cuda12.1-mpi4.1-oumi",
    "dockerfile": "Dockerfile",
    "dockerfile_dir": "Docker",
    "build_target": "pytorch-cuda12.1-mpi4.1-oumi",
    "tag": "latest",
    "description": "PyTorch + CUDA 12.8 + MPI 4.1 + Oumi Framework for HPC",
    "requires_gpu": True,
    "base_image": "pytorch-cuda12.1-mpi4.1:latest",
    "test_commands": [
        "python3 --version",
        "python3 -c 'import torch; print(torch.__version__)'",
        "python3 -c 'import oumi; print(oumi.__version__)'",
        "oumi --version",
        "mpirun --version",
    ],
}

# Legacy alias - deprecated
CONTAINER_CONFIG = BASE_CONTAINER_CONFIG

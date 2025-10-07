"""
HPC extensions for docker-wrapper library.

These extensions provide HPC-specific functionality on top of the docker-wrapper
base library, including Apptainer conversion, GPU support, and cluster deployment.
"""

__version__ = "1.0.0"
__author__ = "Pharos AI Hyperscaler Team"

# When docker-wrapper is available, import its classes
# from docker_wrapper import DockerImage, DockerClient

# For now, provide placeholder imports
from .apptainer_converter import ApptainerConverter
from .cluster_deploy import ClusterDeployer

__all__ = [
    "ApptainerConverter",
    "ClusterDeployer",
]

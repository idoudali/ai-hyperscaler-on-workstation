"""Ansible inventory generation for HPC and Kubernetes clusters.

This module provides functionality to generate Ansible inventories from cluster
configuration files, with support for both HPC/SLURM and Kubernetes deployments.

Main components:
    - BaseInventoryGenerator: Shared logic for all inventory types
    - HPCInventoryGenerator: SLURM-specific inventory generation
    - KubernetesInventoryGenerator: Kubespray-specific inventory generation
    - INIFormatter: Generate INI format inventories (Ansible default)
    - YAMLFormatter: Generate YAML format inventories

Example usage:
    >>> from ai_how.inventory import HPCInventoryGenerator, INIFormatter
    >>> generator = HPCInventoryGenerator('cluster.yaml', 'hpc')
    >>> inventory = generator.generate()
    >>> formatter = INIFormatter()
    >>> ini_content = formatter.format(inventory)
"""

from ai_how.inventory.base import BaseInventoryGenerator
from ai_how.inventory.formatters import INIFormatter, YAMLFormatter
from ai_how.inventory.hpc import HPCInventoryGenerator
from ai_how.inventory.kubernetes import KubernetesInventoryGenerator

__all__ = [
    "BaseInventoryGenerator",
    "HPCInventoryGenerator",
    "KubernetesInventoryGenerator",
    "INIFormatter",
    "YAMLFormatter",
]

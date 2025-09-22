#!/usr/bin/env python3
"""
Enhanced Ansible inventory generator for the hyperscaler project.
This script creates comprehensive inventory structure from cluster.yaml configuration,
with advanced GPU detection and GRES configuration generation.
"""

import yaml
import sys
import json
from pathlib import Path
from typing import Dict, List, Any, Optional


class InventoryGenerator:
    """Enhanced inventory generator with GPU detection and GRES configuration."""

    def __init__(self, cluster_config_path: str = "cluster.yaml"):
        """Initialize inventory generator with cluster configuration."""
        self.cluster_config_path = Path(cluster_config_path)
        self.cluster_config: Dict[str, Any] = {}
        self.inventory: Dict[str, Any] = {}

    def load_cluster_config(self) -> None:
        """Load and parse cluster configuration file."""
        try:
            if not self.cluster_config_path.exists():
                raise FileNotFoundError(f"Cluster config file not found: {self.cluster_config_path}")

            with open(self.cluster_config_path, 'r') as file:
                self.cluster_config = yaml.safe_load(file)

            print(f"✓ Loaded cluster configuration from {self.cluster_config_path}")

        except Exception as e:
            print(f"✗ Error loading cluster config: {e}")
            raise

    def detect_gpu_resources(self, node_config: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Detect GPU resources via PCIe passthrough configuration."""
        gpu_devices = []

        pcie_config = node_config.get('pcie_passthrough', {})
        if not pcie_config.get('enabled', False):
            return gpu_devices

        devices = pcie_config.get('devices', [])
        for device in devices:
            if device.get('device_type') == 'gpu':
                # Extract GPU information
                gpu_info = {
                    'device_id': device.get('device_id', 'unknown'),
                    'vendor_id': device.get('vendor_id', '10de'),  # Default to NVIDIA
                    'pci_address': device.get('pci_address', 'unknown'),
                    'iommu_group': device.get('iommu_group', 'unknown'),
                    'vendor': self._get_vendor_name(device.get('vendor_id', '10de')),
                    'memory': device.get('memory', 'unknown')
                }
                gpu_devices.append(gpu_info)

        return gpu_devices

    def _get_vendor_name(self, vendor_id: str) -> str:
        """Get vendor name from vendor ID."""
        vendor_map = {
            '10de': 'nvidia',
            '1002': 'amd',
            '8086': 'intel'
        }
        return vendor_map.get(vendor_id.lower(), 'unknown')

    def generate_gres_config(self, gpu_devices: List[Dict[str, Any]], node_name: str) -> List[str]:
        """Generate GRES configuration for GPU resources."""
        gres_config = []

        for i, gpu in enumerate(gpu_devices):
            # Format: NodeName=node01 Name=gpu Type=rtx3080 File=/dev/nvidia0
            vendor = gpu['vendor']
            device_id = gpu['device_id']

            # Create a readable GPU type from device ID
            gpu_type = f"{vendor}_{device_id}"

            gres_line = f"NodeName={node_name} Name=gpu Type={gpu_type} File=/dev/nvidia{i}"
            gres_config.append(gres_line)

        return gres_config

    def generate_hpc_inventory(self) -> Dict[str, Any]:
        """Generate HPC cluster inventory with GPU detection."""
        hpc_config = self.cluster_config.get('clusters', {}).get('hpc', {})
        if not hpc_config:
            print("⚠️  No HPC cluster configuration found")
            return {}

        inventory = {
            'children': {
                'hpc_controllers': {
                    'hosts': {},
                    'vars': {}
                },
                'hpc_compute_nodes': {
                    'hosts': {},
                    'vars': {}
                },
                'hpc_gpu_nodes': {
                    'hosts': {},
                    'vars': {}
                }
            },
            'vars': {
                'cluster_name': hpc_config.get('name', 'hpc-cluster'),
                'slurm_config': hpc_config.get('slurm_config', {}),
                'network': hpc_config.get('network', {})
            }
        }

        # Process controller
        controller_config = hpc_config.get('controller', {})
        if controller_config:
            controller_name = 'hpc-controller'
            controller_ip = controller_config.get('ip_address', '192.168.100.10')

            inventory['children']['hpc_controllers']['hosts'][controller_name] = {
                'ansible_host': controller_ip,
                'cpu_cores': controller_config.get('cpu_cores', 4),
                'memory_gb': controller_config.get('memory_gb', 8),
                'disk_gb': controller_config.get('disk_gb', 100),
                'base_image_path': controller_config.get('base_image_path', ''),
                'node_role': 'controller'
            }

        # Process compute nodes
        compute_nodes = hpc_config.get('compute_nodes', [])
        all_gres_config = []

        for i, node_config in enumerate(compute_nodes):
            node_name = f'hpc-compute-{i+1:02d}'
            node_ip = node_config.get('ip', f'192.168.100.{11+i}')

            # Basic node configuration
            node_vars = {
                'ansible_host': node_ip,
                'cpu_cores': node_config.get('cpu_cores', 8),
                'memory_gb': node_config.get('memory_gb', 16),
                'disk_gb': node_config.get('disk_gb', 200),
                'base_image_path': node_config.get('base_image_path', ''),
                'node_role': 'compute'
            }

            # Detect GPU resources
            gpu_devices = self.detect_gpu_resources(node_config)

            if gpu_devices:
                # This is a GPU node
                node_vars['gpu_devices'] = gpu_devices
                node_vars['gpu_count'] = len(gpu_devices)
                node_vars['has_gpu'] = True
                node_vars['node_role'] = 'gpu_compute'

                # Generate GRES configuration
                gres_config = self.generate_gres_config(gpu_devices, node_name)
                node_vars['slurm_gres'] = gres_config
                all_gres_config.extend(gres_config)

                # Add to GPU nodes group
                inventory['children']['hpc_gpu_nodes']['hosts'][node_name] = node_vars
            else:
                # Regular compute node
                node_vars['has_gpu'] = False
                inventory['children']['hpc_compute_nodes']['hosts'][node_name] = node_vars

        # Add global GRES configuration
        if all_gres_config:
            inventory['vars']['slurm_gres_conf'] = all_gres_config

        return inventory

    def generate_cloud_inventory(self) -> Dict[str, Any]:
        """Generate Cloud cluster inventory with GPU detection."""
        cloud_config = self.cluster_config.get('clusters', {}).get('cloud', {})
        if not cloud_config:
            print("⚠️  No Cloud cluster configuration found")
            return {}

        inventory = {
            'children': {
                'k8s_control_plane': {
                    'hosts': {},
                    'vars': {}
                },
                'k8s_workers': {
                    'hosts': {},
                    'vars': {}
                },
                'k8s_gpu_workers': {
                    'hosts': {},
                    'vars': {}
                }
            },
            'vars': {
                'cluster_name': cloud_config.get('name', 'cloud-cluster'),
                'kubernetes_config': cloud_config.get('kubernetes_config', {}),
                'network': cloud_config.get('network', {})
            }
        }

        # Process control plane
        control_plane_config = cloud_config.get('control_plane', {})
        if control_plane_config:
            cp_name = 'k8s-control-plane'
            cp_ip = control_plane_config.get('ip_address', '192.168.200.10')

            inventory['children']['k8s_control_plane']['hosts'][cp_name] = {
                'ansible_host': cp_ip,
                'cpu_cores': control_plane_config.get('cpu_cores', 4),
                'memory_gb': control_plane_config.get('memory_gb', 8),
                'disk_gb': control_plane_config.get('disk_gb', 100),
                'base_image_path': control_plane_config.get('base_image_path', ''),
                'node_role': 'control_plane'
            }

        # Process worker nodes (CPU workers)
        cpu_workers = cloud_config.get('worker_nodes', {}).get('cpu', [])
        for i, worker_config in enumerate(cpu_workers):
            worker_name = f'k8s-worker-{i+1:02d}'
            worker_ip = worker_config.get('ip', f'192.168.200.{11+i}')

            inventory['children']['k8s_workers']['hosts'][worker_name] = {
                'ansible_host': worker_ip,
                'cpu_cores': worker_config.get('cpu_cores', 4),
                'memory_gb': worker_config.get('memory_gb', 8),
                'disk_gb': worker_config.get('disk_gb', 100),
                'base_image_path': worker_config.get('base_image_path', ''),
                'node_role': 'worker',
                'worker_type': 'cpu'
            }

        # Process GPU worker nodes
        gpu_workers = cloud_config.get('worker_nodes', {}).get('gpu', [])
        for i, worker_config in enumerate(gpu_workers):
            worker_name = f'k8s-gpu-worker-{i+1:02d}'
            worker_ip = worker_config.get('ip', f'192.168.200.{20+i}')

            # Basic worker configuration
            worker_vars = {
                'ansible_host': worker_ip,
                'cpu_cores': worker_config.get('cpu_cores', 8),
                'memory_gb': worker_config.get('memory_gb', 16),
                'disk_gb': worker_config.get('disk_gb', 200),
                'base_image_path': worker_config.get('base_image_path', ''),
                'node_role': 'gpu_worker',
                'worker_type': 'gpu'
            }

            # Detect GPU resources
            gpu_devices = self.detect_gpu_resources(worker_config)

            if gpu_devices:
                worker_vars['gpu_devices'] = gpu_devices
                worker_vars['gpu_count'] = len(gpu_devices)
                worker_vars['has_gpu'] = True

            inventory['children']['k8s_gpu_workers']['hosts'][worker_name] = worker_vars

        return inventory

    def generate_inventory(self) -> Dict[str, Any]:
        """Generate complete Ansible inventory structure."""
        print(f"🚀 Generating enhanced Ansible inventory from {self.cluster_config_path}")

        # Load cluster configuration
        self.load_cluster_config()

        # Generate inventory structure
        inventory = {
            'all': {
                'children': {}
            }
        }

        # Generate HPC cluster inventory
        hpc_inventory = self.generate_hpc_inventory()
        if hpc_inventory:
            inventory['all']['children']['hpc_cluster'] = hpc_inventory
            print(f"✓ Generated HPC cluster inventory")

            # Log GPU detection results
            gpu_nodes = hpc_inventory.get('children', {}).get('hpc_gpu_nodes', {}).get('hosts', {})
            if gpu_nodes:
                print(f"✓ Detected {len(gpu_nodes)} GPU nodes in HPC cluster")
                for node_name, node_config in gpu_nodes.items():
                    gpu_count = node_config.get('gpu_count', 0)
                    print(f"  • {node_name}: {gpu_count} GPU(s)")

        # Generate Cloud cluster inventory
        cloud_inventory = self.generate_cloud_inventory()
        if cloud_inventory:
            inventory['all']['children']['cloud_cluster'] = cloud_inventory
            print(f"✓ Generated Cloud cluster inventory")

            # Log GPU detection results
            gpu_workers = cloud_inventory.get('children', {}).get('k8s_gpu_workers', {}).get('hosts', {})
            if gpu_workers:
                print(f"✓ Detected {len(gpu_workers)} GPU workers in Cloud cluster")
                for worker_name, worker_config in gpu_workers.items():
                    gpu_count = worker_config.get('gpu_count', 0)
                    print(f"  • {worker_name}: {gpu_count} GPU(s)")

        self.inventory = inventory
        return inventory

    def save_inventory(self, output_path: str = "inventories/hpc/hosts.yml") -> None:
        """Save generated inventory to YAML file."""
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)

        try:
            with open(output_file, 'w') as file:
                yaml.dump(self.inventory, file, default_flow_style=False, sort_keys=False, indent=2)

            print(f"✓ Inventory saved to {output_file}")

        except Exception as e:
            print(f"✗ Error saving inventory: {e}")
            raise

    def validate_inventory(self) -> bool:
        """Validate generated inventory structure."""
        if not self.inventory:
            print("✗ No inventory generated to validate")
            return False

        try:
            # Check basic structure
            if 'all' not in self.inventory:
                raise ValueError("Missing 'all' group in inventory")

            children = self.inventory['all'].get('children', {})
            if not children:
                raise ValueError("No cluster children defined in inventory")

            # Validate HPC cluster
            if 'hpc_cluster' in children:
                hpc_cluster = children['hpc_cluster']

                # Check for GRES configuration if GPU nodes exist
                gpu_nodes = hpc_cluster.get('children', {}).get('hpc_gpu_nodes', {}).get('hosts', {})
                if gpu_nodes:
                    gres_conf = hpc_cluster.get('vars', {}).get('slurm_gres_conf', [])
                    if not gres_conf:
                        raise ValueError("GPU nodes detected but no GRES configuration generated")

                    print(f"✓ GRES configuration validated: {len(gres_conf)} entries")

            # Validate YAML syntax
            yaml_str = yaml.dump(self.inventory)
            yaml.safe_load(yaml_str)

            print("✓ Inventory validation passed")
            return True

        except Exception as e:
            print(f"✗ Inventory validation failed: {e}")
            return False

    def print_summary(self) -> None:
        """Print inventory generation summary."""
        if not self.inventory:
            return

        print("\n" + "="*60)
        print("📋 INVENTORY GENERATION SUMMARY")
        print("="*60)

        all_children = self.inventory.get('all', {}).get('children', {})

        for cluster_name, cluster_config in all_children.items():
            print(f"\n🏗️  {cluster_name.upper().replace('_', ' ')}")
            print("-" * 40)

            children = cluster_config.get('children', {})
            total_hosts = 0

            for group_name, group_config in children.items():
                hosts = group_config.get('hosts', {})
                host_count = len(hosts)
                total_hosts += host_count

                if host_count > 0:
                    print(f"  📦 {group_name}: {host_count} host(s)")

                    # Show GPU details for GPU groups
                    if 'gpu' in group_name.lower():
                        total_gpus = 0
                        for host_name, host_config in hosts.items():
                            gpu_count = host_config.get('gpu_count', 0)
                            total_gpus += gpu_count

                        if total_gpus > 0:
                            print(f"    🎮 Total GPUs: {total_gpus}")

            print(f"  📊 Total hosts: {total_hosts}")

        print("\n" + "="*60)


def generate_inventory(cluster_config_path: str = "cluster.yaml") -> Dict[str, Any]:
    """Generate enhanced Ansible inventory structure."""
    generator = InventoryGenerator(cluster_config_path)

    try:
        # Generate inventory
        inventory = generator.generate_inventory()

        # Validate inventory
        if not generator.validate_inventory():
            raise ValueError("Inventory validation failed")

        # Save inventory
        generator.save_inventory()

        # Print summary
        generator.print_summary()

        return inventory

    except Exception as e:
        print(f"✗ Inventory generation failed: {e}")
        raise


if __name__ == "__main__":
    config_path = sys.argv[1] if len(sys.argv) > 1 else "cluster.yaml"
    generate_inventory(config_path)

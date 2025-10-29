#!/usr/bin/env python3
"""
Generate Kubespray inventory from cluster.yaml configuration for cloud cluster.

This script generates a Kubespray-compatible inventory.ini file from the cluster
configuration, mapping cloud cluster VMs to Kubernetes node groups.
"""

import sys
import yaml
import ipaddress
from pathlib import Path
from typing import Dict, List, Any

# Add parent directory to path to import ai_how utilities
sys.path.insert(0, str(Path(__file__).parent.parent / "python" / "ai_how" / "src"))

from ai_how.utils.virsh_utils import get_domain_ip, get_domain_state


def extract_cloud_cluster_nodes(config_data: Dict[str, Any], cluster_name: str) -> Dict[str, List[Dict[str, Any]]]:
    """Extract cloud cluster node information from configuration.

    Args:
        config_data: Parsed cluster configuration dictionary
        cluster_name: Name of the cloud cluster (typically "cloud")

    Returns:
        Dictionary with node groups: {
            'control_plane': [{'name': '...', 'ip': '...'}, ...],
            'cpu_workers': [{'name': '...', 'ip': '...'}, ...],
            'gpu_workers': [{'name': '...', 'ip': '...'}, ...]
        }
    """
    if 'clusters' not in config_data:
        raise ValueError("No clusters found in configuration")

    if cluster_name not in config_data['clusters']:
        raise ValueError(f"Cluster '{cluster_name}' not found in configuration")

    cluster = config_data['clusters'][cluster_name]
    nodes = {
        'control_plane': [],
        'cpu_workers': [],
        'gpu_workers': []
    }

    # Extract network configuration to determine subnet
    subnet_str = '192.168.200.0/24'  # Default fallback
    if 'network' in cluster and 'subnet' in cluster['network']:
        subnet_str = cluster['network']['subnet']

    # Parse subnet to calculate IP addresses
    try:
        network = ipaddress.IPv4Network(subnet_str, strict=False)
        network_base = str(network.network_address).split('.')[:3]  # Get base like ['192', '168', '200']
    except (ValueError, AttributeError) as e:
        raise ValueError(f"Invalid subnet configuration '{subnet_str}': {e}")

    # Extract control plane node and determine base IP offset
    control_plane_ip_offset = 10  # Default offset (e.g., .10 for 192.168.200.10)
    if 'control_plane' in cluster:
        control_plane = cluster['control_plane']
        control_plane_ip = control_plane.get('ip_address') or control_plane.get('ip', None)

        if control_plane_ip:
            # Extract last octet from control plane IP to determine offset
            control_plane_ip_parts = control_plane_ip.split('.')
            if len(control_plane_ip_parts) == 4:
                control_plane_ip_offset = int(control_plane_ip_parts[3])
        else:
            # Calculate default control plane IP from offset
            control_plane_ip = f"{'.'.join(network_base)}.{control_plane_ip_offset}"

        nodes['control_plane'].append({
            'name': 'control-plane',
            'ip': control_plane_ip,
            'ansible_host': control_plane_ip
        })

    # Extract worker nodes and calculate IP addresses to avoid collisions
    if 'worker_nodes' in cluster:
        worker_nodes = cluster['worker_nodes']

        # Count CPU workers to determine GPU worker starting offset
        cpu_worker_count = len(worker_nodes.get('cpu', []))
        # Add buffer to prevent collision (e.g., 10 IPs buffer)
        gpu_worker_start_offset = control_plane_ip_offset + cpu_worker_count + 10

        # CPU workers - start at control_plane + 1
        if 'cpu' in worker_nodes:
            for idx, node in enumerate(worker_nodes['cpu'], start=1):
                cpu_ip_offset = control_plane_ip_offset + idx
                default_cpu_ip = f"{'.'.join(network_base)}.{cpu_ip_offset}"
                cpu_ip = node.get('ip', default_cpu_ip)

                nodes['cpu_workers'].append({
                    'name': f"cpu-worker-{idx:02d}",
                    'ip': cpu_ip,
                    'ansible_host': cpu_ip
                })

        # GPU workers - start after all CPU workers with buffer
        if 'gpu' in worker_nodes:
            for idx, node in enumerate(worker_nodes['gpu'], start=1):
                gpu_ip_offset = gpu_worker_start_offset + idx
                default_gpu_ip = f"{'.'.join(network_base)}.{gpu_ip_offset}"
                gpu_ip = node.get('ip', default_gpu_ip)

                nodes['gpu_workers'].append({
                    'name': f"gpu-worker-{idx:02d}",
                    'ip': gpu_ip,
                    'ansible_host': gpu_ip
                })

    return nodes


def generate_kubespray_inventory(
    config_path: str,
    cluster_name: str,
    ssh_key_path: str = None,
    ssh_username: str = "admin",
    output_path: str = None
) -> str:
    """Generate Kubespray-compatible inventory from cluster configuration.

    Args:
        config_path: Path to cluster configuration YAML file
        cluster_name: Name of cluster to generate inventory for (typically "cloud")
        ssh_key_path: Path to SSH private key (default: build/shared/ssh-keys/id_rsa)
        ssh_username: SSH username (default: admin, matching Packer build)
        output_path: Optional path to write inventory file

    Returns:
        Generated inventory content as string
    """
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)

    # Extract node information
    nodes = extract_cloud_cluster_nodes(config, cluster_name)

    # Default SSH key path from Packer build system
    if ssh_key_path is None:
        project_root = Path(__file__).parent.parent
        ssh_key_path = project_root / "build" / "shared" / "ssh-keys" / "id_rsa"
        ssh_key_path = str(ssh_key_path.absolute())

    # Verify SSH key exists
    if not Path(ssh_key_path).exists():
        print(f"⚠️  WARNING: SSH private key not found at: {ssh_key_path}", file=sys.stderr)
        print(f"   Run 'make config' or build Packer images to generate SSH keys", file=sys.stderr)

    # SSH connection arguments for Kubespray
    ssh_args = f"ansible_ssh_private_key_file={ssh_key_path} ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'"

    inventory_lines = []

    # Expected libvirt domain names for cloud cluster
    domain_for = {
        "control-plane": f"{cluster_name}-cluster-control-plane",
        "cpu-worker-01": f"{cluster_name}-cluster-cpu-worker-01",
        "gpu-worker-01": f"{cluster_name}-cluster-gpu-worker-01",
    }

    # Override IPs when virsh reports them (and warn if they differ), and skip shut off VMs
    mismatches: List[str] = []
    for key in ["control_plane", "cpu_workers", "gpu_workers"]:
        filtered: List[Dict[str, Any]] = []
        for node in nodes[key]:
            host_label = node["name"]
            domain = domain_for.get(host_label)
            state = get_domain_state(domain) if domain else None
            if state and state.lower() != "running":
                # skip shut off VMs from inventory
                continue
            live_ip = get_domain_ip(domain) if domain else None
            if live_ip:
                if live_ip != node["ip"]:
                    mismatches.append(f"{host_label}: config={node['ip']} live={live_ip}")
                node["ip"] = live_ip
                node["ansible_host"] = live_ip
            filtered.append(node)
        nodes[key] = filtered

    if mismatches:
        print("⚠️  WARNING: Detected IP mismatches (config vs. live):", file=sys.stderr)
        for m in mismatches:
            print(f"   - {m}", file=sys.stderr)

    # Kubespray inventory format
    # [all] section - all nodes
    inventory_lines.append("[all]")
    all_nodes = []
    for node in nodes['control_plane']:
        all_nodes.append(f"{node['name']} ansible_host={node['ansible_host']} ip={node['ip']} ansible_user={ssh_username} {ssh_args}")
    for node in nodes['cpu_workers']:
        all_nodes.append(f"{node['name']} ansible_host={node['ansible_host']} ip={node['ip']} ansible_user={ssh_username} {ssh_args}")
    for node in nodes['gpu_workers']:
        all_nodes.append(f"{node['name']} ansible_host={node['ansible_host']} ip={node['ip']} ansible_user={ssh_username} {ssh_args}")

    inventory_lines.extend(all_nodes)
    inventory_lines.append("")

    # [kube_control_plane] section
    if nodes['control_plane']:
        inventory_lines.append("[kube_control_plane]")
        for node in nodes['control_plane']:
            inventory_lines.append(node['name'])
        inventory_lines.append("")

    # [etcd] section (typically same as control plane for small clusters)
    if nodes['control_plane']:
        inventory_lines.append("[etcd]")
        for node in nodes['control_plane']:
            inventory_lines.append(node['name'])
        inventory_lines.append("")

    # [kube_node] section - all worker nodes
    worker_nodes = nodes['cpu_workers'] + nodes['gpu_workers']
    if worker_nodes:
        inventory_lines.append("[kube_node]")
        for node in worker_nodes:
            inventory_lines.append(node['name'])
        inventory_lines.append("")

    # [calico_rr] section - empty (not using route reflectors)
    inventory_lines.append("[calico_rr]")
    inventory_lines.append("")

    # [k8s_cluster:children] section
    inventory_lines.append("[k8s_cluster:children]")
    inventory_lines.append("kube_control_plane")
    inventory_lines.append("kube_node")
    inventory_lines.append("calico_rr")
    inventory_lines.append("")

    inventory_content = "\n".join(inventory_lines)

    if output_path:
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as f:
            f.write(inventory_content)
        print(f"✅ Kubespray inventory written to: {output_path}")
        if ssh_key_path:
            print(f"   Using SSH key: {ssh_key_path}")
        print(f"   Using SSH username: {ssh_username}")
        print(f"   Control plane nodes: {len(nodes['control_plane'])}")
        print(f"   CPU worker nodes: {len(nodes['cpu_workers'])}")
        print(f"   GPU worker nodes: {len(nodes['gpu_workers'])}")

    return inventory_content


def main():
    if len(sys.argv) < 3:
        print("Usage: generate-kubespray-inventory.py <config_file> <cluster_name> [output_file] [ssh_key_path] [ssh_username]", file=sys.stderr)
        print("", file=sys.stderr)
        print("Arguments:", file=sys.stderr)
        print("  config_file        - Path to cluster configuration YAML", file=sys.stderr)
        print("  cluster_name       - Name of cloud cluster (typically 'cloud')", file=sys.stderr)
        print("  output_file        - (Optional) Path to write inventory (default: stdout)", file=sys.stderr)
        print("  ssh_key_path       - (Optional) Path to SSH private key", file=sys.stderr)
        print("  ssh_username       - (Optional) SSH username (default: admin)", file=sys.stderr)
        sys.exit(1)

    config_path = sys.argv[1]
    cluster_name = sys.argv[2]
    output_path = sys.argv[3] if len(sys.argv) > 3 else None
    ssh_key_path = sys.argv[4] if len(sys.argv) > 4 else None
    ssh_username = sys.argv[5] if len(sys.argv) > 5 else "admin"

    try:
        inventory = generate_kubespray_inventory(
            config_path, cluster_name, ssh_key_path, ssh_username, output_path
        )

        if not output_path:
            print(inventory)

    except Exception as e:
        print(f"❌ Error generating Kubespray inventory: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

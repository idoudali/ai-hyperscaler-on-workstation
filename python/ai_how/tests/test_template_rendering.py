#!/usr/bin/env python3
"""
Test script to verify that our VM templates render correctly with the new configuration.
"""

import sys
import uuid
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader


def test_template_rendering():
    """Test template rendering with the new hardware acceleration configuration."""

    # Find template directory
    template_dir = Path(__file__).parent.parent / "src" / "ai_how" / "vm_management" / "templates"
    if not template_dir.exists():
        print(f"❌ Template directory not found: {template_dir}")
        return False

    # Setup Jinja2 environment
    env = Environment(loader=FileSystemLoader(str(template_dir)))

    # Load sample configuration
    config_file = (
        Path(__file__).parent.parent.parent.parent / "config" / "example-multi-gpu-clusters.yaml"
    )
    if not config_file.exists():
        print(f"❌ Configuration file not found: {config_file}")
        return False

    with open(config_file) as f:
        config = yaml.safe_load(f)

    hpc_cluster = config["clusters"]["hpc"]

    # Test data for compute node with GPU passthrough
    compute_node_vars = {
        "vm_name": "test-compute-01",
        "vm_uuid": str(uuid.uuid4()),
        "memory_gb": 16,
        "cpu_cores": 8,
        "disk_path": "/var/lib/libvirt/images/test-compute-01.qcow2",
        "network_bridge": "virbr100",
        "mac_address": "52:54:00:12:34:56",
        "hardware": hpc_cluster.get("hardware", {}),
        "pcie_passthrough": {
            "enabled": True,
            "devices": [
                {
                    "pci_address": "0000:65:00.0",
                    "device_type": "gpu",
                    "vendor_id": "10de",
                    "device_id": "2684",
                    "iommu_group": 1,
                }
            ],
        },
    }

    # Test data for controller (no GPU passthrough)
    controller_vars = {
        "vm_name": "test-controller",
        "vm_uuid": str(uuid.uuid4()),
        "memory_gb": 8,
        "cpu_cores": 4,
        "disk_path": "/var/lib/libvirt/images/test-controller.qcow2",
        "network_bridge": "virbr100",
        "mac_address": "52:54:00:12:34:55",
        "hardware": hpc_cluster.get("hardware", {}),
    }

    # Test compute node template
    print("🔍 Testing compute_node.xml.j2 template...")
    try:
        template = env.get_template("compute_node.xml.j2")
        rendered = template.render(**compute_node_vars)

        # Basic checks
        if "host-passthrough" not in rendered:
            print("❌ CPU model not found in rendered template")
            return False

        if "vmx" not in rendered or "svm" not in rendered:
            print("❌ CPU features not found in rendered template")
            return False

        if "hostdev" not in rendered:
            print("❌ PCIe passthrough not found in rendered template")
            return False

        if "graphics type='none'" not in rendered:
            print("❌ Graphics should be disabled for GPU passthrough")
            return False

        print("✅ Compute node template rendered successfully")

    except Exception as e:
        print(f"❌ Error rendering compute node template: {e}")
        return False

    # Test controller template
    print("🔍 Testing controller.xml.j2 template...")
    try:
        template = env.get_template("controller.xml.j2")
        rendered = template.render(**controller_vars)

        # Basic checks
        if "host-passthrough" not in rendered:
            print("❌ CPU model not found in controller template")
            return False

        if "vmx" not in rendered or "svm" not in rendered:
            print("❌ CPU features not found in controller template")
            return False

        # Controller should have VNC graphics
        if "graphics type='vnc'" not in rendered:
            print("❌ Controller should have VNC graphics enabled")
            return False

        print("✅ Controller template rendered successfully")

    except Exception as e:
        print(f"❌ Error rendering controller template: {e}")
        return False

    # Test network template
    print("🔍 Testing cluster_network.xml.j2 template...")
    try:
        template = env.get_template("cluster_network.xml.j2")

        network_vars = {
            "cluster_name": "test-cluster",
            "bridge_name": "virbr100",
            "gateway_ip": "192.168.100.1",
            "netmask": "255.255.255.0",
            "dhcp_start": "192.168.100.10",
            "dhcp_end": "192.168.100.254",
            "static_leases": {
                "test-controller": "192.168.100.10",
                "test-compute-01": "192.168.100.11",
            },
            "vm_macs": {
                "test-controller": "52:54:00:12:34:55",
                "test-compute-01": "52:54:00:12:34:56",
            },
            "dns_servers": ["8.8.8.8", "1.1.1.1"],
        }

        rendered = template.render(**network_vars)

        if "test-cluster-network" not in rendered:
            print("❌ Cluster network name not found")
            return False

        print("✅ Network template rendered successfully")

    except Exception as e:
        print(f"❌ Error rendering network template: {e}")
        return False

    return True


def main():
    """Main test function."""
    print("🚀 Testing template rendering with KVM acceleration and GPU passthrough...")
    print("=" * 70)

    success = test_template_rendering()

    print("=" * 70)
    if success:
        print("✅ All template rendering tests passed!")
        return 0
    else:
        print("❌ Template rendering tests failed!")
        return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
Test script to verify template rendering with updated hardware configuration.
"""

import sys
import uuid
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader


def test_template_with_hardware_config():
    """Test template rendering with the new hardware configuration structure."""

    # Find template directory
    template_dir = Path(__file__).parent.parent / "src" / "ai_how" / "vm_management" / "templates"
    if not template_dir.exists():
        print(f"❌ Template directory not found: {template_dir}")
        return False

    # Setup Jinja2 environment
    env = Environment(loader=FileSystemLoader(str(template_dir)))

    # Load sample configuration
    config_file = Path(__file__).parent.parent.parent.parent / "config" / "template-cluster.yaml"
    if not config_file.exists():
        print(f"❌ Configuration file not found: {config_file}")
        return False

    with open(config_file) as f:
        config = yaml.safe_load(f)

    hpc_cluster = config["clusters"]["hpc"]

    # Test data for compute node with GPU passthrough from actual config
    compute_node_config = hpc_cluster["compute_nodes"][0]  # First compute node

    template_vars = {
        "vm_name": "test-compute-01",
        "vm_uuid": str(uuid.uuid4()),
        "memory_gb": compute_node_config["memory_gb"],
        "cpu_cores": compute_node_config["cpu_cores"],
        "disk_path": "/var/lib/libvirt/images/test-compute-01.qcow2",
        "network_bridge": hpc_cluster["network"]["bridge"],
        "ip_address": compute_node_config["ip"],
        "mac_address": "52:54:00:12:34:56",
        # Hardware configuration from cluster
        "hardware": hpc_cluster.get("hardware", {}),
        # PCIe passthrough configuration from individual node
        "pcie_passthrough": compute_node_config.get("pcie_passthrough", {}),
    }

    # Test compute node template
    print("🔍 Testing compute_node.xml.j2 template with hardware config...")
    try:
        template = env.get_template("compute_node.xml.j2")
        rendered = template.render(**template_vars)

        # Check for key elements
        checks = [
            ("host-passthrough" in rendered, "CPU model not found"),
            ("vmx" in rendered or "svm" in rendered, "CPU features not found"),
            ("kvm" in rendered.lower(), "KVM configuration not found"),
            ("hostdev" in rendered, "PCIe passthrough not found"),
            (
                "bus='0x65'" in rendered and "slot='0x00'" in rendered,
                "GPU PCI address components not found",
            ),
            ("0x10de" in rendered and "0x2684" in rendered, "GPU vendor/device IDs not found"),
        ]

        success = True
        for check, error_msg in checks:
            if not check:
                print(f"❌ {error_msg}")
                success = False

        if success:
            print("✅ Compute node template rendered successfully with hardware config")

            # Print relevant sections for debugging
            print("\n📋 Template sections found:")
            if "host-passthrough" in rendered:
                print("  ✓ CPU model: host-passthrough")
            if "vmx" in rendered:
                print("  ✓ CPU features: VMX/SVM enabled")
            if "hostdev" in rendered:
                print("  ✓ PCIe passthrough: GPU device configured")
        else:
            # Debug PCIe passthrough issue
            print(f"\n📋 PCIe passthrough config: {template_vars['pcie_passthrough']}")
            print("\n📋 Looking for PCIe devices in rendered template:")
            lines = rendered.split("\n")
            found_pcie = False
            in_hostdev = False
            for i, line in enumerate(lines):
                if "hostdev" in line.lower():
                    in_hostdev = True
                    found_pcie = True
                    print(f"  Line {i}: {line.strip()}")
                elif in_hostdev:
                    print(f"  Line {i}: {line.strip()}")
                    if "</hostdev>" in line:
                        in_hostdev = False
                elif "pcie" in line.lower() or "0000:" in line:
                    print(f"  Line {i}: {line.strip()}")
                    found_pcie = True
            if not found_pcie:
                print("  No PCIe-related lines found in template")

        return success

    except Exception as e:
        print(f"❌ Error rendering compute node template: {e}")
        # Print template variables for debugging
        print("Template variables:")
        for key, value in template_vars.items():
            if key == "pcie_passthrough":
                print(f"  {key}: {type(value)} = {value}")
            else:
                print(f"  {key}: {type(value)}")

        # Also print the rendered template for debugging
        try:
            template = env.get_template("compute_node.xml.j2")
            rendered = template.render(**template_vars)
            print("\n📋 Rendered template (first 2000 chars):")
            print(rendered[:2000])
            print("\n📋 PCIe passthrough section:")
            lines = rendered.split("\n")
            in_hostdev = False
            for line in lines:
                if "hostdev" in line.lower() or in_hostdev:
                    print(f"  {line}")
                    in_hostdev = "hostdev" in line.lower()
                    if "</hostdev>" in line:
                        in_hostdev = False
        except Exception as render_e:
            print(f"Could not render template for debugging: {render_e}")

        return False


def main():
    """Main test function."""
    print("🚀 Testing template fixes with hardware configuration...")
    print("=" * 70)

    success = test_template_with_hardware_config()

    print("=" * 70)
    if success:
        print("✅ Template rendering tests with hardware config passed!")
        return 0
    else:
        print("❌ Template rendering tests failed!")
        return 1


if __name__ == "__main__":
    sys.exit(main())

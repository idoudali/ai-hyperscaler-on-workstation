# PCIe Passthrough Validation

The AI-HOW CLI includes comprehensive validation for PCIe passthrough
configuration, ensuring that devices are properly configured for GPU and other
device passthrough to VMs.

> **Note**: For core PCIe passthrough concepts, see [Common Concepts - PCIe Passthrough](common-concepts.md).

## Overview

PCIe passthrough validation checks:

1. **System Requirements**: IOMMU, VFIO modules, KVM support
2. **Device Configuration**: PCI address format, device types, vendor/device IDs
3. **Driver Binding**: Ensures devices are bound to VFIO instead of conflicting
   drivers
4. **Availability**: Verifies devices exist and are accessible

## Usage

### Basic Validation

```bash
# Validate configuration with PCIe passthrough checks
ai-how validate config/cluster.yaml

# Skip PCIe validation (schema only)
ai-how validate --skip-pcie-validation config/cluster.yaml
```

### PCIe Device Inventory

```bash
# Show all PCIe devices and their driver binding status
ai-how inventory pcie
```

## Validation Checks

### 1. System Requirements

- **Architecture**: x86_64 only (PCIe passthrough not supported on other
  architectures)
- **KVM**: Must be available and loaded
- **VFIO Modules**: `vfio`, `vfio_iommu_type1`, `vfio_pci` must be loaded
- **IOMMU**: Must be enabled in kernel (Intel VT-d or AMD IOMMU)

### 2. Device Configuration

- **PCI Address Format**: Must match `0000:xx:xx.x` pattern
- **Device Types**: `gpu`, `network`, `storage`, `audio`, `other`
- **Required Fields**: `pci_address`, `device_type`
- **Optional Fields**: `vendor_id`, `device_id`, `iommu_group`

### 3. Driver Binding

- **VFIO Driver**: Devices must be bound to VFIO driver
- **No Conflicts**: Devices must not be bound to NVIDIA, Nouveau, or other
  conflicting drivers
- **IOMMU Groups**: Devices in same IOMMU group must be passed together

## Configuration Example

```yaml
compute_nodes:
  - name: "gpu-node-01"
    pcie_passthrough:
      enabled: true
      devices:
        - pci_address: "0000:01:00.0"
          device_type: "gpu"
          vendor_id: "10de"
          device_id: "2684"
        - pci_address: "0000:01:00.1"
          device_type: "audio"
          vendor_id: "10de"
          device_id: "22bd"
```

## Troubleshooting

### Common Issues

1. **IOMMU Not Enabled**

   ```text
   Error: IOMMU is not enabled. Required kernel parameters: intel_iommu=on or amd_iommu=on
   ```

   **Solution**: Add `intel_iommu=on` (Intel) or `amd_iommu=on` (AMD) to kernel
   command line

2. **VFIO Modules Not Loaded**

   ```text
   Error: Missing required VFIO modules: ['vfio', 'vfio_iommu_type1', 'vfio_pci']
   ```

   **Solution**: Load modules: `sudo modprobe vfio vfio_iommu_type1 vfio_pci`

3. **Device Bound to Conflicting Driver**

   ```text
   Error: PCIe device 0000:01:00.0 is bound to a conflicting driver
   ```

   **Solution**: Unbind from NVIDIA driver and bind to VFIO:

   ```bash
   echo "0000:01:00.0" > /sys/bus/pci/drivers/nvidia/unbind
   echo "0000:01:00.0" > /sys/bus/pci/drivers/vfio-pci/bind
   ```

### Manual Device Binding

```bash
# List PCI devices
lspci -nnk

# Check current driver binding
ls -la /sys/bus/pci/devices/0000:01:00.0/driver

# Unbind from current driver
echo "0000:01:00.0" > /sys/bus/pci/devices/0000:01:00.0/driver/unbind

# Bind to VFIO driver
echo "0000:01:00.0" > /sys/bus/pci/drivers/vfio-pci/bind

# Verify binding
ls -la /sys/bus/pci/devices/0000:01:00.0/driver
```

## Performance Considerations

- **IOMMU Groups**: Plan device assignments to minimize IOMMU group conflicts
- **Memory**: Use hugepages for better GPU performance
- **CPU Pinning**: Pin VM CPUs to specific host cores for consistent performance
- **NUMA**: Keep GPUs and VM memory on same NUMA node

## Security Notes

- PCIe passthrough bypasses hypervisor isolation
- Devices have direct access to host memory
- Ensure proper VM isolation and access controls
- Monitor device usage and access patterns

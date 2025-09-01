"""GPU mapping utility for VM status reporting."""

import logging
import subprocess

logger = logging.getLogger(__name__)


class GPUMapper:
    """Maps PCI addresses to GPU models for VM status reporting."""

    def __init__(self):
        """Initialize the GPU mapper."""
        self._gpu_cache: dict[str, str] = {}
        self._load_gpu_mappings()

    def _load_gpu_mappings(self) -> None:
        """Load GPU mappings from system using lspci."""
        try:
            # Get all VGA and 3D controllers (GPUs)
            result = subprocess.run(["lspci", "-nn"], capture_output=True, text=True, check=True)

            for line in result.stdout.splitlines():
                if "vga" in line.lower() or "3d" in line.lower():
                    # Parse PCI address and device info
                    # Format: "01:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD106
                    # [GeForce RTX 4060 Ti 16GB] [10de:2805] (rev a1)"
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        pci_addr = parts[0]
                        # Extract model name from the line
                        model = self._extract_gpu_model(line)
                        if model:
                            # Convert to full PCI address format
                            full_pci_addr = f"0000:{pci_addr}"
                            self._gpu_cache[full_pci_addr] = model
                            logger.debug(f"Mapped GPU {full_pci_addr} -> {model}")

        except subprocess.CalledProcessError as e:
            logger.warning(f"Failed to load GPU mappings: {e}")
        except Exception as e:
            logger.warning(f"Unexpected error loading GPU mappings: {e}")

    def _extract_gpu_model(self, lspci_line: str) -> str | None:
        """Extract GPU model name from lspci output line."""
        try:
            # Look for NVIDIA GPU models in the line
            if "nvidia" in lspci_line.lower() and "[" in lspci_line and "]" in lspci_line:
                # Find the model name in brackets
                start = lspci_line.find("[")
                end = lspci_line.find("]", start)
                if start != -1 and end != -1:
                    model = lspci_line[start + 1 : end]
                    # Clean up the model name
                    if (
                        "geforce" in model.lower()
                        or "rtx" in model.lower()
                        or "gtx" in model.lower()
                    ):
                        return model.strip()

                    # If no clear model name, try to extract from the full line
                    if "nvidia corporation" in lspci_line.lower():
                        # Extract after "NVIDIA Corporation"
                        nvidia_part = lspci_line.lower().split("nvidia corporation")[1]
                        if "[" in nvidia_part:
                            model_start = nvidia_part.find("[") + 1
                            model_end = nvidia_part.find("]", model_start)
                            if model_start > 0 and model_end > model_start:
                                return nvidia_part[model_start:model_end].strip()

            return None
        except Exception as e:
            logger.debug(f"Failed to extract GPU model from line '{lspci_line}': {e}")
            return None

    def get_gpu_model(self, pci_address: str) -> str | None:
        """Get GPU model for a given PCI address."""
        # Try exact match first
        if pci_address in self._gpu_cache:
            return self._gpu_cache[pci_address]

        # Try without leading zeros
        if pci_address.startswith("0000:"):
            short_addr = pci_address[5:]  # Remove "0000:"
            for full_addr, model in self._gpu_cache.items():
                if full_addr.endswith(short_addr):
                    return model

        return None

    def get_gpu_info_from_pcie_config(self, pcie_config: dict) -> str | None:
        """Extract GPU information from PCIe passthrough configuration.

        Returns a formatted string with both PCI address and GPU model name.
        """
        if not pcie_config or not pcie_config.get("enabled"):
            return None

        devices = pcie_config.get("devices", [])
        gpu_info_list = []

        for device in devices:
            if device.get("device_type") == "gpu":
                pci_address = device.get("pci_address")
                if pci_address:
                    model = self.get_gpu_model(pci_address)
                    if model:
                        # Format: "PCI_ADDRESS (MODEL_NAME)"
                        gpu_info_list.append(f"{pci_address} ({model})")
                    else:
                        # If model not found, just show PCI address
                        gpu_info_list.append(pci_address)

        if gpu_info_list:
            return ", ".join(gpu_info_list)

        return None

    def get_gpu_info_with_pci(self, pci_address: str) -> str | None:
        """Get GPU information with PCI address and model name.

        Returns a formatted string: "PCI_ADDRESS (MODEL_NAME)"
        """
        model = self.get_gpu_model(pci_address)
        if model:
            return f"{pci_address} ({model})"
        return pci_address


# Global instance for reuse
_gpu_mapper = None


def get_gpu_mapper() -> GPUMapper:
    """Get the global GPU mapper instance."""
    global _gpu_mapper
    if _gpu_mapper is None:
        _gpu_mapper = GPUMapper()
    return _gpu_mapper

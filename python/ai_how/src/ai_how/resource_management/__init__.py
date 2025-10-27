"""Resource management for shared GPU allocation and conflict detection."""

from ai_how.resource_management.gpu_allocator import GPUResourceAllocator
from ai_how.resource_management.shared_gpu_validator import SharedGPUValidator

__all__ = ["GPUResourceAllocator", "SharedGPUValidator"]

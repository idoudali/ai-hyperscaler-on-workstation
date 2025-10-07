#!/bin/bash
# Entrypoint script for PyTorch container

set -e

# Display environment information
echo "=== PyTorch HPC Container ==="
echo "Python: $(python3 --version)"
echo "PyTorch: $(python3 -c 'import torch; print(torch.__version__)')"
echo "CUDA Available: $(python3 -c 'import torch; print(torch.cuda.is_available())')"

if python3 -c 'import torch; exit(0 if torch.cuda.is_available() else 1)' 2>/dev/null; then
    echo "CUDA Devices: $(python3 -c 'import torch; print(torch.cuda.device_count())')"
    echo "CUDA Version: $(python3 -c 'import torch; print(torch.version.cuda)')"
fi

echo "MPI: $(mpirun --version | head -n 1)"
echo "=============================="

# Execute command or start bash
if [ $# -eq 0 ]; then
    exec /bin/bash
else
    exec "$@"
fi

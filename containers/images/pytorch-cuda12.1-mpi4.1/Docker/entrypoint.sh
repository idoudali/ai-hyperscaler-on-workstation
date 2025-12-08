#!/bin/bash
# Entrypoint script for PyTorch container

set -e

# Activate Python virtual environment
# This ensures PyTorch and other packages installed in /venv are available
if [ -f "/venv/bin/activate" ]; then
    source /venv/bin/activate
fi

# Ensure PATH includes venv bin directory (in case activation didn't work)
export PATH="/venv/bin:${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

# Execute command or start bash
if [ $# -eq 0 ]; then
    exec /bin/bash
else
    exec "$@"
fi

#!/usr/bin/env bash
#
# Monitoring Test Helper Functions
#

# Check if a Python package is installed
# Usage: check_python_package "package_name"
check_python_package() {
    local package="$1"
    python3 -c "import $package" >/dev/null 2>&1
}

# Skip test if Python package is not installed
skip_if_no_package() {
    local package="$1"
    if ! check_python_package "$package"; then
        skip "Python package '$package' not installed"
    fi
}

# Skip test if monitoring directory does not exist
skip_if_no_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        skip "Directory '$dir' does not exist"
    fi
}

# Check if a port is in use (server running)
# Usage: check_port_listening "port"
check_port_listening() {
    local port="$1"
    # Try using netcat if available, else ss or netstat
    if command -v nc >/dev/null 2>&1; then
        nc -z localhost "$port"
        return $?
    elif command -v ss >/dev/null 2>&1; then
        ss -tuln | grep -q ":$port "
        return $?
    else
        # Fallback: check if we can connect via python
        python3 -c "import socket; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); result = s.connect_ex(('localhost', $port)); s.close(); exit(result)"
        return $?
    fi
}

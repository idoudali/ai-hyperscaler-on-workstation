#!/bin/bash

# Test script for HPC Base Packages Role
# This script tests the Ansible role locally

set -e

echo "=== Testing HPC Base Packages Role ==="

# Check if we're in the right directory
if [ ! -f "ansible.cfg" ]; then
    echo "Error: Must run from ansible directory"
    exit 1
fi

# Check if Ansible is available
if ! command -v ansible-playbook &> /dev/null; then
    echo "Error: Ansible not found. Please install it first."
    exit 1
fi

# Test the role syntax
echo "Testing role syntax..."
ansible-playbook --syntax-check playbooks/playbook-hpc-packer.yml

# Test the role in check mode (dry run)
echo "Testing role in check mode..."
ansible-playbook --check --diff playbooks/playbook-hpc-packer.yml

echo "=== Role syntax and check mode tests passed ==="
echo "Note: This is a dry-run test. The role is ready for use with Packer."

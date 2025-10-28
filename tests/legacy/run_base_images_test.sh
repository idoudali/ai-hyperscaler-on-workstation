#!/bin/bash
# Base Images Test Runner
# Streamlined runner for building and validating Packer base images

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_IMAGES_TEST_SCRIPT="$SCRIPT_DIR/test_base_images.sh"

# Make test script executable if it isn't
[[ -x "$BASE_IMAGES_TEST_SCRIPT" ]] || chmod +x "$BASE_IMAGES_TEST_SCRIPT"

# Run base images test directly
exec "$BASE_IMAGES_TEST_SCRIPT" "$@"

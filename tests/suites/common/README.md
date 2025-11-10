# Common Test Utilities

Shared utilities, helpers, and configuration used across all test suites.

## Utility Scripts

- **suite-config.sh** - Common configuration and environment variables
- **suite-logging.sh** - Logging functions and test output formatting
- **suite-test-runner.sh** - Test execution framework and result tracking
- **suite-check-helpers.sh** - Helper functions for common test assertions
- **suite-utils.sh** - General utility functions used across test suites
- **test-shared-utilities.sh** - Unit tests for shared utility functions

## Purpose

Provides reusable components that ensure consistency across all test suites including:

- Standardized logging and output formatting
- Common configuration management
- Test result tracking and reporting
- SSH connectivity helpers
- File existence and content checks
- Service status validation

## Usage

Source these scripts in your test suite:

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/suite-config.sh"
source "${SCRIPT_DIR}/../common/suite-logging.sh"
source "${SCRIPT_DIR}/../common/suite-check-helpers.sh"
```

## Dependencies

None - this is the base utility layer used by all other test suites.

#!/usr/bin/env python3
"""Example script demonstrating how to use the cluster schema."""

import sys
from pathlib import Path

# Add the src directory to the Python path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from ai_how.schemas import (
    get_required_fields,
    get_schema_description,
    get_schema_title,
    get_schema_version,
)


def main():
    """Demonstrate schema usage."""
    print("=== Cluster Schema Usage Example ===\n")

    # Access basic schema information
    print(f"Schema Title: {get_schema_title()}")
    print(f"Schema Description: {get_schema_description()}")
    print(f"Schema Version Pattern: {get_schema_version()}")
    print(f"Required Fields: {', '.join(get_required_fields())}")

    # Note: Direct schema access is no longer available with lazy loading
    # Use the provided functions to access schema information
    print("\nNote: Schema is now loaded lazily to prevent import failures.")
    print("Use the provided functions to access schema information safely.")

    print("\n=== Schema functions available successfully! ===")


if __name__ == "__main__":
    main()

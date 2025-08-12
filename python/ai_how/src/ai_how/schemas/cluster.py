"""Cluster configuration schema for the ai-how package."""

import json
import logging
import threading
from importlib import resources
from typing import Any

# Lazy-load the schema when needed with thread safety
_CLUSTER_SCHEMA: dict[str, Any] | None = None
_CLUSTER_SCHEMA_LOCK = threading.Lock()

# Create a logger instance for this module
logger = logging.getLogger(__name__)


def _get_cluster_schema() -> dict[str, Any]:
    """Get the cluster schema, loading it if not already loaded."""
    global _CLUSTER_SCHEMA
    if _CLUSTER_SCHEMA is None:
        with _CLUSTER_SCHEMA_LOCK:
            if _CLUSTER_SCHEMA is None:
                _CLUSTER_SCHEMA = _load_schema()
    return _CLUSTER_SCHEMA


def _load_schema() -> dict[str, Any]:
    """Load the cluster schema from package resources."""
    try:
        with resources.files("ai_how.schemas").joinpath("cluster.schema.json").open("r") as f:
            return json.load(f)
    except (ModuleNotFoundError, FileNotFoundError) as e:
        # Log the error for debugging but don't fail import
        logger.warning(f"Failed to load cluster schema from package: {e}")
        # Return a minimal schema to prevent import failures
        return {"type": "object", "properties": {}}
    except json.JSONDecodeError as e:
        # Log the error for debugging but don't fail import
        logger.warning(f"Failed to parse cluster schema: {e}")
        # Return a minimal schema to prevent import failures
        return {"type": "object", "properties": {}}


def get_schema_version() -> str:
    """Get the schema version from the properties.

    Expected schema structure:
    {
        "properties": {
            "version": {
                "pattern": <str>
            }
        }
    }

    Returns:
        The schema version pattern string, or "unknown" if the schema structure
        doesn't match expectations or if the schema cannot be loaded.
    """
    try:
        schema = _get_cluster_schema()
        properties = schema.get("properties")
        if not isinstance(properties, dict):
            return "unknown"
        version = properties.get("version")
        if not isinstance(version, dict):
            return "unknown"
        pattern = version.get("pattern")
        if not isinstance(pattern, str):
            return "unknown"
        return pattern
    except Exception:
        return "unknown"


def get_schema_title() -> str:
    """Get the schema title."""
    try:
        schema = _get_cluster_schema()
        return schema.get("title", "Unknown Schema")
    except Exception:
        return "Unknown Schema"


def get_schema_description() -> str:
    """Get the schema description."""
    try:
        schema = _get_cluster_schema()
        return schema.get("description", "No description available")
    except Exception:
        return "No description available"


def get_required_fields() -> list[str]:
    """Get the list of required fields."""
    try:
        schema = _get_cluster_schema()
        return schema.get("required", [])
    except Exception:
        return []

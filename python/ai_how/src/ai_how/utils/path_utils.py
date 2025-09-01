"""Path utility functions for AI-HOW."""

from pathlib import Path
from typing import Union


def resolve_path(path: Union[str, Path], base_dir: Union[str, Path] | None = None) -> Path:
    """
    Resolve a path to an absolute path.

    If the path is already absolute, it is returned as-is.
    If the path is relative, it is resolved relative to the base directory
    (defaults to current working directory).

    Args:
        path: The path to resolve (can be absolute or relative)
        base_dir: Base directory for resolving relative paths (defaults to cwd)

    Returns:
        Absolute Path object

    Raises:
        ValueError: If the resolved path doesn't exist
    """
    path_obj = Path(path)

    # If path is already absolute, return as-is
    if path_obj.is_absolute():
        return path_obj

    # Resolve relative to base directory
    base_dir = Path.cwd() if base_dir is None else Path(base_dir)

    resolved_path = base_dir / path_obj

    return resolved_path


def validate_qcow2_file(file_path: Union[str, Path]) -> Path:
    """
    Validate that a file exists and is a qcow2 image.

    Args:
        file_path: Path to the qcow2 file

    Returns:
        Path object of the validated file

    Raises:
        FileNotFoundError: If the file doesn't exist
        ValueError: If the file is not a qcow2 image
    """
    path_obj = Path(file_path)

    if not path_obj.exists():
        raise FileNotFoundError(f"Image file not found: {path_obj}")

    if not path_obj.is_file():
        raise ValueError(f"Path is not a file: {path_obj}")

    # Check file extension
    if path_obj.suffix.lower() != ".qcow2":
        raise ValueError(f"File must have .qcow2 extension: {path_obj}")

    return path_obj


def resolve_and_validate_image_path(
    image_path: Union[str, Path], base_dir: Union[str, Path] | None = None
) -> Path:
    """
    Resolve a relative or absolute image path and validate it's a qcow2 file.

    Args:
        image_path: Path to the image file (can be relative or absolute)
        base_dir: Base directory for resolving relative paths (defaults to cwd)

    Returns:
        Absolute Path object of the validated qcow2 file

    Raises:
        FileNotFoundError: If the file doesn't exist
        ValueError: If the file is not a qcow2 image
    """
    resolved_path = resolve_path(image_path, base_dir)
    return validate_qcow2_file(resolved_path)

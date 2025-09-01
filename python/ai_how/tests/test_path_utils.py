"""Tests for path utility functions."""

from pathlib import Path
from unittest.mock import patch

import pytest

from ai_how.utils.path_utils import (
    resolve_and_validate_image_path,
    resolve_path,
    validate_qcow2_file,
)


class TestResolvePath:
    """Test the resolve_path function."""

    def test_resolve_absolute_path(self):
        """Test that absolute paths are returned as-is."""
        absolute_path = "/absolute/path/to/file.qcow2"
        result = resolve_path(absolute_path)
        assert result == Path(absolute_path)

    def test_resolve_relative_path_with_default_base(self):
        """Test that relative paths are resolved relative to current working directory."""
        relative_path = "relative/path/file.qcow2"

        with patch("pathlib.Path.cwd") as mock_cwd:
            mock_cwd.return_value = Path("/current/working/directory")
            result = resolve_path(relative_path)

        expected = Path("/current/working/directory") / relative_path
        assert result == expected

    def test_resolve_relative_path_with_custom_base(self):
        """Test that relative paths are resolved relative to custom base directory."""
        relative_path = "relative/path/file.qcow2"
        base_dir = Path("/custom/base/directory")

        result = resolve_path(relative_path, base_dir)
        expected = base_dir / relative_path
        assert result == expected

    def test_resolve_path_object_input(self):
        """Test that Path objects are handled correctly."""
        path_obj = Path("relative/path/file.qcow2")
        base_dir = Path("/custom/base/directory")

        result = resolve_path(path_obj, base_dir)
        expected = base_dir / path_obj
        assert result == expected


class TestValidateQcow2File:
    """Test the validate_qcow2_file function."""

    def test_validate_existing_qcow2_file(self, tmp_path):
        """Test validation of an existing qcow2 file."""
        qcow2_file = tmp_path / "test.qcow2"
        qcow2_file.touch()

        result = validate_qcow2_file(qcow2_file)
        assert result == qcow2_file

    def test_validate_nonexistent_file(self):
        """Test validation fails for non-existent file."""
        nonexistent_file = Path("/nonexistent/file.qcow2")

        with pytest.raises(FileNotFoundError, match="Image file not found"):
            validate_qcow2_file(nonexistent_file)

    def test_validate_directory(self, tmp_path):
        """Test validation fails for directory."""
        directory = tmp_path / "test.qcow2"
        directory.mkdir()

        with pytest.raises(ValueError, match="Path is not a file"):
            validate_qcow2_file(directory)

    def test_validate_wrong_extension(self, tmp_path):
        """Test validation fails for files without .qcow2 extension."""
        wrong_ext_file = tmp_path / "test.img"
        wrong_ext_file.touch()

        with pytest.raises(ValueError, match="File must have .qcow2 extension"):
            validate_qcow2_file(wrong_ext_file)

    def test_validate_case_insensitive_extension(self, tmp_path):
        """Test validation accepts case variations of .qcow2 extension."""
        qcow2_file = tmp_path / "test.QCOW2"
        qcow2_file.touch()

        result = validate_qcow2_file(qcow2_file)
        assert result == qcow2_file


class TestResolveAndValidateImagePath:
    """Test the resolve_and_validate_image_path function."""

    def test_resolve_and_validate_absolute_path(self, tmp_path):
        """Test resolution and validation of absolute path."""
        qcow2_file = tmp_path / "test.qcow2"
        qcow2_file.touch()

        result = resolve_and_validate_image_path(str(qcow2_file))
        assert result == qcow2_file

    def test_resolve_and_validate_relative_path(self, tmp_path):
        """Test resolution and validation of relative path."""
        qcow2_file = tmp_path / "test.qcow2"
        qcow2_file.touch()

        with patch("pathlib.Path.cwd") as mock_cwd:
            mock_cwd.return_value = tmp_path
            result = resolve_and_validate_image_path("test.qcow2")

        assert result == qcow2_file

    def test_resolve_and_validate_relative_path_with_custom_base(self, tmp_path):
        """Test resolution and validation of relative path with custom base."""
        qcow2_file = tmp_path / "test.qcow2"
        qcow2_file.touch()

        result = resolve_and_validate_image_path("test.qcow2", tmp_path)
        assert result == qcow2_file

    def test_resolve_and_validate_nonexistent_file(self):
        """Test resolution and validation fails for non-existent file."""
        with pytest.raises(FileNotFoundError, match="Image file not found"):
            resolve_and_validate_image_path("/nonexistent/file.qcow2")

    def test_resolve_and_validate_wrong_extension(self, tmp_path):
        """Test resolution and validation fails for wrong extension."""
        wrong_ext_file = tmp_path / "test.img"
        wrong_ext_file.touch()

        with pytest.raises(ValueError, match="File must have .qcow2 extension"):
            resolve_and_validate_image_path(str(wrong_ext_file))

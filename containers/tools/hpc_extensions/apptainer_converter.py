"""
Apptainer converter for Docker images.

Extends docker-wrapper functionality to convert Docker images to
Apptainer format for HPC cluster deployment.
"""

import os
import subprocess
import tempfile
from pathlib import Path
from typing import Optional
import logging

logger = logging.getLogger(__name__)


class ApptainerConverter:
    """Convert Docker images to Apptainer format."""

    def __init__(self, apptainer_cmd: str = "apptainer"):
        """
        Initialize Apptainer converter.

        Args:
            apptainer_cmd: Command to use (apptainer or singularity for backward compatibility)
        """
        self.apptainer_cmd = apptainer_cmd
        self._check_apptainer_available()

    def _check_apptainer_available(self) -> bool:
        """Check if Apptainer is available."""
        try:
            result = subprocess.run(
                [self.apptainer_cmd, "--version"],
                capture_output=True,
                text=True,
                stdin=subprocess.DEVNULL,
                check=True
            )
            logger.info(f"Found {self.apptainer_cmd}: {result.stdout.strip()}")
            return True
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            logger.error(f"Apptainer not found: {e}")
            return False

    def convert_docker_to_apptainer(
        self,
        docker_image: str,
        output_path: str,
        force: bool = False
    ) -> bool:
        """
        Convert Docker image to Apptainer format.

        Args:
            docker_image: Docker image name/tag
            output_path: Output path for .sif file
            force: Overwrite existing file

        Returns:
            True if conversion successful
        """
        output_path = Path(output_path)

        # Check if output exists
        if output_path.exists() and not force:
            logger.error(f"Output file already exists: {output_path}")
            return False

        # Create output directory if needed
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Convert using apptainer build
        logger.info(f"Converting {docker_image} to Apptainer...")

        try:
            cmd = [
                self.apptainer_cmd,
                "build",
            ]

            if force:
                cmd.append("--force")

            cmd.extend([
                str(output_path),
                f"docker-daemon://{docker_image}"
            ])

            # Set environment to ensure non-interactive behavior
            env = os.environ.copy()
            env['APPTAINER_DISABLE_CACHE'] = 'false'
            env['APPTAINER_SILENT'] = 'true'

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                stdin=subprocess.DEVNULL,
                env=env,
                check=True
            )

            logger.info(f"Successfully converted to {output_path}")
            logger.debug(result.stdout)
            return True

        except subprocess.CalledProcessError as e:
            logger.error(f"Conversion failed: {e}")
            logger.error(e.stderr)
            return False

    def test_apptainer_image(
        self,
        sif_path: str,
        test_cmd: str = "python3 --version"
    ) -> bool:
        """
        Test an Apptainer image by running a command.

        Args:
            sif_path: Path to .sif file
            test_cmd: Command to test

        Returns:
            True if test successful
        """
        try:
            result = subprocess.run(
                [self.apptainer_cmd, "exec", sif_path] + test_cmd.split(),
                capture_output=True,
                text=True,
                stdin=subprocess.DEVNULL,
                check=True
            )
            logger.info(f"Test successful: {result.stdout.strip()}")
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"Test failed: {e}")
            logger.error(e.stderr)
            return False

    def get_image_info(self, sif_path: str) -> dict:
        """
        Get information about an Apptainer image.

        Args:
            sif_path: Path to .sif file

        Returns:
            Dictionary with image metadata
        """
        try:
            result = subprocess.run(
                [self.apptainer_cmd, "inspect", sif_path],
                capture_output=True,
                text=True,
                stdin=subprocess.DEVNULL,
                check=True
            )

            # Parse inspect output
            info = {
                "path": sif_path,
                "size": Path(sif_path).stat().st_size if Path(sif_path).exists() else 0,
                "inspect_output": result.stdout
            }

            return info

        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to get image info: {e}")
            return {"error": str(e)}

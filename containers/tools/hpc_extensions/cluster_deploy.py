"""
Cluster deployment utilities for container images.

Handles deployment of Apptainer images to HPC clusters via SSH/rsync.
"""

import os
import subprocess
from pathlib import Path
from typing import List, Optional
import logging
import yaml

logger = logging.getLogger(__name__)


class ClusterDeployer:
    """Deploy container images to HPC clusters."""

    def __init__(self, cluster_config_path: Optional[str] = None):
        """
        Initialize cluster deployer.

        Args:
            cluster_config_path: Path to cluster configuration YAML
        """
        self.cluster_config = None
        if cluster_config_path:
            self.load_cluster_config(cluster_config_path)

    def load_cluster_config(self, config_path: str):
        """Load cluster configuration from YAML file."""
        with open(config_path, 'r') as f:
            self.cluster_config = yaml.safe_load(f)
        logger.info(f"Loaded cluster config from {config_path}")

    def deploy_image(
        self,
        sif_path: str,
        target_path: str,
        controller_ip: str,
        ssh_user: str = "root",
        ssh_key: Optional[str] = None,
        sync_to_nodes: bool = False
    ) -> bool:
        """
        Deploy Apptainer image to cluster controller.

        Args:
            sif_path: Local path to .sif file
            target_path: Remote path on controller
            controller_ip: Controller node IP address
            ssh_user: SSH username
            ssh_key: Path to SSH private key
            sync_to_nodes: Whether to sync to compute nodes

        Returns:
            True if deployment successful
        """
        if not Path(sif_path).exists():
            logger.error(f"Local image not found: {sif_path}")
            return False

        # Build rsync command
        rsync_cmd = ["rsync", "-avz", "--progress"]

        if ssh_key:
            rsync_cmd.extend(["-e", f"ssh -i {ssh_key}"])

        rsync_cmd.extend([
            sif_path,
            f"{ssh_user}@{controller_ip}:{target_path}"
        ])

        logger.info(f"Deploying {sif_path} to {controller_ip}:{target_path}")

        try:
            result = subprocess.run(
                rsync_cmd,
                capture_output=True,
                text=True,
                stdin=subprocess.DEVNULL,
                check=True
            )
            logger.info("Deployment successful")
            logger.debug(result.stdout)

            if sync_to_nodes:
                return self._sync_to_compute_nodes(
                    target_path, controller_ip, ssh_user, ssh_key
                )

            return True

        except subprocess.CalledProcessError as e:
            logger.error(f"Deployment failed: {e}")
            logger.error(e.stderr)
            return False

    def _sync_to_compute_nodes(
        self,
        image_path: str,
        controller_ip: str,
        ssh_user: str,
        ssh_key: Optional[str]
    ) -> bool:
        """Sync image from controller to all compute nodes."""
        logger.info("Syncing image to compute nodes...")

        # Build SSH command to execute on controller
        ssh_cmd = ["ssh"]

        if ssh_key:
            ssh_cmd.extend(["-i", ssh_key])

        ssh_cmd.extend([
            f"{ssh_user}@{controller_ip}",
            f"pdcp -w ^/etc/slurm/nodes.txt {image_path} {image_path}"
        ])

        try:
            result = subprocess.run(
                ssh_cmd,
                capture_output=True,
                text=True,
                stdin=subprocess.DEVNULL,
                check=True
            )
            logger.info("Sync to compute nodes successful")
            return True
        except subprocess.CalledProcessError as e:
            logger.warning(f"Sync to compute nodes failed: {e}")
            logger.warning("You may need to manually sync or use Ansible")
            return False

    def verify_deployment(
        self,
        image_path: str,
        controller_ip: str,
        ssh_user: str = "root",
        ssh_key: Optional[str] = None,
        verify_nodes: bool = False
    ) -> bool:
        """
        Verify image deployment on cluster.

        Args:
            image_path: Remote path to verify
            controller_ip: Controller IP
            ssh_user: SSH username
            ssh_key: SSH private key path
            verify_nodes: Whether to verify on compute nodes too

        Returns:
            True if verification successful
        """
        # Build SSH command
        ssh_cmd = ["ssh"]

        if ssh_key:
            ssh_cmd.extend(["-i", ssh_key])

        ssh_cmd.extend([
            f"{ssh_user}@{controller_ip}",
            f"ls -lh {image_path}"
        ])

        try:
            result = subprocess.run(
                ssh_cmd,
                capture_output=True,
                text=True,
                stdin=subprocess.DEVNULL,
                check=True
            )
            logger.info(f"Image verified on controller: {result.stdout.strip()}")

            if verify_nodes:
                return self._verify_on_compute_nodes(
                    image_path, controller_ip, ssh_user, ssh_key
                )

            return True

        except subprocess.CalledProcessError as e:
            logger.error(f"Verification failed: {e}")
            return False

    def _verify_on_compute_nodes(
        self,
        image_path: str,
        controller_ip: str,
        ssh_user: str,
        ssh_key: Optional[str]
    ) -> bool:
        """Verify image exists on all compute nodes."""
        ssh_cmd = ["ssh"]

        if ssh_key:
            ssh_cmd.extend(["-i", ssh_key])

        ssh_cmd.extend([
            f"{ssh_user}@{controller_ip}",
            f"pdsh -w ^/etc/slurm/nodes.txt ls -lh {image_path}"
        ])

        try:
            result = subprocess.run(
                ssh_cmd,
                capture_output=True,
                text=True,
                stdin=subprocess.DEVNULL,
                check=True
            )
            logger.info("Image verified on all compute nodes")
            logger.debug(result.stdout)
            return True
        except subprocess.CalledProcessError as e:
            logger.warning(f"Verification on compute nodes failed: {e}")
            return False

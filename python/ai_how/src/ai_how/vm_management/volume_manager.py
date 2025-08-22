"""Volume management using libvirt storage pools and volumes."""

import json
import logging
from pathlib import Path
from typing import Any

import libvirt

from ai_how.utils.logging import (
    log_function_entry,
    log_function_exit,
    log_operation_start,
    log_operation_success,
    run_subprocess_with_logging,
)
from ai_how.vm_management.libvirt_client import LibvirtClient

logger = logging.getLogger(__name__)


class VolumeManagerError(Exception):
    """Raised when volume management operations fail."""

    pass


class VolumeManager:
    """Manages libvirt storage pools and volumes for HPC clusters."""

    def __init__(self, libvirt_client: LibvirtClient):
        """Initialize volume manager.

        Args:
            libvirt_client: LibvirtClient instance for connections
        """
        log_function_entry(logger, "__init__")

        self.client = libvirt_client
        logger.debug("VolumeManager initialized with libvirt client")

        log_function_exit(logger, "__init__")

    def create_cluster_pool(self, cluster_name: str, pool_path: Path, base_image_path: Path) -> str:
        """Create a storage pool for the cluster with base image.

        Args:
            cluster_name: Name of the cluster
            pool_path: Base path for the storage pool
            base_image_path: Path to the base image file

        Returns:
            Storage pool name

        Raises:
            VolumeManagerError: If pool creation fails
        """
        log_function_entry(
            logger,
            "create_cluster_pool",
            cluster_name=cluster_name,
            pool_path=pool_path,
            base_image_path=base_image_path,
        )

        try:
            pool_name = f"{cluster_name}-pool"
            cluster_pool_path = pool_path / cluster_name

            log_operation_start(
                logger,
                "cluster storage pool creation",
                pool_name=pool_name,
                pool_path=cluster_pool_path,
            )

            # Check if pool already exists
            if self._pool_exists(pool_name):
                logger.debug(f"Storage pool {pool_name} already exists")
                log_function_exit(logger, "create_cluster_pool", result=pool_name)
                return pool_name

            # Generate pool XML (libvirt will create the directory)
            pool_xml = self._generate_pool_xml(pool_name, cluster_pool_path)
            logger.debug(f"Generated XML for pool {pool_name}")

            # Create storage pool using libvirt APIs
            try:
                with self.client.get_connection() as conn:
                    logger.debug("Defining storage pool")
                    pool = conn.storagePoolDefineXML(pool_xml, 0)

                    logger.debug(
                        "Building storage pool (creates directory with proper permissions)"
                    )
                    pool.build(0)

                    logger.debug("Starting storage pool")
                    pool.create(0)

                    logger.debug("Setting pool to autostart")
                    pool.setAutostart(1)

                    pool_uuid = pool.UUIDString()
                    logger.debug(f"Storage pool created with UUID: {pool_uuid}")

            except libvirt.libvirtError as e:
                logger.error(f"Failed to create storage pool {pool_name}: {e}")
                raise VolumeManagerError(f"Failed to create storage pool {pool_name}: {e}") from e

            # Create base image volume in pool using libvirt
            base_volume_name = f"{cluster_name}-base.qcow2"

            # Check if base volume already exists in pool
            if not self._volume_exists_in_pool(pool_name, base_volume_name):
                logger.debug(f"Creating base image volume from: {base_image_path}")
                self._create_base_volume_from_image(pool_name, base_volume_name, base_image_path)
            else:
                logger.debug(f"Base image volume already exists in pool: {base_volume_name}")

            log_operation_success(
                logger,
                "cluster storage pool creation",
                pool_name=pool_name,
                pool_path=cluster_pool_path,
            )

            log_function_exit(logger, "create_cluster_pool", result=pool_name)
            return pool_name

        except Exception as e:
            logger.error(f"Failed to create cluster pool for {cluster_name}: {e}")
            if isinstance(e, VolumeManagerError):
                raise
            else:
                raise VolumeManagerError(f"Unexpected error creating cluster pool: {e}") from e

    def destroy_cluster_pool(self, cluster_name: str, force: bool = False) -> bool:
        """Destroy cluster storage pool and all volumes.

        Args:
            cluster_name: Name of the cluster
            force: Whether to force destruction even if volumes exist

        Returns:
            True if pool destroyed successfully

        Raises:
            VolumeManagerError: If pool destruction fails
        """
        log_function_entry(logger, "destroy_cluster_pool", cluster_name=cluster_name, force=force)

        try:
            pool_name = f"{cluster_name}-pool"

            if not self._pool_exists(pool_name):
                logger.debug(f"Storage pool {pool_name} does not exist")
                log_function_exit(logger, "destroy_cluster_pool", result=True)
                return True

            log_operation_start(logger, "cluster storage pool destruction", pool_name=pool_name)

            with self.client.get_connection() as conn:
                pool = conn.storagePoolLookupByName(pool_name)

                # List and destroy all volumes if force is True
                if force:
                    try:
                        volume_names = pool.listVolumes()
                        logger.debug(f"Found {len(volume_names)} volumes to destroy")

                        for vol_name in volume_names:
                            try:
                                volume = pool.storageVolLookupByName(vol_name)
                                volume.delete(0)
                                logger.debug(f"Destroyed volume: {vol_name}")
                            except libvirt.libvirtError as e:
                                logger.warning(f"Failed to destroy volume {vol_name}: {e}")
                    except libvirt.libvirtError as e:
                        logger.warning(f"Could not list volumes in pool {pool_name}: {e}")

                # Destroy the pool
                logger.debug("Destroying storage pool")
                if pool.isActive():
                    pool.destroy()

                pool.undefine()
                logger.debug(f"Storage pool {pool_name} undefined")

            log_operation_success(logger, "cluster storage pool destruction", pool_name=pool_name)
            log_function_exit(logger, "destroy_cluster_pool", result=True)
            return True

        except libvirt.libvirtError as e:
            logger.error(f"Failed to destroy cluster pool {cluster_name}: {e}")
            raise VolumeManagerError(f"Failed to destroy cluster pool {cluster_name}: {e}") from e
        except Exception as e:
            logger.error(f"Unexpected error destroying cluster pool {cluster_name}: {e}")
            raise VolumeManagerError(
                f"Unexpected error destroying cluster pool {cluster_name}: {e}"
            ) from e

    def create_vm_volume(
        self, cluster_name: str, vm_name: str, size_gb: int, vm_type: str = "compute"
    ) -> str:
        """Create a COW volume for a VM in the cluster pool.

        Args:
            cluster_name: Name of the cluster
            vm_name: Name of the VM
            size_gb: Size of the volume in GB
            vm_type: Type of VM (controller, compute, etc.)

        Returns:
            Path to the created volume

        Raises:
            VolumeManagerError: If volume creation fails
        """
        log_function_entry(
            logger,
            "create_vm_volume",
            cluster_name=cluster_name,
            vm_name=vm_name,
            size_gb=size_gb,
            vm_type=vm_type,
        )

        try:
            pool_name = f"{cluster_name}-pool"
            volume_name = f"{vm_name}.qcow2"
            base_volume_name = f"{cluster_name}-base.qcow2"

            log_operation_start(
                logger,
                "VM volume creation",
                pool_name=pool_name,
                volume_name=volume_name,
                size_gb=size_gb,
            )

            # Check if pool exists
            if not self._pool_exists(pool_name):
                raise VolumeManagerError(f"Storage pool {pool_name} does not exist")

            with self.client.get_connection() as conn:
                pool = conn.storagePoolLookupByName(pool_name)
                pool_path = self._get_pool_path(pool)
                base_volume_path = pool_path / base_volume_name

                logger.debug(f"Pool path: {pool_path}")
                logger.debug(f"Base volume path: {base_volume_path}")

                # Check if volume already exists
                try:
                    existing_volume = pool.storageVolLookupByName(volume_name)
                    volume_path = existing_volume.path()
                    logger.debug(f"Volume {volume_name} already exists at {volume_path}")
                    log_function_exit(logger, "create_vm_volume", result=volume_path)
                    return volume_path
                except libvirt.libvirtError:
                    # Volume doesn't exist, continue with creation
                    pass

                # Generate volume XML for copy-on-write
                volume_xml = self._generate_volume_xml(volume_name, size_gb, base_volume_path)
                logger.debug(f"Generated XML for volume {volume_name}")

                # Create volume
                try:
                    volume = pool.createXML(volume_xml, 0)
                    volume_path = volume.path()

                    logger.debug(f"Volume created: {volume_name}")
                    logger.debug(f"Volume path: {volume_path}")

                except libvirt.libvirtError as e:
                    logger.error(f"Failed to create volume {volume_name}: {e}")
                    raise VolumeManagerError(f"Failed to create volume {volume_name}: {e}") from e

            log_operation_success(
                logger, "VM volume creation", volume_name=volume_name, volume_path=volume_path
            )

            log_function_exit(logger, "create_vm_volume", result=volume_path)
            return volume_path

        except Exception as e:
            logger.error(f"Failed to create VM volume for {vm_name}: {e}")
            if isinstance(e, VolumeManagerError):
                raise
            else:
                raise VolumeManagerError(f"Unexpected error creating VM volume: {e}") from e

    def destroy_vm_volume(self, cluster_name: str, vm_name: str) -> bool:
        """Destroy VM volume from cluster pool.

        Args:
            cluster_name: Name of the cluster
            vm_name: Name of the VM

        Returns:
            True if volume destroyed successfully

        Raises:
            VolumeManagerError: If volume destruction fails
        """
        log_function_entry(logger, "destroy_vm_volume", cluster_name=cluster_name, vm_name=vm_name)

        try:
            pool_name = f"{cluster_name}-pool"
            volume_name = f"{vm_name}.qcow2"

            if not self._pool_exists(pool_name):
                logger.debug(f"Storage pool {pool_name} does not exist")
                log_function_exit(logger, "destroy_vm_volume", result=True)
                return True

            log_operation_start(logger, "VM volume destruction", volume_name=volume_name)

            with self.client.get_connection() as conn:
                pool = conn.storagePoolLookupByName(pool_name)

                try:
                    volume = pool.storageVolLookupByName(volume_name)
                    volume_path = volume.path()

                    volume.delete(0)
                    logger.debug(f"Destroyed volume: {volume_name} at {volume_path}")

                except libvirt.libvirtError as e:
                    # Use helper to check for 'not found' error
                    if self._is_libvirt_not_found_error(
                        e,
                        libvirt.VIR_ERR_NO_STORAGE_VOL,  # type: ignore[attr-defined]
                        ["not found"],
                    ):
                        logger.debug(f"Volume {volume_name} does not exist")
                        log_function_exit(logger, "destroy_vm_volume", result=True)
                        return True
                    else:
                        raise

            log_operation_success(logger, "VM volume destruction", volume_name=volume_name)
            log_function_exit(logger, "destroy_vm_volume", result=True)
            return True

        except libvirt.libvirtError as e:
            logger.error(f"Failed to destroy VM volume {vm_name}: {e}")
            raise VolumeManagerError(f"Failed to destroy VM volume {vm_name}: {e}") from e
        except Exception as e:
            logger.error(f"Unexpected error destroying VM volume {vm_name}: {e}")
            raise VolumeManagerError(f"Unexpected error destroying VM volume {vm_name}: {e}") from e

    def resize_vm_volume(self, cluster_name: str, vm_name: str, new_size_gb: int) -> bool:
        """Resize VM volume.

        Args:
            cluster_name: Name of the cluster
            vm_name: Name of the VM
            new_size_gb: New size in GB

        Returns:
            True if volume resized successfully

        Raises:
            VolumeManagerError: If volume resize fails
        """
        log_function_entry(
            logger,
            "resize_vm_volume",
            cluster_name=cluster_name,
            vm_name=vm_name,
            new_size_gb=new_size_gb,
        )

        try:
            pool_name = f"{cluster_name}-pool"
            volume_name = f"{vm_name}.qcow2"

            if not self._pool_exists(pool_name):
                raise VolumeManagerError(f"Storage pool {pool_name} does not exist")

            log_operation_start(
                logger, "VM volume resize", volume_name=volume_name, new_size_gb=new_size_gb
            )

            with self.client.get_connection() as conn:
                pool = conn.storagePoolLookupByName(pool_name)
                volume = pool.storageVolLookupByName(volume_name)
                volume_path = volume.path()

                cmd = ["qemu-img", "resize", volume_path, f"{new_size_gb}G"]

                result = run_subprocess_with_logging(
                    cmd,
                    logger,
                    check=True,
                    operation_description=f"Resizing volume to {new_size_gb}GB",
                )

                if result.success:
                    logger.debug(f"Volume {volume_name} resized to {new_size_gb}GB")

            log_operation_success(
                logger, "VM volume resize", volume_name=volume_name, new_size_gb=new_size_gb
            )

            log_function_exit(logger, "resize_vm_volume", result=True)
            return True

        except Exception as e:
            logger.error(f"Failed to resize VM volume {vm_name}: {e}")
            if isinstance(e, VolumeManagerError):
                raise
            else:
                raise VolumeManagerError(f"Unexpected error resizing VM volume: {e}") from e

    def get_volume_info(self, cluster_name: str, vm_name: str) -> dict[str, Any]:
        """Get volume information and statistics.

        Args:
            cluster_name: Name of the cluster
            vm_name: Name of the VM

        Returns:
            Dictionary with volume information

        Raises:
            VolumeManagerError: If operation fails
        """
        log_function_entry(logger, "get_volume_info", cluster_name=cluster_name, vm_name=vm_name)

        try:
            pool_name = f"{cluster_name}-pool"
            volume_name = f"{vm_name}.qcow2"

            if not self._pool_exists(pool_name):
                raise VolumeManagerError(f"Storage pool {pool_name} does not exist")

            with self.client.get_connection() as conn:
                pool = conn.storagePoolLookupByName(pool_name)
                volume = pool.storageVolLookupByName(volume_name)

                volume_info = volume.info()
                volume_path = volume.path()

                info = {
                    "name": volume_name,
                    "path": volume_path,
                    "type": volume_info[0],
                    "capacity": volume_info[1],
                    "allocation": volume_info[2],
                    "capacity_gb": volume_info[1] / (1024**3),
                    "allocation_gb": volume_info[2] / (1024**3),
                }

                # Get additional info using qemu-img
                try:
                    cmd = ["qemu-img", "info", "--output=json", volume_path]
                    result = run_subprocess_with_logging(
                        cmd,
                        logger,
                        check=True,
                        operation_description="Getting volume information",
                    )

                    qemu_info = json.loads(result.stdout)
                    info.update(
                        {
                            "format": qemu_info.get("format", "unknown"),
                            "virtual_size": qemu_info.get("virtual-size", 0),
                            "actual_size": qemu_info.get("actual-size", 0),
                            "backing_file": qemu_info.get("backing-filename"),
                        }
                    )
                except Exception as e:
                    logger.warning(f"Could not get detailed volume info: {e}")

                log_function_exit(logger, "get_volume_info", result=f"{len(info)} fields")
                return info

        except libvirt.libvirtError as e:
            logger.error(f"Failed to get volume info for {vm_name}: {e}")
            raise VolumeManagerError(f"Failed to get volume info for {vm_name}: {e}") from e
        except Exception as e:
            logger.error(f"Unexpected error getting volume info for {vm_name}: {e}")
            raise VolumeManagerError(f"Unexpected error getting volume info: {e}") from e

    def list_cluster_volumes(self, cluster_name: str) -> list[dict[str, Any]]:
        """List all volumes in cluster pool.

        Args:
            cluster_name: Name of the cluster

        Returns:
            List of volume information dictionaries

        Raises:
            VolumeManagerError: If operation fails
        """
        log_function_entry(logger, "list_cluster_volumes", cluster_name=cluster_name)

        try:
            pool_name = f"{cluster_name}-pool"

            if not self._pool_exists(pool_name):
                logger.debug(f"Storage pool {pool_name} does not exist")
                log_function_exit(logger, "list_cluster_volumes", result="empty list")
                return []

            volumes = []

            with self.client.get_connection() as conn:
                pool = conn.storagePoolLookupByName(pool_name)
                volume_names = pool.listVolumes()

                logger.debug(f"Found {len(volume_names)} volumes in pool {pool_name}")

                for vol_name in volume_names:
                    try:
                        volume = pool.storageVolLookupByName(vol_name)
                        volume_info = volume.info()

                        info = {
                            "name": vol_name,
                            "path": volume.path(),
                            "capacity_gb": volume_info[1] / (1024**3),
                            "allocation_gb": volume_info[2] / (1024**3),
                        }
                        volumes.append(info)

                    except libvirt.libvirtError as e:
                        logger.warning(f"Could not get info for volume {vol_name}: {e}")

            log_function_exit(logger, "list_cluster_volumes", result=f"{len(volumes)} volumes")
            return volumes

        except libvirt.libvirtError as e:
            logger.error(f"Failed to list cluster volumes for {cluster_name}: {e}")
            raise VolumeManagerError(f"Failed to list cluster volumes: {e}") from e
        except Exception as e:
            logger.error(f"Unexpected error listing cluster volumes for {cluster_name}: {e}")
            raise VolumeManagerError(f"Unexpected error listing cluster volumes: {e}") from e

    def get_pool_info(self, cluster_name: str) -> dict[str, Any]:
        """Get storage pool information and statistics.

        Args:
            cluster_name: Name of the cluster

        Returns:
            Dictionary with pool information

        Raises:
            VolumeManagerError: If operation fails
        """
        log_function_entry(logger, "get_pool_info", cluster_name=cluster_name)

        try:
            pool_name = f"{cluster_name}-pool"

            if not self._pool_exists(pool_name):
                raise VolumeManagerError(f"Storage pool {pool_name} does not exist")

            with self.client.get_connection() as conn:
                pool = conn.storagePoolLookupByName(pool_name)

                pool_info = pool.info()
                pool_xml = pool.XMLDesc(0)

                # Extract pool path from XML
                import xml.etree.ElementTree as ET

                root = ET.fromstring(pool_xml)
                path_elem = root.find(".//target/path")
                pool_path = path_elem.text if path_elem is not None else "unknown"

                info = {
                    "name": pool_name,
                    "path": pool_path,
                    "state": pool_info[0],
                    "capacity": pool_info[1],
                    "allocation": pool_info[2],
                    "available": pool_info[3],
                    "capacity_gb": pool_info[1] / (1024**3),
                    "allocation_gb": pool_info[2] / (1024**3),
                    "available_gb": pool_info[3] / (1024**3),
                    "uuid": pool.UUIDString(),
                }

                # Get volume count
                try:
                    volume_names = pool.listVolumes()
                    info["volume_count"] = len(volume_names)
                except libvirt.libvirtError:
                    info["volume_count"] = 0

                log_function_exit(
                    logger, "get_pool_info", result=f"pool with {info['volume_count']} volumes"
                )
                return info

        except libvirt.libvirtError as e:
            logger.error(f"Failed to get pool info for {cluster_name}: {e}")
            raise VolumeManagerError(f"Failed to get pool info: {e}") from e
        except Exception as e:
            logger.error(f"Unexpected error getting pool info for {cluster_name}: {e}")
            raise VolumeManagerError(f"Unexpected error getting pool info: {e}") from e

    def validate_pool_space(self, cluster_name: str, required_space_gb: int) -> bool:
        """Validate available space in pool.

        Args:
            cluster_name: Name of the cluster
            required_space_gb: Required space in GB

        Returns:
            True if enough space is available

        Raises:
            VolumeManagerError: If operation fails
        """
        try:
            pool_info = self.get_pool_info(cluster_name)
            available_gb = pool_info["available_gb"]

            logger.debug(
                f"Pool space check: available={available_gb:.2f}GB, required={required_space_gb}GB"
            )

            return available_gb >= required_space_gb

        except Exception as e:
            logger.warning(f"Could not validate pool space: {e}")
            return False

    def _pool_exists(self, pool_name: str) -> bool:
        """Check if storage pool exists.

        Args:
            pool_name: Name of the storage pool

        Returns:
            True if pool exists, False otherwise
        """
        try:
            with self.client.get_connection() as conn:
                conn.storagePoolLookupByName(pool_name)
                return True
        except libvirt.libvirtError:
            return False

    def _generate_pool_xml(self, pool_name: str, pool_path: Path) -> str:
        """Generate storage pool XML configuration.

        Args:
            pool_name: Name of the storage pool
            pool_path: Path to the storage pool directory

        Returns:
            XML configuration string
        """
        xml = f"""
<pool type="dir">
  <name>{pool_name}</name>
  <target>
    <path>{pool_path}</path>
  </target>
</pool>
        """.strip()

        return xml

    def _generate_volume_xml(self, volume_name: str, size_gb: int, base_volume_path: Path) -> str:
        """Generate volume XML configuration for copy-on-write.

        Args:
            volume_name: Name of the volume
            size_gb: Size of the volume in GB
            base_volume_path: Path to the base image

        Returns:
            XML configuration string
        """
        size_bytes = size_gb * 1024 * 1024 * 1024

        xml = f"""
<volume type="file">
  <name>{volume_name}</name>
  <capacity unit="bytes">{size_bytes}</capacity>
  <target>
    <format type="qcow2"/>
  </target>
  <backingStore>
    <path>{base_volume_path}</path>
    <format type="qcow2"/>
  </backingStore>
</volume>
        """.strip()

        return xml

    def _get_pool_path(self, pool) -> Path:
        """Get pool path from libvirt pool object.

        Args:
            pool: libvirt storage pool object

        Returns:
            Path to the pool directory
        """
        pool_xml = pool.XMLDesc(0)
        import xml.etree.ElementTree as ET

        root = ET.fromstring(pool_xml)
        path_elem = root.find(".//target/path")
        if path_elem is not None and path_elem.text:
            return Path(path_elem.text)
        else:
            raise VolumeManagerError("Could not determine pool path from XML")

    def _volume_exists_in_pool(self, pool_name: str, volume_name: str) -> bool:
        """Check if volume exists in storage pool.

        Args:
            pool_name: Name of the storage pool
            volume_name: Name of the volume

        Returns:
            True if volume exists, False otherwise
        """
        try:
            with self.client.get_connection() as conn:
                pool = conn.storagePoolLookupByName(pool_name)
                pool.storageVolLookupByName(volume_name)
                return True
        except libvirt.libvirtError:
            return False

    def _create_base_volume_from_image(
        self, pool_name: str, volume_name: str, source_image_path: Path
    ) -> None:
        """Create base volume in pool from existing image file using libvirt.

        Args:
            pool_name: Name of the storage pool
            volume_name: Name for the new volume
            source_image_path: Path to the source image file
        """
        logger.debug(f"Creating base volume from image: {source_image_path} -> {volume_name}")

        try:
            with self.client.get_connection() as conn:
                pool = conn.storagePoolLookupByName(pool_name)

                # Get source image information
                cmd = ["qemu-img", "info", "--output=json", str(source_image_path)]
                result = run_subprocess_with_logging(
                    cmd,
                    logger,
                    check=True,
                    operation_description="Getting source image information",
                )

                if not result.success:
                    raise VolumeManagerError(
                        f"Failed to get source image info: {source_image_path}"
                    )

                import json

                image_info = json.loads(result.stdout)
                virtual_size = image_info.get("virtual-size", 0)
                format_type = image_info.get("format", "qcow2")

                # Generate volume XML for the base image
                volume_xml = f"""
<volume type="file">
  <name>{volume_name}</name>
  <capacity unit="bytes">{virtual_size}</capacity>
  <target>
    <format type="{format_type}"/>
  </target>
</volume>
                """.strip()

                logger.debug(f"Creating volume with XML for {volume_name}")
                volume = pool.createXML(volume_xml, 0)
                volume_path = volume.path()

                logger.debug(f"Volume created at: {volume_path}")

                # Upload the image data to the volume using libvirt streams
                self._upload_volume_data(volume, source_image_path)

                logger.debug(f"Base volume created successfully: {volume_name}")

        except Exception as e:
            logger.error(f"Failed to create base volume from image: {e}")
            raise VolumeManagerError(f"Failed to create base volume from image: {e}") from e

    def _upload_volume_data(self, volume: Any, source_path: Path) -> None:
        """Upload data to volume using libvirt stream API.

        Args:
            volume: libvirt volume object
            source_path: Path to source data file
        """
        logger.debug(f"Uploading data to volume from: {source_path}")

        try:
            # Get connection from volume
            conn = volume.connect()

            # Create stream for upload
            stream = conn.newStream(0)

            # Get volume info
            volume_info = volume.info()
            capacity = volume_info[1]  # Volume capacity in bytes

            # Start upload
            volume.upload(stream, 0, capacity, 0)

            # Upload file data in chunks
            chunk_size = 1024 * 1024  # 1MB chunks
            total_sent = 0

            with open(source_path, "rb") as f:
                while True:
                    data = f.read(chunk_size)
                    if not data:
                        break

                    bytes_sent = stream.send(data)
                    if bytes_sent < 0:
                        raise VolumeManagerError("Stream send failed")

                    total_sent += bytes_sent
                    if total_sent % (chunk_size * 10) == 0:  # Log every 10MB
                        logger.debug(f"Uploaded {total_sent // (1024 * 1024)}MB...")

            # Finish the stream
            stream.finish()
            logger.debug(f"Successfully uploaded {total_sent} bytes to volume")

        except Exception as e:
            logger.error(f"Failed to upload volume data: {e}")
            # Try to cleanup the stream
            try:
                if "stream" in locals():
                    stream.abort()
            except Exception as cleanup_e:
                logger.error(f"Failed to abort stream: {cleanup_e}")
            raise VolumeManagerError(f"Failed to upload volume data: {e}") from e

    def _is_libvirt_not_found_error(
        self, error: libvirt.libvirtError, expected_error_code: int, fallback_patterns: list[str]
    ) -> bool:
        """Check if a libvirt error represents a "not found" condition.

        Args:
            error: The libvirt error to check
            expected_error_code: The expected libvirt error code for "not found"
            fallback_patterns: List of string patterns to check if error code doesn't match

        Returns:
            True if the error represents a "not found" condition, False otherwise
        """
        try:
            # First try to check the error code
            if hasattr(error, "get_error_code"):
                error_code = error.get_error_code()
                if error_code == expected_error_code:
                    return True
        except (AttributeError, TypeError):
            pass

        # Fallback to string checking for backward compatibility
        error_str = str(error).lower()
        return any(pattern.lower() in error_str for pattern in fallback_patterns)

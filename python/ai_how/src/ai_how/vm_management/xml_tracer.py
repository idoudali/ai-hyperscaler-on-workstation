"""XML tracing system for libvirt operations with versioned folder storage."""

import datetime
import json
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


class XMLTracer:
    """Traces and logs all XML definitions passed to libvirt APIs in versioned folders."""

    def __init__(self, cluster_name: str, operation: str = "unknown"):
        """Initialize XML tracer for a specific cluster operation.

        Args:
            cluster_name: Name of the cluster being operated on
            operation: Type of operation (start, stop, destroy, etc.)
        """
        self.cluster_name = cluster_name
        self.operation = operation
        self.start_time = datetime.datetime.now()
        self.xml_records: list[dict] = []
        self.operation_counter = 0
        self.trace_folder = self._generate_trace_folder()
        self.metadata_file = self.trace_folder / "trace_metadata.json"

        # Create trace folder
        try:
            self.trace_folder.mkdir(parents=True, exist_ok=True)
            logger.debug(f"Created XML trace folder: {self.trace_folder}")
        except OSError as e:
            logger.error(f"Failed to create trace folder {self.trace_folder}: {e}")
            raise

    def _generate_trace_folder(self) -> Path:
        """Generate unique versioned trace folder per run."""
        timestamp = self.start_time.strftime("%Y%m%d_%H%M%S_%f")[:-3]  # Include milliseconds
        folder_name = f"run_{self.cluster_name}_{self.operation}_{timestamp}"
        return Path("traces") / folder_name

    def log_xml(
        self,
        xml_type: str,
        xml_content: str,
        operation: str,
        target_name: str = "",
        success: bool = True,
        error: str = "",
    ):
        """Log XML content to individual files in versioned trace folder.

        Args:
            xml_type: Type of XML (domain, network, pool, volume)
            xml_content: The XML content to log
            operation: Operation type (create, define, destroy, etc.)
            target_name: Name of the target object (optional)
            success: Whether the operation was successful
            error: Error message if operation failed (optional)
        """
        self.operation_counter += 1
        timestamp = datetime.datetime.now()

        # Generate filename for this XML operation
        target_suffix = f"_{target_name}" if target_name else ""
        status_suffix = "_SUCCESS" if success else "_FAILED"
        xml_filename = (
            f"{self.operation_counter:03d}_{xml_type}_{operation}{target_suffix}{status_suffix}.xml"
        )
        xml_file_path = self.trace_folder / xml_filename

        try:
            # Save XML content to file
            with open(xml_file_path, "w") as f:
                f.write(xml_content)

            logger.debug(f"Saved XML trace: {xml_filename}")

        except OSError as e:
            logger.error(f"Failed to write XML trace file {xml_filename}: {e}")
            # Continue execution even if trace writing fails

        # Create metadata record
        record = {
            "sequence": self.operation_counter,
            "timestamp": timestamp.isoformat(),
            "xml_type": xml_type,
            "operation": operation,
            "target_name": target_name,
            "success": success,
            "error": error,
            "xml_file": xml_filename,
            "xml_length": len(xml_content),
        }
        self.xml_records.append(record)

    def save_trace(self):
        """Save metadata summary to trace folder.

        Returns:
            Path to the trace folder
        """
        try:
            trace_metadata = {
                "cluster_name": self.cluster_name,
                "operation": self.operation,
                "start_time": self.start_time.isoformat(),
                "end_time": datetime.datetime.now().isoformat(),
                "total_xml_operations": len(self.xml_records),
                "trace_folder": str(self.trace_folder),
                "xml_operations": self.xml_records,
                "file_listing": self._get_trace_file_listing(),
            }

            with open(self.metadata_file, "w") as f:
                json.dump(trace_metadata, f, indent=2)

            logger.info(f"Saved XML trace metadata: {self.metadata_file}")

        except OSError as e:
            logger.error(f"Failed to write trace metadata: {e}")

        return self.trace_folder

    def _get_trace_file_listing(self) -> list[str]:
        """Get list of all XML files in trace folder."""
        xml_files = []
        try:
            for file_path in sorted(self.trace_folder.glob("*.xml")):
                xml_files.append(file_path.name)
        except OSError as e:
            logger.error(f"Failed to list XML files in trace folder: {e}")

        return xml_files

    def get_summary(self) -> dict:
        """Get summary of XML operations and trace folder location."""
        operations: dict[str, int] = {}
        xml_types: dict[str, int] = {}
        success_count = 0

        for record in self.xml_records:
            op = record["operation"]
            xml_type = record["xml_type"]

            operations[op] = operations.get(op, 0) + 1
            xml_types[xml_type] = xml_types.get(xml_type, 0) + 1

            if record["success"]:
                success_count += 1

        return {
            "total_operations": len(self.xml_records),
            "successful_operations": success_count,
            "failed_operations": len(self.xml_records) - success_count,
            "operations_by_type": operations,
            "xml_types": xml_types,
            "trace_folder": str(self.trace_folder),
            "metadata_file": str(self.metadata_file),
        }

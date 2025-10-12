#!/usr/bin/env python3
"""
SLURM Training Failure Diagnosis Tool
Task 025: Failure Detection Scripts

Analyzes job failures and provides detailed diagnostic information
for distributed training failures in SLURM environments.

Usage:
    diagnose_training_failure.py --job-id <id> --exit-code <code> --output <file>
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any


class TrainingFailureDiagnostic:
    """Diagnose distributed training failures in SLURM"""

    def __init__(self, job_id: str, exit_code: int):
        self.job_id = job_id
        self.exit_code = exit_code
        self.timestamp = datetime.now().isoformat()
        self.diagnostics: Dict[str, Any] = {
            "job_id": job_id,
            "exit_code": exit_code,
            "timestamp": self.timestamp,
            "failure_category": "unknown",
            "symptoms": [],
            "likely_causes": [],
            "recommended_actions": [],
            "system_state": {},
        }

    def run_command(self, cmd: List[str]) -> Optional[str]:
        """Run a command and return its output"""
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
            return result.stdout if result.returncode == 0 else None
        except (subprocess.TimeoutExpired, FileNotFoundError, Exception):
            return None

    def check_oom_killer(self) -> bool:
        """Check if OOM killer was triggered"""
        output = self.run_command(["dmesg", "-T"])
        if output and ("out of memory" in output.lower() or "oom" in output.lower()):
            self.diagnostics["symptoms"].append("OOM (Out of Memory) killer triggered")
            self.diagnostics["likely_causes"].append("Insufficient memory for training batch size or model")
            self.diagnostics["recommended_actions"].extend([
                "Reduce batch size or model size",
                "Increase node memory allocation",
                "Enable gradient checkpointing to reduce memory usage",
                "Use mixed precision training (FP16/BF16)",
            ])
            return True
        return False

    def check_gpu_errors(self) -> bool:
        """Check for GPU-related errors"""
        # Check nvidia-smi
        smi_output = self.run_command(["nvidia-smi"])
        if not smi_output:
            self.diagnostics["symptoms"].append("nvidia-smi not available or failed")
            self.diagnostics["likely_causes"].append("GPU driver issue or no GPU access")
            self.diagnostics["recommended_actions"].extend([
                "Verify GPU driver installation",
                "Check GPU allocation in SLURM (--gres=gpu:X)",
                "Verify cgroup configuration for GPU access",
            ])
            return True

        # Check dmesg for GPU errors
        dmesg_output = self.run_command(["dmesg", "-T"])
        if dmesg_output:
            gpu_keywords = ["xid", "gpu", "nvidia", "cuda", "nvrm"]
            if any(keyword in dmesg_output.lower() for keyword in gpu_keywords):
                self.diagnostics["symptoms"].append("GPU-related errors in system log")
                self.diagnostics["likely_causes"].append("GPU hardware error or driver issue")
                self.diagnostics["recommended_actions"].extend([
                    "Check dmesg for GPU XID errors",
                    "Verify GPU health with nvidia-smi -q",
                    "Check GPU temperature and power limits",
                    "May need to exclude faulty GPU from SLURM",
                ])
                return True

        return False

    def check_nccl_errors(self) -> bool:
        """Check for NCCL communication errors"""
        # Check for NCCL environment variables
        nccl_vars = ["NCCL_DEBUG", "NCCL_DEBUG_SUBSYS", "NCCL_SOCKET_IFNAME"]
        nccl_set = [var for var in nccl_vars if os.environ.get(var)]

        if not nccl_set:
            self.diagnostics["symptoms"].append("NCCL debug not enabled")
            self.diagnostics["recommended_actions"].append(
                "Enable NCCL_DEBUG=INFO for detailed communication logs"
            )

        # Common NCCL issues based on exit code
        if self.exit_code in [139, 134]:  # SIGSEGV, SIGABRT
            self.diagnostics["symptoms"].append("Segmentation fault or abort signal")
            self.diagnostics["likely_causes"].extend([
                "NCCL communication failure",
                "Network timeout or packet loss",
                "Incompatible NCCL version with CUDA",
            ])
            self.diagnostics["recommended_actions"].extend([
                "Check network connectivity between nodes",
                "Verify NCCL version compatibility with CUDA",
                "Set NCCL_SOCKET_IFNAME to correct network interface",
                "Increase NCCL_TIMEOUT (default 1800s)",
            ])
            return True

        return False

    def check_mpi_errors(self) -> bool:
        """Check for MPI-related errors"""
        # Check PMIx availability
        pmix_lib = Path("/usr/lib/x86_64-linux-gnu/libpmix.so.2")
        if not pmix_lib.exists():
            self.diagnostics["symptoms"].append("PMIx library not found")
            self.diagnostics["likely_causes"].append("MPI/PMIx not properly installed")
            self.diagnostics["recommended_actions"].extend([
                "Install PMIx libraries (libpmix2)",
                "Verify SLURM was compiled with PMIx support",
            ])
            return True

        # Exit codes related to MPI failures
        if self.exit_code in [1, 127, 255]:
            self.diagnostics["likely_causes"].extend([
                "MPI initialization failure",
                "Process communication error",
                "Hostname resolution issue",
            ])
            self.diagnostics["recommended_actions"].extend([
                "Check /etc/hosts for correct node entries",
                "Verify SSH connectivity between nodes",
                "Check SLURM node configuration (scontrol show node)",
            ])
            return True

        return False

    def check_container_errors(self) -> bool:
        """Check for container-related errors"""
        # Check container runtime
        apptainer_available = self.run_command(["which", "apptainer"]) is not None
        singularity_available = self.run_command(["which", "singularity"]) is not None

        if not (apptainer_available or singularity_available):
            self.diagnostics["symptoms"].append("No container runtime available")
            self.diagnostics["likely_causes"].append("Container runtime not installed")
            self.diagnostics["recommended_actions"].extend([
                "Install Apptainer or Singularity",
                "Verify container runtime in SLURM configuration",
            ])
            return True

        # Check for mount/bind errors (common in containers)
        if self.exit_code in [1, 2]:
            self.diagnostics["likely_causes"].extend([
                "Container mount point not accessible",
                "Permission denied for container paths",
                "Missing container image or incorrect path",
            ])
            self.diagnostics["recommended_actions"].extend([
                "Verify container image path is accessible",
                "Check bind mount paths in container execution",
                "Ensure correct file permissions on mount points",
            ])
            return True

        return False

    def check_network_errors(self) -> bool:
        """Check for network-related errors"""
        # Check network interfaces
        ip_output = self.run_command(["ip", "addr", "show"])
        if not ip_output:
            self.diagnostics["symptoms"].append("Cannot query network interfaces")
            return True

        # Check for common network issues in dmesg
        dmesg_output = self.run_command(["dmesg", "-T"])
        if dmesg_output:
            network_keywords = ["network", "timeout", "connection", "unreachable"]
            if any(keyword in dmesg_output.lower() for keyword in network_keywords):
                self.diagnostics["symptoms"].append("Network-related errors in system log")
                self.diagnostics["likely_causes"].extend([
                    "Network connectivity issue between nodes",
                    "Firewall blocking SLURM/MPI ports",
                    "Network interface misconfiguration",
                ])
                self.diagnostics["recommended_actions"].extend([
                    "Test inter-node connectivity (ping, nc)",
                    "Check firewall rules (iptables, firewalld)",
                    "Verify correct network interface for MPI/NCCL",
                ])
                return True

        return False

    def check_disk_space(self) -> bool:
        """Check for disk space issues"""
        df_output = self.run_command(["df", "-h"])
        if df_output:
            # Parse df output and check for >90% usage
            for line in df_output.split("\n")[1:]:
                parts = line.split()
                if len(parts) >= 5:
                    try:
                        usage = int(parts[4].rstrip("%"))
                        if usage > 90:
                            mount_point = parts[5] if len(parts) > 5 else parts[4]
                            self.diagnostics["symptoms"].append(
                                f"Disk usage high: {usage}% on {mount_point}"
                            )
                            self.diagnostics["likely_causes"].append("Insufficient disk space")
                            self.diagnostics["recommended_actions"].extend([
                                "Clean up temporary files in /tmp, /var/tmp",
                                "Remove old log files",
                                "Increase disk allocation for job",
                            ])
                            return True
                    except (ValueError, IndexError):
                        continue
        return False

    def categorize_failure(self):
        """Categorize the failure based on exit code and symptoms"""
        if self.exit_code == 0:
            self.diagnostics["failure_category"] = "success"
        elif self.exit_code == 137:
            self.diagnostics["failure_category"] = "oom_killed"
            self.diagnostics["likely_causes"].append("Process killed by OOM killer (SIGKILL)")
        elif self.exit_code == 139:
            self.diagnostics["failure_category"] = "segmentation_fault"
        elif self.exit_code in [134, 6]:
            self.diagnostics["failure_category"] = "abort_signal"
        elif self.exit_code == 143:
            self.diagnostics["failure_category"] = "terminated"
            self.diagnostics["likely_causes"].append("Process terminated (SIGTERM)")
        elif self.exit_code == 124:
            self.diagnostics["failure_category"] = "timeout"
            self.diagnostics["likely_causes"].append("Job exceeded time limit")
        elif self.exit_code == 1:
            self.diagnostics["failure_category"] = "general_error"
        else:
            self.diagnostics["failure_category"] = f"exit_code_{self.exit_code}"

    def collect_system_state(self):
        """Collect current system state"""
        # Memory
        free_output = self.run_command(["free", "-h"])
        if free_output:
            self.diagnostics["system_state"]["memory"] = free_output.split("\n")[1]

        # GPU state
        gpu_output = self.run_command(["nvidia-smi", "--query-gpu=index,name,memory.used,memory.total", "--format=csv,noheader"])
        if gpu_output:
            self.diagnostics["system_state"]["gpus"] = gpu_output.strip().split("\n")

        # Load average
        uptime_output = self.run_command(["uptime"])
        if uptime_output:
            self.diagnostics["system_state"]["load"] = uptime_output.strip()

        # Disk usage
        df_output = self.run_command(["df", "-h", "/", "/tmp", "/var"])
        if df_output:
            self.diagnostics["system_state"]["disk"] = [
                line for line in df_output.split("\n")[1:] if line
            ]

    def run_diagnosis(self):
        """Run all diagnostic checks"""
        self.categorize_failure()

        # Run all checks
        checks = [
            self.check_oom_killer,
            self.check_gpu_errors,
            self.check_nccl_errors,
            self.check_mpi_errors,
            self.check_container_errors,
            self.check_network_errors,
            self.check_disk_space,
        ]

        for check in checks:
            try:
                check()
            except Exception as e:
                self.diagnostics["symptoms"].append(f"Check failed: {check.__name__}: {e}")

        # Collect system state
        self.collect_system_state()

        # Remove duplicates
        self.diagnostics["symptoms"] = list(set(self.diagnostics["symptoms"]))
        self.diagnostics["likely_causes"] = list(set(self.diagnostics["likely_causes"]))
        self.diagnostics["recommended_actions"] = list(set(self.diagnostics["recommended_actions"]))

    def save_report(self, output_path: str):
        """Save diagnostic report to JSON file"""
        try:
            with open(output_path, "w") as f:
                json.dump(self.diagnostics, f, indent=2)
            print(f"Diagnostic report saved to: {output_path}")
        except Exception as e:
            print(f"Failed to save report: {e}", file=sys.stderr)

    def print_report(self):
        """Print diagnostic report to stdout"""
        print("\n" + "=" * 80)
        print(f"SLURM Job Failure Diagnosis Report")
        print("=" * 80)
        print(f"Job ID: {self.job_id}")
        print(f"Exit Code: {self.exit_code}")
        print(f"Category: {self.diagnostics['failure_category']}")
        print(f"Timestamp: {self.timestamp}")
        print("=" * 80)

        if self.diagnostics["symptoms"]:
            print("\nSymptoms Detected:")
            for symptom in self.diagnostics["symptoms"]:
                print(f"  - {symptom}")

        if self.diagnostics["likely_causes"]:
            print("\nLikely Causes:")
            for cause in self.diagnostics["likely_causes"]:
                print(f"  - {cause}")

        if self.diagnostics["recommended_actions"]:
            print("\nRecommended Actions:")
            for action in self.diagnostics["recommended_actions"]:
                print(f"  - {action}")

        if self.diagnostics["system_state"]:
            print("\nSystem State:")
            for key, value in self.diagnostics["system_state"].items():
                print(f"  {key}: {value}")

        print("=" * 80 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Diagnose SLURM job failures for distributed training"
    )
    parser.add_argument(
        "--job-id",
        required=True,
        help="SLURM job ID",
    )
    parser.add_argument(
        "--exit-code",
        type=int,
        required=True,
        help="Job exit code",
    )
    parser.add_argument(
        "--output",
        required=False,
        help="Output JSON file path for diagnostic report",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print diagnostic report to stdout",
    )

    args = parser.parse_args()

    # Run diagnosis
    diagnostic = TrainingFailureDiagnostic(args.job_id, args.exit_code)
    diagnostic.run_diagnosis()

    # Print report if verbose
    if args.verbose:
        diagnostic.print_report()

    # Save report if output path specified
    if args.output:
        diagnostic.save_report(args.output)
    else:
        # Print to stdout as JSON
        print(json.dumps(diagnostic.diagnostics, indent=2))


if __name__ == "__main__":
    main()

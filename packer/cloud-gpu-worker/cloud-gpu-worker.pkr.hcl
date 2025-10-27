# Cloud GPU Worker Image Packer Template
# This template creates a Debian 13 (trixie) GPU-enabled Kubernetes worker image
# with NVIDIA drivers and container toolkit for accelerated workloads

# Include common Ansible variables
locals {
  ansible_env_vars = [
    "ANSIBLE_HOST_KEY_CHECKING=False",
    "ANSIBLE_ROLES_PATH=${var.repo_tot_dir}/ansible/roles",
    "ANSIBLE_REMOTE_TMP=/tmp"
  ]
}

packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
    ansible = {
      version = ">= 1.1.4"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# Variables for customization
variable "disk_size" {
  type        = string
  description = "Disk size for the cloud GPU worker image"
}

variable "memory" {
  type        = number
  description = "Memory allocation for build VM in MB"
}

variable "cpus" {
  type        = number
  description = "CPU cores for build VM"
}

variable "debian_cloud_image_url" {
  type        = string
  description = "Debian 13 cloud image URL"
}

variable "debian_cloud_image_checksum" {
  type    = string
  default = ""
}

variable "repo_tot_dir" {
  type        = string
  description = "Repository top of tree directory path"
}

variable "source_directory" {
  type        = string
  description = "Source directory path"
}

variable "build_directory" {
  type        = string
  description = "Base build directory path"
}

variable "image_name" {
  type        = string
  description = "Name identifier for the image (e.g., 'cloud-gpu-worker')"
}

variable "vm_name" {
  type        = string
  description = "Output VM image filename"
}

variable "cloud_init_dir" {
  type        = string
  description = "Directory containing cloud-init configuration files"
}

variable "ssh_keys_dir" {
  type        = string
  description = "Directory containing SSH key pair for authentication"
}

variable "ssh_username" {
  type        = string
  description = "SSH username used by the communicator and Ansible"
}

# Local variables
locals {
  output_directory = "${var.build_directory}"
}

# QEMU builder configuration
source "qemu" "cloud_gpu_worker" {
  # Basic VM configuration
  vm_name          = var.vm_name
  output_directory = local.output_directory
  disk_size        = var.disk_size
  memory           = var.memory
  cpus             = var.cpus

  # Use Debian cloud image as base
  iso_url      = var.debian_cloud_image_url
  iso_checksum = var.debian_cloud_image_checksum
  disk_image   = true
  format       = "qcow2"

  # QEMU/KVM acceleration
  accelerator    = "kvm"
  machine_type   = "pc"
  net_device     = "virtio-net"
  disk_interface = "virtio"

  # Drive optimization settings for TRIM support and size reduction
  disk_cache         = "writeback"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"

  # Display settings
  headless         = true
  vnc_bind_address = "127.0.0.1"
  vnc_port_min     = 5900
  vnc_port_max     = 6000

  # Cloud-init configuration
  cd_files = [
    "${var.cloud_init_dir}/user-data",
    "${var.cloud_init_dir}/meta-data"
  ]
  cd_label = "cidata"

  # Optimized boot wait - cloud-init typically completes in 30-45s
  boot_wait = "10s"

  # Communication settings - optimized for speed
  communicator           = "ssh"
  ssh_username           = var.ssh_username
  ssh_private_key_file   = "${var.ssh_keys_dir}/id_rsa"
  ssh_timeout            = "8m"
  ssh_port               = 22
  ssh_handshake_attempts = 15
  ssh_wait_timeout       = "5m"
  ssh_pty                = true

  # Optimized shutdown configuration
  shutdown_command = "sudo shutdown -P now"
  shutdown_timeout = "2m"

  # Optimized QEMU arguments for faster boot, debugging, and size optimization
  qemuargs = [
    ["-serial", "file:${var.build_directory}/../qemu-serial.log"],
    ["-serial", "mon:stdio"],
    # Faster boot configuration
    ["-boot", "order=cd,menu=off,splash-time=1000"],
    # Optimize for speed
    ["-cpu", "host"],
    ["-smp", "cpus=${var.cpus}"]
    # Note: Drive configuration with TRIM support (discard=unmap, disk_detect_zeroes=unmap)
    # is handled automatically by Packer using disk_cache, disk_discard, and disk_detect_zeroes settings above
  ]
}

# Build configuration with GPU worker provisioning
build {
  name    = "cloud-gpu-worker-image"
  sources = ["source.qemu.cloud_gpu_worker"]

  # Wait for cloud-init to complete and verify SSH setup
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Cloud-init completed successfully'"
    ]
  }

  # System preparation with GPU prerequisites
  provisioner "file" {
    source      = "${var.source_directory}/setup-gpu-worker.sh"
    destination = "/tmp/setup-gpu-worker.sh"
  }

  provisioner "shell" {
    inline = [
      "echo 'Running GPU worker setup script...'",
      "chmod +x /tmp/setup-gpu-worker.sh",
      "DEBIAN_FRONTEND=noninteractive sudo /tmp/setup-gpu-worker.sh",
      "rm -f /tmp/setup-gpu-worker.sh",
      "echo 'GPU worker setup script completed'"
    ]
  }

  # Install GPU worker packages using specialized Ansible playbook
  provisioner "ansible" {
    playbook_file    = "${var.repo_tot_dir}/ansible/playbooks/playbook-cloud-packer-gpu-worker.yml"
    ansible_env_vars = local.ansible_env_vars
    command          = "/usr/bin/ansible-playbook"
    extra_arguments = [
      "-u", var.ssh_username,
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
      "--extra-vars", "{\"packer_build\":true}",
      "--extra-vars", "{\"gpu_enabled\":true}",
      "--extra-vars", "{\"nvidia_install_drivers_only\":true}",
      "--extra-vars", "{\"nvidia_install_cuda\":false}",
      "--extra-vars", "{\"nvidia_packer_build\":true}",
      "--become",
      "--become-user=root",
      "-v"
    ]
    use_proxy = false
  }

  # Verify GPU driver installation
  provisioner "shell" {
    inline = [
      "echo 'Verifying NVIDIA driver installation...'",
      "nvidia-smi || echo 'WARNING: nvidia-smi not working (expected in VM without GPU passthrough)'",
      "ls -la /usr/bin/nvidia-smi",
      "echo 'GPU driver verification complete'"
    ]
  }

  # Final cleanup for cloning - optimized for speed and size
  provisioner "shell" {
    # Use bash and set options within the script (shebang only supports a single arg)
    inline_shebang = "/usr/bin/env bash"
    inline = [
      "set -xeuo pipefail",
      "echo 'Performing comprehensive cleanup and size optimization...'",
      # Remove package caches and temporary files
      "sudo apt-get clean && sudo apt-get autoclean && sudo apt-get autoremove -y",
      "sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*",
      # Clear all log files and journal
      "sudo truncate -s 0 /var/log/*log 2>/dev/null || true",
      "sudo find /var/log -type f -name '*.log' -exec truncate -s 0 {} + 2>/dev/null || true",
      "sudo journalctl --vacuum-time=1s 2>/dev/null || true",
      "sudo rm -rf /var/log/journal/* 2>/dev/null || true",
      # Clear shell histories and identifiers
      "sudo rm -f /root/.bash_history /home/${var.ssh_username}/.bash_history || true",
      "sudo truncate -s 0 /etc/machine-id; sudo rm -f /var/lib/dbus/machine-id",
      # Remove SSH host keys and network persistence
      "sudo rm -f /etc/ssh/ssh_host_* /etc/udev/rules.d/70-persistent-net.rules",
      # Clean cloud-init state
      "sudo cloud-init clean --logs",
      # Remove unnecessary documentation and man pages
      "sudo rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/*",
      "sudo rm -rf /usr/share/locale/*",
      # Preserve timezone data for system functionality
      "sudo find /usr/share/zoneinfo -type f ! -name 'UTC' ! -name 'GMT' ! -name 'GMT+*' ! -name 'GMT-*' -delete 2>/dev/null || true",
      # Remove package manager cache and temporary files
      "sudo rm -rf /var/cache/apt/* /var/cache/debconf/*",
      # Clear systemd journal and logs
      "sudo systemctl stop systemd-journald 2>/dev/null || true",
      "sudo rm -rf /var/log/journal/* /run/log/journal/*",
      "echo 'Cleanup complete'"
    ]
  }

  # Regenerate SSH host keys after cleanup to ensure SSH service can start
  provisioner "shell" {
    inline = [
      "echo 'Regenerating SSH host keys...'",
      "sudo ssh-keygen -A",
      "echo 'SSH host keys regenerated successfully'"
    ]
  }

  # Zero-fill free space to trim dirty pages and optimize image compression
  provisioner "shell" {
    inline = [
      "echo 'Zero-filling free space to optimize image size...'",
      # Create a large file filled with zeros, then delete it
      # This forces the filesystem to mark all free space as zeros
      "FREE_SPACE=$(df --output=avail /tmp | tail -1)",
      "sudo dd if=/dev/zero of=/tmp/zero_fill bs=1M count=$FREE_SPACE status=none 2>/dev/null || true",
      "sudo rm -f /tmp/zero_fill",
      # Clear swap if it exists
      "sudo swapoff -a 2>/dev/null || true",
      "sudo rm -f /swapfile /swap.img 2>/dev/null || true",
      "echo 'Zero-fill complete'"
    ]
  }

  # Optimize and compress the final QEMU image
  post-processor "shell-local" {
    inline = [
      "echo 'Optimizing and compressing QEMU image...'",
      "cd ${local.output_directory}",
      # Get original image size
      "ORIGINAL_SIZE=$(du -h ${var.vm_name} | cut -f1)",
      "echo Original image size: $ORIGINAL_SIZE",
      # Convert to compressed qcow2 with optimization
      "qemu-img convert -c -O qcow2 ${var.vm_name} ${var.vm_name}.compressed",
      # Replace original with compressed version
      "mv ${var.vm_name}.compressed ${var.vm_name}",
      # Get final image size
      "FINAL_SIZE=$(du -h ${var.vm_name} | cut -f1)",
      "echo Final compressed image size: $FINAL_SIZE",
      # Additional optimization: check and repair if needed
      "qemu-img check ${var.vm_name}",
      "echo 'Image optimization complete'"
    ]
  }

  # Create build metadata
  post-processor "shell-local" {
    inline = [
      "echo 'Creating build metadata...'",
      "mkdir -p ${local.output_directory}",
      "date > ${local.output_directory}/build_timestamp.txt",
      "echo 'Cloud GPU Worker Image (${var.image_name})' > ${local.output_directory}/image_type.txt",
      "echo '${var.vm_name}' > ${local.output_directory}/image_name.txt",
      "echo 'Debian 13 (trixie) Cloud Image' > ${local.output_directory}/base_image.txt",
      "echo 'Kubernetes + NVIDIA GPU drivers + container toolkit + DCGM monitoring' > ${local.output_directory}/features.txt",
      "echo 'Size optimized with zero-fill and compression' > ${local.output_directory}/optimization.txt",
      "ls -la ${local.output_directory}/ > ${local.output_directory}/contents.txt"
    ]
  }
}

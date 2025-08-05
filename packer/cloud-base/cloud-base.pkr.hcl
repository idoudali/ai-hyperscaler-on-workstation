# Cloud Base Image Packer Template
# This template creates a minimal Debian 13 (trixie) base image optimized for Kubernetes workloads
# using Debian cloud image as base with cloud-init configuration

packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

# Variables for customization
variable "disk_size" {
  type        = string
  description = "Disk size for the Cloud base image"
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

variable "build_directory" {
  type        = string
  description = "Base build directory path"
}

variable "image_name" {
  type        = string
  description = "Name identifier for the image (e.g., 'cloud-base')"
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

# Local variables
locals {
  output_directory = "${var.build_directory}"
}

# QEMU builder configuration
source "qemu" "cloud_base" {
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
  boot_wait = "45s"

  # Communication settings - optimized for speed
  communicator           = "ssh"
  ssh_username           = "debian"
  ssh_private_key_file   = "${var.ssh_keys_dir}/id_rsa"
  ssh_timeout            = "8m" # Reduced from 15m
  ssh_port               = 22
  ssh_handshake_attempts = 15   # Reduced from 20
  ssh_wait_timeout       = "5m" # Reduced from 15m
  ssh_pty                = true

  # Optimized shutdown configuration
  shutdown_command = "sudo shutdown -P now"
  shutdown_timeout = "2m"

  # Optimized QEMU arguments for faster boot and debugging
  qemuargs = [
    ["-serial", "file:${var.build_directory}/../qemu-serial.log"],
    ["-serial", "mon:stdio"],
    # Faster boot configuration
    ["-boot", "order=cd,menu=off,splash-time=1000"],
    # Optimize for speed
    ["-cpu", "host"],
    ["-smp", "cpus=${var.cpus}"]
  ]
}

# Build configuration with minimal provisioning
build {
  name    = "cloud-base-image"
  sources = ["source.qemu.cloud_base"]

  # Wait for cloud-init to complete and verify SSH setup
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Cloud-init completed successfully'"
    ]
  }

  # Minimal system preparation - optimized for speed
  provisioner "shell" {
    inline = [
      "echo 'Performing minimal system preparation...'",
      # Combined update and upgrade with optimizations
      "sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq",
      # Quick cleanup
      "sudo apt-get autoremove -y -qq && sudo apt-get autoclean -qq",
      "echo 'System preparation complete'"
    ]
  }

  # Final cleanup for cloning - optimized for speed
  provisioner "shell" {
    inline = [
      "echo 'Performing final cleanup...'",
      # Combined cleanup operations for speed
      "sudo apt-get clean",
      "sudo truncate -s 0 /var/log/*log 2>/dev/null || true",
      "sudo find /var/log -type f -name '*.log' -exec truncate -s 0 {} + 2>/dev/null || true",
      # Clear history and identifiers
      "history -c && history -w; sudo rm -f /root/.bash_history",
      "sudo truncate -s 0 /etc/machine-id; sudo rm -f /var/lib/dbus/machine-id",
      # Remove SSH host keys and network persistence
      "sudo rm -f /etc/ssh/ssh_host_* /etc/udev/rules.d/70-persistent-net.rules",
      # Clean cloud-init state
      "sudo cloud-init clean --logs",
      "echo 'Cleanup complete'"
    ]
  }

  # Create build metadata
  post-processor "shell-local" {
    inline = [
      "echo 'Creating build metadata...'",
      "mkdir -p ${local.output_directory}",
      "date > ${local.output_directory}/build_timestamp.txt",
      "echo 'Cloud Base Image (${var.image_name})' > ${local.output_directory}/image_type.txt",
      "echo '${var.vm_name}' > ${local.output_directory}/image_name.txt",
      "echo 'Debian 13 (trixie) Cloud Image' > ${local.output_directory}/base_image.txt",
      "ls -la ${local.output_directory}/ > ${local.output_directory}/contents.txt"
    ]
  }
}

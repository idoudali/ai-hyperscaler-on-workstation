
The Hyperscaler on a Workstation: An Automated Approach to Emulating an Advanced AI Infrastructure


Section 1: The Foundation: Host Preparation and Virtualization

The successful emulation of a complex, multi-environment AI infrastructure begins with the meticulous preparation of the physical host machine. This foundational layer, comprising the host operating system, the hypervisor, specialized networking, and critical NVIDIA drivers, establishes the bedrock upon which the entire virtualized architecture will be constructed. The objective of this section is to configure a stable, high-performance virtualization environment that mirrors the logical separation of the High-Performance Computing (HPC) and Cloud clusters as envisioned in the "AI Hyperscaler Blueprint" design document.1 This involves not only installing the necessary software but also configuring it to enable the advanced GPU partitioning capabilities required for this emulation. The subsequent sections will introduce powerful automation tools like Packer and Ansible to streamline the creation and configuration of this virtualized environment.

1.1 Host System Prerequisites and Configuration

The selection of a suitable host system and its correct initial configuration are paramount. The entire emulation relies on specific hardware features and a clean software environment to avoid conflicts and ensure stability.
The primary hardware requirement is a server or workstation equipped with an NVIDIA A100 GPU and a modern multi-core CPU that supports hardware virtualization extensions (Intel VT-x or AMD-V). These extensions are essential for the KVM hypervisor to operate efficiently. The host operating system for this guide will be Debian 12 "Bookworm," chosen for its stability and robust support for the required virtualization and kernel technologies.
Before proceeding with software installation, it is critical to verify these hardware prerequisites. First, ensure that CPU virtualization support is enabled in the system's BIOS/UEFI settings. This can be confirmed within the operating system by installing the cpu-checker utility and running the kvm-ok command. A successful check will return the message: INFO: /dev/kvm exists KVM acceleration can be used.
Second, Input-Output Memory Management Unit (IOMMU) support (Intel VT-d or AMD-Vi) must also be enabled in the BIOS/UEFI. IOMMU is a crucial technology that allows the hypervisor to provide virtual machines with exclusive access to physical hardware devices, which is the underlying mechanism for GPU passthrough.2 This can be verified by checking the kernel boot logs for IOMMU-related messages.
Finally, a critical preparatory step is to prevent the default open-source NVIDIA driver, nouveau, from loading. The nouveau driver conflicts with the proprietary NVIDIA drivers required for vGPU and MIG functionality. Failure to blacklist it will result in the proprietary drivers being unable to bind to the GPU, causing the entire setup to fail. This is accomplished by adding modprobe.blacklist=nouveau to the kernel boot parameters, typically in the /etc/default/grub file, and then updating the GRUB configuration and rebooting the system.2

1.2 Installing and Configuring the KVM/QEMU Hypervisor and Libvirt

With the host system properly prepared, the next step is to install the virtualization stack. This guide utilizes the Kernel-based Virtual Machine (KVM), a Type-1 hypervisor built directly into the Linux kernel, in conjunction with QEMU for hardware emulation and the libvirt toolkit for management.
The necessary packages are available in the standard Debian 12 repositories and can be installed with a single apt command. For a server environment without a graphical interface, it is recommended to use the --no-install-recommends flag to avoid installing unnecessary graphical packages.5

Bash


sudo apt update
sudo apt install --no-install-recommends qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst


This command installs the core components:
qemu-kvm: The backend that provides the full machine emulation.
libvirt-daemon-system: The libvirtd daemon that manages the hypervisor and virtual machines.
libvirt-clients: Provides the command-line tools for interacting with libvirt, most notably virsh.
bridge-utils: Tools for creating and managing network bridges.
virtinst: Provides the virt-install tool for scripted VM creation.
After installation, the libvirtd service should start automatically. Its status can be verified using systemctl status libvirtd. For ease of management, the current user should be added to the libvirt and kvm groups. This allows the user to manage virtual machines using virsh and other tools without needing to use sudo for every command. A logout and login are required for this group membership to take effect.

Bash


sudo usermod -aG libvirt $(whoami)
sudo usermod -aG kvm $(whoami)



1.3 Installing the NVIDIA Host Driver and vGPU Manager

The selection and installation of the correct NVIDIA driver on the host is arguably the most critical and nuanced step in the entire setup process. Standard NVIDIA datacenter drivers, while suitable for bare-metal or containerized workloads, lack the specific components required for GPU virtualization with KVM. To enable the partitioning and passthrough of GPU slices, the NVIDIA vGPU software package must be used.
The distinction is not trivial. The NVIDIA vGPU software includes the vGPU Manager, a component that installs specialized kernel modules and creates the necessary interfaces within the Linux sysfs filesystem. These interfaces expose "mediated device" (mdev) types, which are the standardized kernel objects that libvirt and KVM use to represent and assign virtual GPUs to guest VMs.3 Without the vGPU Manager, the host operating system has no mechanism to create these virtual devices, and GPU passthrough will be impossible. The vGPU software is enterprise-grade and must be downloaded from the NVIDIA Licensing Portal after acquiring the appropriate licenses.3
The downloaded package will include a .run file installer for the vGPU manager (e.g., NVIDIA-Linux-x86_64-xxx.xx.xx-vgpu-kvm.run). Before installation, any required kernel development packages must be installed to allow the installer to compile the necessary kernel modules for the host's running kernel.6

Bash


# Install kernel headers for the current kernel
sudo apt install -y linux-headers-$(uname -r)

# Make the installer executable and run it
chmod +x NVIDIA-Linux-x86_64-*.run
sudo./NVIDIA-Linux-x86_64-*.run


During the installation, accept the license agreement and allow the installer to register the kernel modules with DKMS (Dynamic Kernel Module Support) if prompted. This ensures the NVIDIA modules are automatically recompiled if the host kernel is updated. After a successful installation and a system reboot, the nvidia-smi command should function correctly and display the A100 GPU's status, confirming that the vGPU Manager driver is loaded and active.3

1.4 Architecting the Virtual Networks: Creating Isolated Bridges for HPC and Cloud

To accurately emulate the distinct infrastructure stacks from the design document, it is essential to create separate, isolated virtual networks for the HPC cluster and the 'Pharos' cloud. The design document specifies different physical networking for training (InfiniBand) and inference (Ethernet) to optimize for different workloads.1 While the performance characteristics of InfiniBand cannot be replicated in this virtual environment, the principle of logical and network isolation can and should be emulated.
This is achieved by creating two distinct virtual network bridges using libvirt. By default, libvirt creates a single network named default, which operates in NAT mode and uses the virbr0 bridge device. For this emulation, two new networks will be created: hpc-net for the SLURM cluster and pharos-net for the Kubernetes cluster. This creates two separate Layer 2 broadcast domains, preventing network chatter between the environments and allowing for independent network policies and IP address schemes.
These networks are defined using XML files and managed with the virsh command-line tool.
1. Create the XML definition for hpc-net (e.g., hpc-net.xml):
This network will use the 192.168.100.0/24 subnet.

XML


<network>
  <name>hpc-net</name>
  <forward mode='nat'/>
  <bridge name='virbr100' stp='on' delay='0'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.100.10' end='192.168.100.254'/>
    </dhcp>
  </ip>
</network>


2. Create the XML definition for pharos-net (e.g., pharos-net.xml):
This network will use the 192.168.200.0/24 subnet.

XML


<network>
  <name>pharos-net</name>
  <forward mode='nat'/>
  <bridge name='virbr200' stp='on' delay='0'/>
  <ip address='192.168.200.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.200.10' end='192.168.200.254'/>
    </dhcp>
  </ip>
</network>


3. Define, start, and autostart the networks using virsh:

Bash


# Define and start the HPC network
sudo virsh net-define hpc-net.xml
sudo virsh net-start hpc-net
sudo virsh net-autostart hpc-net

# Define and start the Pharos cloud network
sudo virsh net-define pharos-net.xml
sudo virsh net-start pharos-net
sudo virsh net-autostart pharos-net

# Verify the networks are active
sudo virsh net-list


This completes the foundational setup of the host. The system now has a robust hypervisor, the correct GPU drivers for virtualization, and a logically partitioned network architecture ready for the deployment of the virtual machines.

Component
Recommended Version/Specification
Rationale
Host Operating System
Debian 12 "Bookworm"
Stable, long-term support Linux distribution with modern kernel features.
Host Kernel
6.1+ (Debian 12 default)
Required for compatibility with modern KVM and NVIDIA driver features.
Hypervisor
KVM/QEMU
Native Linux hypervisor providing high performance and direct kernel integration.
Management Toolkit
Libvirt
Standard API and toolset for managing KVM/QEMU virtual machines and networks.
NVIDIA Host Driver
NVIDIA vGPU Manager 15.x+
The specific driver package required to enable MIG and create mediated devices (mdevs) for KVM. Standard datacenter drivers will not work. 8


Network Name
Bridge Interface
IP Address Range
DHCP Range
Purpose
hpc-net
virbr100
192.168.100.0/24
192.168.100.10 - 192.168.100.254
Isolated network for the emulated SLURM HPC cluster VMs.
pharos-net
virbr200
192.168.200.0/24
192.168.200.10 - 192.168.200.254
Isolated network for the emulated 'Pharos' Kubernetes cloud VMs.


Section 2: Carving the Core: GPU Partitioning for a Hybrid Environment

With the host system prepared, the focus shifts to partitioning the physical NVIDIA A100 GPU. This emulation creates a hybrid environment where GPU resources are strategically allocated to both the HPC cluster for training and the 'Pharos' cloud for accelerated inference. NVIDIA's Multi-Instance GPU (MIG) technology allows a single Ampere-architecture GPU to be securely partitioned into multiple, fully isolated GPU Instances (GIs), each with its own dedicated compute, memory, and cache resources.1 This section details the process of creating and allocating these virtual GPUs to their respective clusters.

2.1 Enabling MIG (Multi-Instance GPU) Mode on the A100

By default, an A100 GPU operates in a monolithic mode. To enable partitioning, it must first be explicitly placed into MIG mode. This is a system-level change that requires superuser privileges and a GPU reset, meaning any applications currently using the GPU must be terminated. On systems running monitoring daemons like NVIDIA's Data Center GPU Manager (DCGM), these services must be stopped before attempting to change the MIG mode.
The process is managed via the nvidia-smi command-line utility.
1. Stop conflicting services (if running):

Bash


sudo systemctl stop dcgm


2. Enable MIG mode for the first GPU (index 0):

Bash


sudo nvidia-smi -i 0 -mig 1


A successful command will output a message confirming that MIG mode has been enabled for the specified GPU. In some cases, a system reboot may be required to apply the change.
3. Verify MIG mode:
After the command completes, verify that MIG mode is active:

Bash


nvidia-smi -i 0 --query-gpu=mig.mode.current --format=csv


The output should be Enabled. The standard nvidia-smi output will also now show "MIG M." as "Enabled".10

2.2 Strategic Partitioning: A Hybrid Layout for Training and Inference

The NVIDIA A100 GPU can be partitioned into a maximum of seven GPU Instances.1 To create a balanced hybrid environment that serves both training and inference workloads, we will divide these instances between the two clusters. A logical allocation is:
Four GPU Instances for the HPC cluster, enabling a powerful 4-node distributed training environment.
Three GPU Instances for the 'Pharos' cloud, creating a 3-node pool for GPU-accelerated inference within the Kubernetes cluster.
To maximize the number of nodes, the optimal strategy is to create seven identical 1g.5gb instances. This provides one vGPU for each of the seven planned GPU-enabled VMs, giving each an isolated slice of the A100 with approximately 5GB of VRAM and 1/7th of the GPU's streaming multiprocessors.

2.3 Creating GPU Instances and Corresponding Mediated Devices (mdevs)

The process of making a MIG slice available to a KVM virtual machine is a two-stage abstraction. First, NVIDIA's tools are used to create the hardware-level partition, the GPU Instance (GI). Second, the Linux kernel's mediated device (mdev) framework is used to create a virtual device that libvirt and KVM can attach to a VM.
Step 1: Create the seven GPU Instances (GIs)
Using the profile name 1g.5gb (profile ID 19 for an A100 40GB), the nvidia-smi mig -cgi command is used to create the instances.

Bash


# Create seven GPU Instances of type 1g.5gb (profile ID 19)
for i in {1..7}; do
  sudo nvidia-smi mig -i 0 -cgi 19 -C
done


After creation, nvidia-smi -L will list the physical GPU and all seven newly created MIG devices.10
Step 2: Create seven vGPU Mediated Devices (mdevs)
Now, for each GI, a corresponding mdev must be created by interacting with the sysfs filesystem.

Bash


# Identify the PCI address of the A100 GPU
PCI_ADDR=$(lspci | grep -i 'NVIDIA.*A100' | awk '{print $1}')
PCI_ADDR="0000:${PCI_ADDR}"

# Identify the vGPU type for the 1g.5gb profile
# (e.g., nvidia-471, name varies by driver)
VGPU_TYPE="nvidia-471" 

# Create the seven mdevs
for i in {0..6}; do
  MDEV_UUID=$(uuidgen)
  echo "Creating mdev ${i} with UUID: ${MDEV_UUID}"
  echo ${MDEV_UUID} | sudo tee /sys/bus/pci/devices/${PCI_ADDR}/mdev_supported_types/${VGPU_TYPE}/create
done


This completes the GPU partitioning. The single A100 is now logically divided into seven independent, virtual GPUs, ready for allocation according to the master plan below.

**Note on Schema Evolution**: The current implementation has evolved to use a simplified per-VM PCIe passthrough configuration instead of this complex MIG+mdev approach. In the updated schema, each VM directly specifies its PCIe device assignments in its `pcie_passthrough` configuration block, providing greater flexibility and simpler management. The global GPU inventory serves as a reference for conflict detection.

MIG Profile
Mediated Device (mdev) UUID (Generated)
Assigned VM Name
Cluster Role
1g.5gb
MDEV-UUID-1
hpc-compute-01
HPC Compute Node
1g.5gb
MDEV-UUID-2
hpc-compute-02
HPC Compute Node
1g.5gb
MDEV-UUID-3
hpc-compute-03
HPC Compute Node
1g.5gb
MDEV-UUID-4
hpc-compute-04
HPC Compute Node
1g.5gb
MDEV-UUID-5
k8s-worker-gpu-01
Kubernetes GPU Worker
1g.5gb
MDEV-UUID-6
k8s-worker-gpu-02
Kubernetes GPU Worker
1g.5gb
MDEV-UUID-7
k8s-worker-gpu-03
Kubernetes GPU Worker
N/A
N/A
k8s-worker-cpu-01
Kubernetes CPU Worker


Section 3: Automating Image Creation with Packer

To ensure a consistent and reproducible foundation for all virtual machines, we introduce HashiCorp Packer. Packer automates the creation of machine images, producing a "golden image" that can be used as a base for both the HPC and Pharos cluster VMs. This approach replaces manual, per-VM OS installation with a standardized, automated process, significantly reducing setup time and eliminating configuration drift.

3.1 Introduction to Packer for Building QEMU Images

Packer works by taking a template file, which defines a source (like an ISO file) and a builder (like QEMU), and then runs a series of provisioning steps to configure the image. For this emulation, we will use the Packer QEMU builder to create a Debian 12 image. The key to automation is a "preseed" file, which contains answers to all the questions normally asked during a Debian installation, allowing it to run unattended.12

3.2 Creating a Packer Template for Debian 12

The Packer configuration is written in HCL (HashiCorp Configuration Language). The following template defines a build for a Debian 12 QEMU image.
debian12.pkr.hcl:

Terraform


packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "disk_size" {
  type    = string
  default = "100G"
}

source "qemu" "debian" {
  vm_name            = "debian12-base.qcow2"
  iso_url            = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso"
  iso_checksum       = "sha256:a293323344379514e75a5a083376b134355b30a46245de22a0fd113856551eb8"
  output_directory   = "output-debian-base"
  disk_size          = var.disk_size
  format             = "qcow2"
  accelerator        = "kvm"
  headless           = true
  net_device         = "virtio-net"
  disk_interface     = "virtio"
  
  http_directory     = "http"

  boot_wait          = "10s"
  boot_command =
}

build {
  name    = "debian-base-image"
  sources = ["source.qemu.debian"]
}


This template instructs Packer to:
Download the Debian 12 net-installer ISO.
Start a temporary HTTP server to serve files from a local http/ directory.14
Launch a QEMU VM, boot from the ISO, and type a specific boot_command.
The boot_command tells the Debian installer to fetch its configuration from the preseed.cfg file served by Packer's temporary HTTP server, enabling a fully unattended installation.12

3.3 Building the Golden Image

Before running Packer, you must create the http/preseed.cfg file. This file contains the configuration for the Debian installation, including user setup, partitioning, and software selection (e.g., enabling the SSH server).
Once the preseed.cfg file is in place, you can build the image:

Bash


packer build.


Packer will execute the steps defined in the template, resulting in a debian12-base.qcow2 file in the output-debian-base/ directory. This qcow2 file is the "golden image" that will be used as the base for all subsequent VM deployments.

Section 4: Building the HPC Training Cluster with Ansible

This section details the construction of the emulated HPC training cluster. We will leverage the Packer golden image for rapid provisioning and Ansible for automated configuration. This environment is designed for batch-oriented, high-throughput workloads and will be managed by the SLURM Workload Manager.1 The process involves provisioning one controller and four compute nodes, attaching the virtual GPUs, and using an Ansible playbook to perform a full, repeatable installation of the SLURM stack.

4.1 Provisioning HPC VMs Declaratively

Instead of using imperative commands like virt-install, we will use declarative, "Infrastructure as Code" (IaC) approaches to define and create the virtual machines. This ensures the VM configurations are version-controlled, repeatable, and easy to manage.
First, create copy-on-write clones from the Packer-built debian12-base.qcow2 image. This is significantly faster and more space-efficient than creating full-sized disks for each VM.

Bash


BASE_IMAGE_PATH="output-debian-base/debian12-base.qcow2"
VM_IMAGE_DIR="/var/lib/libvirt/images"

# Create controller disk
sudo qemu-img create -f qcow2 -b ${BASE_IMAGE_PATH} ${VM_IMAGE_DIR}/hpc-controller.qcow2

# Create compute node disks
for i in $(seq -w 01 04); do
  sudo qemu-img create -f qcow2 -b ${BASE_IMAGE_PATH} ${VM_IMAGE_DIR}/hpc-compute-${i}.qcow2
done



4.1.1 Primary Method: Libvirt XML

Libvirt uses XML files as the definitive source for a VM's configuration. You can create a definition file for each VM and use virsh to register and start it.
Create the HPC Controller VM Definition (hpc-controller.xml):
This file defines the VM's name, resources, disk, and network interface.

XML


<domain type='kvm'>
  <name>hpc-controller</name>
  <memory unit='KiB'>4194304</memory> <vcpu placement='static'>2</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-7.2'>hvm</type>
    <boot dev='hd'/>
  </os>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/hpc-controller.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='network'>
      <source network='hpc-net'/>
      <model type='virtio'/>
    </interface>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <graphics type='none'/>
  </devices>
</domain>


Define and Start the VM:
Use the virsh define command to register the VM with libvirt from the XML file, then start it.

Bash


sudo virsh define hpc-controller.xml
sudo virsh start hpc-controller


This process should be repeated for all four compute nodes, using a unique XML file for each that specifies the correct name, resources, and disk path.

4.1.2 Alternative: Using Terraform

Terraform is a leading IaC tool that can manage the entire lifecycle of your VMs, including the creation of cloned disk volumes from the Packer base image. The Libvirt provider for Terraform enables you to define your KVM infrastructure in HCL.16
Create the Terraform Definition (hpc-cluster.tf):
This file defines the base image, the cloned disks (volumes), and the virtual machines (domains) that use them.

Terraform


terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Define the Packer-built base image as a libvirt volume
resource "libvirt_volume" "base_image" {
  name   = "debian12-base.qcow2"
  pool   = "default"
  source = "/path/to/output-debian-base/debian12-base.qcow2"
}

# Create a cloned volume for the controller
resource "libvirt_volume" "hpc_controller_disk" {
  name           = "hpc-controller.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.base_image.id
}

# Create the controller VM
resource "libvirt_domain" "hpc_controller" {
  name   = "hpc-controller"
  memory = "4096"
  vcpu   = 2

  disk {
    volume_id = libvirt_volume.hpc_controller_disk.id
  }

  network_interface {
    network_name = "hpc-net"
  }
  
  graphics {
    type = "none"
  }
}

# (Repeat for compute nodes...)


Initialize and Apply the Configuration:
Run terraform init once to download the provider, then terraform apply to create the resources.

Bash


terraform init
terraform apply



A Critical Warning on Terraform State Management and Recovery

When using Terraform, it is crucial to understand the role of the state file (terraform.tfstate). This file is Terraform's "memory," mapping the resources defined in your configuration to the actual VMs running on your hypervisor.18
What Happens if the State File is Deleted?
Your VMs are NOT destroyed. The virtual machines will continue to run.
Terraform loses its mapping. It becomes unaware of the infrastructure it previously created.19
The next terraform apply will fail. Without the state file, Terraform will try to create all the resources from scratch, leading to conflicts and errors because resources with the same names already exist.19
How to Recover a Deleted Local State File
If you are not using a remote backend and your local state file is accidentally deleted, do not run terraform apply. Follow these manual steps to recover:
Initialize a New State: Run terraform init in your project directory. This will create a new, empty terraform.tfstate file.
Identify Existing Resources: You must find the unique ID for each resource that still exists. For libvirt VMs, this is the UUID.
Bash
# List all VMs to get their names
virsh list --all

# Get the UUID for a specific VM
virsh domuuid hpc-controller
# Example Output: a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6


Import Each Resource: Use the terraform import command to tell Terraform about each existing resource, one by one. The command format is terraform import <terraform_resource_address> <resource_id>.20
Bash
# Import the HPC controller's disk volume (assuming its ID is known)
terraform import libvirt_volume.hpc_controller_disk /var/lib/libvirt/images/hpc-controller.qcow2

# Import the HPC controller VM
terraform import libvirt_domain.hpc_controller a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6

You must repeat this for every VM and every disk volume defined in your .tf files.
Verify the Recovery: After importing all resources, run terraform plan. If the recovery was successful, Terraform will report:
No changes. Your infrastructure matches the configuration.
This manual recovery process is tedious and error-prone. The best practice is to always use a remote backend (like AWS S3 or Terraform Cloud) which provides state locking, versioning, and backups to prevent this situation entirely.21 If a remote backend is not an option, you should implement a rigorous local backup strategy for your state file.

4.1.3 Alternative: Using Vagrant

Vagrant is a tool focused on creating and managing portable development environments using a Vagrantfile.24 The
vagrant-libvirt plugin allows Vagrant to use KVM as the hypervisor.26 Vagrant is box-centric and works best with pre-packaged images from a repository like Vagrant Cloud.
Create the Vagrant Definition (Vagrantfile):
This file defines all the VMs in the cluster, using a standard Debian 12 box and connecting them to the correct virtual network.

Ruby


Vagrant.configure("2") do |config|
  config.vm.box = "generic/debian12"
  config.vm.box_check_update = false

  # HPC Controller
  config.vm.define "hpc-controller" do |controller|
    controller.vm.hostname = "hpc-controller"
    controller.vm.network :private_network,
      ip: "192.168.100.10",
      libvirt__network_name: "hpc-net"

    controller.vm.provider "libvirt" do |libvirt|
      libvirt.memory = 4096
      libvirt.cpus = 2
    end
  end

  # HPC Compute Nodes
  (1..4).each do |i|
    node_num = format('%02d', i)
    config.vm.define "hpc-compute-#{node_num}" do |node|
      node.vm.hostname = "hpc-compute-#{node_num}"
      node.vm.network :private_network,
        ip: "192.168.100.#{10+i}",
        libvirt__network_name: "hpc-net"

      node.vm.provider "libvirt" do |libvirt|
        libvirt.memory = 8192
        libvirt.cpus = 4
      end
    end
  end
end


Launch the Environment:
Run vagrant up to download the box image (if needed) and create and start all defined VMs.

Bash


vagrant up --provider=libvirt



4.2 Introduction to Ansible for Configuration Management

Ansible is an automation tool that allows you to define your infrastructure as code using "playbooks." We will use Ansible to configure the newly created VMs, installing and setting up SLURM, MUNGE, and all other required software without manual intervention.
First, create an inventory file (inventory.ini) that defines the hosts in our cluster:

Ini, TOML


[hpc_controller]
hpc-controller ansible_host=192.168.100.10

[hpc_compute]
hpc-compute-01 ansible_host=192.168.100.11
hpc-compute-02 ansible_host=192.168.100.12
hpc-compute-03 ansible_host=192.168.100.13
hpc-compute-04 ansible_host=192.168.100.14

[hpc_cluster:children]
hpc_controller
hpc_compute



4.3 Ansible Playbook for SLURM Cluster Setup

A single Ansible playbook can orchestrate the entire cluster configuration. The playbook will use "roles" to logically separate the tasks for the controller and compute nodes.27
playbook-hpc.yml:

YAML


---
- name: Configure all HPC nodes
  hosts: hpc_cluster
  become: yes
  tasks:
    - name: Install common packages and configure MUNGE
      # Tasks to install munge, distribute the key, and start the service

- name: Configure SLURM Controller
  hosts: hpc_controller
  become: yes
  tasks:
    - name: Install slurm-wlm package
      apt:
        name: slurm-wlm
        state: present
    - name: Template slurm.conf
      template:
        src: templates/slurm.conf.j2
        dest: /etc/slurm-llnl/slurm.conf
    #... other controller-specific tasks

- name: Configure SLURM Compute Nodes
  hosts: hpc_compute
  become: yes
  tasks:
    - name: Install slurmd package
      apt:
        name: slurmd
        state: present
    #... other compute-specific tasks


This playbook would be executed with ansible-playbook -i inventory.ini playbook-hpc.yml.

4.4 Attaching vGPUs and Configuring GPU Scheduling via Ansible

The process of attaching vGPUs and creating SLURM's GPU configuration files can also be automated.
Attaching vGPUs: An Ansible task can generate the necessary XML snippet and use the community.libvirt.virt module or a shell command with virsh edit to attach the correct mdev device to each compute node VM.
Configuring SLURM for GPUs: The slurm.conf, gres.conf, and cgroup.conf files are ideal candidates for Ansible's template module. This allows you to generate the configuration files dynamically based on variables defined for your cluster.29
templates/gres.conf.j2:

Django


# This file is managed by Ansible
{% for host in groups['hpc_compute'] %}
NodeName={{ hostvars[host]['inventory_hostname'] }} Name=gpu File=/dev/nvidia0
{% endfor %}


This template snippet automatically generates the gres.conf file for all four compute nodes, making the configuration scalable and error-free. The ConstrainDevices=yes parameter in cgroup.conf remains crucial for enforcing job isolation by restricting a job's access to only the specific GPU device it was allocated.30

4.5 Cluster Verification

After the Ansible playbook completes, the final steps are to install the NVIDIA guest drivers inside the compute VMs (which can also be an Ansible task) and verify the cluster state from the controller.

Bash


# On hpc-controller
sinfo
# Example Output:
# PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
# gpu*         up   infinite      4   idle hpc-compute-[01-04]

srun --gres=gpu:1 --pty nvidia-smi


A successful srun command confirms that the fully automated deployment of the HPC cluster is complete and operational.

Section 5: Building the 'Pharos' Hybrid MLOps Cloud with Ansible

This section details the construction of the emulated 'Pharos' cloud, a modern, hybrid-compute, container-native environment built on Kubernetes. This platform is designed to host the MLOps software stack and support both CPU- and GPU-based inference workloads.1 The process involves provisioning a mix of CPU and GPU virtual machines, attaching the allocated vGPUs, and using a dedicated Ansible playbook to bootstrap a multi-node Kubernetes cluster and deploy the NVIDIA GPU Operator.

5.1 Provisioning Pharos VMs Declaratively

The Pharos cloud will be a heterogeneous cluster consisting of one control plane, one CPU-only worker node, and three GPU-enabled worker nodes. We will provision these VMs by creating copy-on-write clones of the Packer-built image.
Create Kubernetes VM Disks:

Bash


BASE_IMAGE_PATH="output-debian-base/debian12-base.qcow2"
VM_IMAGE_DIR="/var/lib/libvirt/images"

# Create control plane and CPU worker disks
sudo qemu-img create -f qcow2 -b ${BASE_IMAGE_PATH} ${VM_IMAGE_DIR}/k8s-cp.qcow2
sudo qemu-img create -f qcow2 -b ${BASE_IMAGE_PATH} ${VM_IMAGE_DIR}/k8s-worker-cpu-01.qcow2

# Create GPU worker node disks
for i in $(seq -w 01 03); do
  sudo qemu-img create -f qcow2 -b ${BASE_IMAGE_PATH} ${VM_IMAGE_DIR}/k8s-worker-gpu-${i}.qcow2
done


VMs can then be created using Libvirt XML, Terraform, or Vagrant as detailed in Section 4.1, ensuring they are attached to the pharos-net network.

5.2 Attaching vGPU Mediated Devices to Worker Node VMs

The three remaining vGPU mdevs from the master allocation plan are now attached to the three Kubernetes GPU worker nodes. This is done by editing the libvirt XML for each GPU worker VM (k8s-worker-gpu-01, k8s-worker-gpu-02, k8s-worker-gpu-03) using virsh edit and adding the <hostdev> block with the corresponding mdev UUID.

5.3 Ansible Playbook for Kubernetes Cluster Setup (kubeadm)

An Ansible playbook will automate the entire Kubernetes cluster bootstrap process, handling prerequisites, control plane initialization, and node joining.32
inventory.ini (additions for Kubernetes):

Ini, TOML


[k8s_cp]
k8s-cp ansible_host=192.168.200.10

[k8s_cpu_workers]
k8s-worker-cpu-01 ansible_host=192.168.200.11

[k8s_gpu_workers]
k8s-worker-gpu-01 ansible_host=192.168.200.12
k8s-worker-gpu-02 ansible_host=192.168.200.13
k8s-worker-gpu-03 ansible_host=192.168.200.14

[k8s_workers:children]
k8s_cpu_workers
k8s_gpu_workers

[k8s_cluster:children]
k8s_cp
k8s_workers


The Ansible playbook for Kubernetes setup will be similar to the one in the previous report version, orchestrating kubeadm init on the control plane and kubeadm join on all worker nodes.

5.4 Deploying the NVIDIA GPU Operator for Kubernetes

To expose the vGPU resources to Kubernetes, the NVIDIA GPU Operator must be deployed. The operator automates the management of all necessary NVIDIA software components.7
The operator's device plugin discovers the MIG devices on each worker node and advertises them as schedulable resources. For a heterogeneous cluster with a mix of GPU and non-GPU nodes, the mixed MIG strategy is recommended. This instructs the plugin to inspect each GPU individually and report the MIG devices it finds, while correctly handling nodes with no GPUs.35
Ansible Task for GPU Operator:

YAML


- name: Add NVIDIA Helm repository
  kubernetes.core.helm_repository:
    name: nvidia
    repo_url: "https://helm.ngc.nvidia.com/nvidia"

- name: Deploy NVIDIA GPU Operator
  kubernetes.core.helm:
    name: gpu-operator
    chart_ref: nvidia/gpu-operator
    release_namespace: gpu-operator
    create_namespace: yes
    values:
      mig:
        strategy: "mixed"


The operator's Node Feature Discovery (NFD) component will automatically label the GPU-enabled nodes, and the operator's core components (driver, device plugin) will only be deployed to those nodes.39

5.5 Cluster Verification and GPU Workload Test

After the Ansible playbook completes, verify the cluster state.
1. Verify Nodes:
Check that all nodes have joined and are in the Ready state.

Bash


kubectl get nodes -o wide


2. Verify GPU Resources:
Inspect one of the GPU-enabled worker nodes. The "Allocatable" resources section should now list the discovered MIG device.41

Bash


kubectl describe node k8s-worker-gpu-01


The output should contain a line similar to: nvidia.com/mig-1g.5gb: 1
3. Deploy a Test Pod:
Deploy a simple CUDA pod that explicitly requests a MIG resource to confirm that the Kubernetes scheduler can correctly place the pod on a GPU-enabled node.

Bash


kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mig-device-test
spec:
  restartPolicy: OnFailure
  containers:
  - name: cuda-container
    image: "nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda11.7.1-ubuntu20.04"
    args: ["/bin/sh", "-c", "nvidia-smi"]
    resources:
      limits:
        nvidia.com/mig-1g.5gb: 1
EOF

# Wait for the pod to complete and check logs
kubectl logs mig-device-test


The logs should show the nvidia-smi output for the single MIG device, confirming the 'Pharos' hybrid cloud is fully operational.

Section 6: Deploying the Unified MLOps and Storage Fabric with Ansible and Helm

With the 'Pharos' Kubernetes cluster operational, we now deploy the core MLOps and storage services. This section details the automated deployment of MinIO, PostgreSQL, MLflow, and Kubeflow using Ansible to orchestrate Helm chart installations. These services, hosted on the Kubernetes cluster, will function as a centralized "hub" for the entire MLOps lifecycle, serving both the cloud-native environment and the external HPC cluster.1 To optimize resource usage, these management plane services will be scheduled onto the CPU-only worker nodes.

6.1 Using the Ansible Helm Module

Ansible's kubernetes.core.helm module provides a declarative and idempotent way to manage Helm chart releases, making it the ideal tool for deploying our MLOps stack.42 We can define the desired state of each application within an Ansible playbook.

6.2 Deploying MinIO, PostgreSQL, and MLflow

The Ansible tasks for deploying MinIO, PostgreSQL, and MLflow are similar to the previous report version. However, to ensure they run on the CPU-only worker nodes, we will add a nodeSelector to their Helm chart values. First, label the CPU worker node:

Bash


kubectl label node k8s-worker-cpu-01 compute=cpu


Then, add the nodeSelector to the values section of each Ansible Helm task:
Ansible Task for MinIO (with nodeSelector):

YAML


- name: Deploy MinIO using Helm
  kubernetes.core.helm:
    name: minio
    chart_ref: minio/minio
    #... other parameters
    values:
      mode: standalone
      #... other values
      nodeSelector:
        compute: cpu


This same nodeSelector block should be added to the Helm deployment tasks for PostgreSQL and MLflow to ensure they are scheduled away from the GPU-enabled nodes.

6.3 Deploying Kubeflow via Kustomize

The Kubeflow installation via kustomize can also be executed from within an Ansible playbook. Many Kubeflow control plane components are not GPU-intensive and can be scheduled on CPU nodes using similar affinity rules if required.

6.4 Configuring DVC for Use with the MinIO Endpoint

The DVC configuration remains unchanged, pointing to the NodePort service of the MinIO deployment, which is now running on a dedicated CPU node within the Pharos cloud.

Section 7: End-to-End Orchestration with Oumi

This final section validates the entire emulated system by demonstrating a complete, end-to-end MLOps lifecycle orchestrated by Oumi.1 As the top-level orchestrator, Oumi abstracts the underlying infrastructure, allowing users to seamlessly transition from training on the HPC cluster to deploying on the hybrid Kubernetes cloud.43 The workflow will use Oumi to submit a GPU training job to SLURM, and after model promotion, use Oumi again to deploy a GPU-accelerated inference service to Kubernetes.

7.1 Oumi as the Unified Orchestrator

Oumi serves as the primary interface for data scientists, using version-controlled YAML "recipes" to declaratively define the entire workflow.1 Its launcher system is designed to run jobs across different platforms.43 By configuring Oumi's launcher, a simple
oumi launch command can be directed to the appropriate backend—SLURM for training or Kubernetes for inference.

7.2 Training Workflow on SLURM via oumi launch

The training workflow remains the same as the previous report version. An Oumi recipe defines the training job, which is submitted via oumi launch --launcher slurm. Oumi translates this into a SLURM batch job, which is scheduled on one of the four HPC compute nodes, utilizing its assigned vGPU. All results are logged to the central MLflow server running on the Pharos cloud.

7.3 Model Promotion in the MLflow Model Registry

Once training is complete, the model artifact appears in the MLflow UI. An MLOps engineer reviews the model's performance and promotes it through the Model Registry stages (e.g., to "Production"), signaling that it is validated and ready for deployment.

7.4 GPU-Based Inference Deployment to Kubernetes via Oumi

With the model promoted, the final step is to deploy it as a GPU-accelerated inference service on the Pharos hybrid cloud, orchestrated by Oumi. KServe is capable of deploying models that leverage either CPU or GPU resources, making it ideal for this hybrid environment.45
1. Define the Inference Recipe (inference_recipe.yaml):
This recipe specifies the model to be deployed (pulling the "Production" version from MLflow) and the deployment target. Crucially, it will now be configured to generate a KServe InferenceService manifest that requests a GPU resource.

YAML


# inference_recipe.yaml
model:
  name: "models:/llama-finetuned/Production"
inference_engine:
  type: "vllm"
deployment:
  platform: "kubernetes"
  resources:
    limits:
      nvidia.com/mig-1g.5gb: 1


2. Launch the Inference Service:
The MLOps engineer uses oumi launch again, this time targeting the Kubernetes launcher profile.

Bash


oumi launch up --config inference_recipe.yaml --launcher kubernetes


Oumi connects to the Pharos Kubernetes cluster and applies the KServe manifest. The Kubernetes scheduler, aware of the GPU resources via the NVIDIA GPU Operator, will schedule the inference pod onto one of the three k8s-worker-gpu nodes that can satisfy the nvidia.com/mig-1g.5gb: 1 resource limit.
3. Test the Deployed Endpoint:
Once the KServe service is READY, a prediction request can be sent to its endpoint. A successful response confirms that the model trained on the dedicated GPU cluster has been seamlessly deployed and is serving predictions on a GPU slice within the hybrid Kubernetes cluster, completing the full MLOps lifecycle.

Conclusion: A Blueprint Realized through Automation

The comprehensive emulation detailed in this report successfully translates the ambitious architectural principles of the "AI Hyperscaler Blueprint" into a tangible, functional, and highly automated single-machine prototype. By leveraging a modern toolchain—Packer for image creation, Ansible for configuration management, and Oumi for end-to-end orchestration—this guide demonstrates how to construct a high-fidelity, dual-stack environment that mirrors the separation of concerns found in production-scale AI platforms.
The realized system effectively implements the core tenets of the design document with enhanced efficiency and reproducibility:
Purpose-Built Infrastructure: Two distinct, logically isolated environments were created. The SLURM-based HPC cluster provides a dedicated, multi-node GPU environment optimized for training. Concurrently, the Kubernetes-based 'Pharos' cloud offers a robust, hybrid platform supporting both CPU-only MLOps management services and high-performance, GPU-accelerated inference endpoints. This directly emulates the blueprint's strategy of providing specialized hardware stacks for different stages of the ML lifecycle.1
Automated and Idempotent Deployment: The introduction of Packer and Ansible transforms the infrastructure setup from a manual, error-prone process into a declarative, version-controllable, and repeatable workflow. This "Infrastructure as Code" approach is critical for maintaining consistency across complex, hybrid environments.
Unified Orchestration: Oumi serves as the single pane of glass for the entire MLOps lifecycle. By abstracting the underlying SLURM and Kubernetes clusters, it provides a simplified and consistent user experience for both data scientists and MLOps engineers, from submitting a GPU training job to deploying a GPU inference service.1
This emulated environment serves as a powerful tool for developing, testing, and validating automation for complex AI platforms without the cost of physical hardware. By successfully miniaturizing and automating a hybrid hyperscale architecture, this guide provides a concrete and actionable blueprint for understanding, building, and innovating upon the next generation of infrastructure for artificial intelligence.
Works cited
accessed January 1, 1970,
Virtual GPU Software User Guide - NVIDIA Docs, accessed July 29, 2025, https://docs.nvidia.com/vgpu/latest/grid-vgpu-user-guide/index.html
Linux with KVM - NVIDIA Docs, accessed July 29, 2025, https://docs.nvidia.com/vgpu/15.0/grid-vgpu-release-notes-generic-linux-kvm/index.html
SLES 15 SP5 | NVIDIA Virtual GPU for KVM Guests, accessed July 29, 2025, https://documentation.suse.com/sles/15-SP5/html/SLES-all/article-nvidia-vgpu.html
Remote s3 cache storage with minio - Questions - Community Forum - DVC, accessed July 29, 2025, https://discuss.dvc.org/t/remote-s3-cache-storage-with-minio/1472
How to Install Kubernetes Cluster on Debian 12 | 11 - LinuxTechi, accessed July 29, 2025, https://www.linuxtechi.com/install-kubernetes-cluster-on-debian/
The NVIDIA GPU Operator real-word guide for Kubernetes AI - Spectro Cloud, accessed July 29, 2025, https://www.spectrocloud.com/blog/the-real-world-guide-to-the-nvidia-gpu-operator-for-kubernetes-ai
NVIDIA Virtual GPU (vGPU) Software, accessed July 29, 2025, https://docs.nvidia.com/vgpu/index.html
ome/minio-helm-chart - GitHub, accessed July 29, 2025, https://github.com/ome/minio-helm-chart
Generic Resource (GRES) Scheduling - Slurm Workload Manager - SchedMD, accessed July 29, 2025, https://slurm.schedmd.com/gres.html
Installation | Kubeflow, accessed July 29, 2025, https://www.kubeflow.org/docs/components/pipelines/operator-guides/installation/
Unattended Debian/Ubuntu Installation | Packer - HashiCorp Developer, accessed July 29, 2025, https://developer.hashicorp.com/packer/guides/automatic-operating-system-installs/preseed_ubuntu
Building Custom Debian Images with Packer and Ansible - Trie of Logs, accessed July 29, 2025, https://blog.trieoflogs.com/2023-10-18-custom-debian-image/
QEMU Builder | Integrations | Packer - HashiCorp Developer, accessed July 29, 2025, https://developer.hashicorp.com/packer/integrations/hashicorp/qemu/latest/components/builder/qemu
Creating a VM Debian 12 Image for arm64 architecture targeting QEMU & Vagrant usage with QEMU and Packer on MacOS - jmanteau, accessed July 29, 2025, https://jmanteau.fr/posts/unattended-installation-of-debian-mac-arm64/
KVM in Terraform - Dan's Tech Journey, accessed July 29, 2025, https://danstechjourney.com/posts/kvm-terraform/
Terraform with libvirt: Creating a single node Rancher - Jamie Phillips, accessed July 29, 2025, https://www.phillipsj.net/posts/terraform-with-libvirt-creating-a-single-node-rancher/
ELI5: State and locks : r/Terraform - Reddit, accessed July 29, 2025, https://www.reddit.com/r/Terraform/comments/19egqce/eli5_state_and_locks/
Terraform Realtime Questions. 1) What happens if your state file is… | by Ashish Kumar Vishwakarma | Jun, 2025 | Medium, accessed July 29, 2025, https://medium.com/@ashish.mnnit777/terraform-realtime-questions-f4e06fa1821b
Lessons learned after losing the Terraform state file - Trying things, accessed July 29, 2025, https://tryingthings.wordpress.com/2021/03/31/lessons-learned-after-losing-the-terraform-state-file/
Terraform State File Best Practices | by Mike Tyson of the Cloud (MToC) | Medium, accessed July 29, 2025, https://medium.com/@mike_tyson_cloud/terraform-state-file-best-practices-f801c01e1cc2
The complete guide to Terraform state management - Firefly, accessed July 29, 2025, https://www.firefly.ai/academy/the-complete-guide-to-terraform-state-management
Manage Terraform Remote State Using Remote Backend | Tutorial - Env0, accessed July 29, 2025, https://www.env0.com/blog/terraform-remote-state-using-a-remote-backend
Vagrant with libvirt provider - Fedora Developer Portal, accessed July 29, 2025, https://developer.fedoraproject.org/tools/vagrant/vagrant-libvirt.html
README – Documentation for vagrant-libvirt (0.0.28) - RubyDoc.info, accessed July 29, 2025, https://www.rubydoc.info/gems/vagrant-libvirt/0.0.28
Quickstart - Vagrant Libvirt Documentation - GitHub Pages, accessed July 29, 2025, https://vagrant-libvirt.github.io/vagrant-libvirt/
Institut Français de Bioinformatique / Ansible Roles / ansible-slurm - GitLab, accessed July 29, 2025, https://gitlab.com/ifb-elixirfr/ansible-roles/ansible-slurm/-/tree/master
name: start and enable slurmctld service, accessed July 29, 2025, https://slurm.schedmd.com/SLUG16/slug2016_johan_guldmyr.pdf
scicore-unibas-ch/ansible-role-slurm: Configure a slurm cluster - GitHub, accessed July 29, 2025, https://github.com/scicore-unibas-ch/ansible-role-slurm
Slurm configuration - System technical documentation for Niflheim, accessed July 29, 2025, https://niflheim-system.readthedocs.io/en/latest/Slurm_configuration.html
slurm-gpu/README.md at master - GitHub, accessed July 29, 2025, https://github.com/dholt/slurm-gpu/blob/master/README.md
How to Manage Kubernetes with Ansible [Tutorial] - Spacelift, accessed July 29, 2025, https://spacelift.io/blog/ansible-kubernetes
geerlingguy/ansible-role-kubernetes - GitHub, accessed July 29, 2025, https://github.com/geerlingguy/ansible-role-kubernetes
Ansible Playbook for Kubernetes cluster installation on Linux : r/linuxadmin - Reddit, accessed July 29, 2025, https://www.reddit.com/r/linuxadmin/comments/1fxnnxm/ansible_playbook_for_kubernetes_cluster/
GPU Operator with MIG - NVIDIA Docs Hub, accessed July 29, 2025, https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-operator-mig.html
Implementing NVIDIA MIG in Red Hat OpenShift to optimize GPU resources in containerized environments - IBM Developer, accessed July 29, 2025, https://developer.ibm.com/articles/implementing-nvidia-mig-openshift/
Boost GPU efficiency in Kubernetes with NVIDIA Multi-Instance GPU | Red Hat Developer, accessed July 29, 2025, https://developers.redhat.com/articles/2025/05/27/boost-gpu-efficiency-kubernetes-nvidia-mig
Maximizing GPU utilization with NVIDIA's Multi-Instance GPU (MIG) on Amazon EKS: Running more pods per GPU for enhanced performance | Containers, accessed July 29, 2025, https://aws.amazon.com/blogs/containers/maximizing-gpu-utilization-with-nvidias-multi-instance-gpu-mig-on-amazon-eks-running-more-pods-per-gpu-for-enhanced-performance/
Installing the NVIDIA GPU Operator, accessed July 29, 2025, https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html
Getting Started — NVIDIA GPU Operator 23.9.0 documentation, accessed July 29, 2025, https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/23.9.0/getting-started.html
MIG Support in Kubernetes - NVIDIA Docs Hub, accessed July 29, 2025, https://docs.nvidia.com/datacenter/cloud-native/kubernetes/latest/index.html
kubernetes.core.helm module – Manages Kubernetes packages with the Helm package manager — Ansible Community Documentation, accessed July 29, 2025, https://docs.ansible.com/ansible/latest/collections/kubernetes/core/helm_module.html
Core Concepts - Oumi AI, accessed July 29, 2025, https://oumi.ai/docs/en/latest/get_started/core_concepts.html
Changelog - Oumi AI, accessed July 29, 2025, https://oumi.ai/docs/en/latest/about/changelog.html
Empower conversational AI at scale with KServe | Red Hat Developer, accessed July 29, 2025, https://developers.redhat.com/articles/2024/03/15/empower-conversational-ai-scale-kserve
KServe — RAPIDS Deployment Documentation documentation, accessed July 29, 2025, https://docs.rapids.ai/deployment/stable/platforms/kserve/
kserve/kserve: Standardized Serverless ML Inference Platform on Kubernetes - GitHub, accessed July 29, 2025, https://github.com/kserve/kserve
Inference Autoscaling - KServe Documentation Website, accessed July 29, 2025, https://kserve.github.io/website/0.10/modelserving/autoscaling/autoscaling/

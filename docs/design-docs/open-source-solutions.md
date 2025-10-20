
An Analysis of Open-Source Implementations for Hybrid HPC and Cloud-Native AI Infrastructure


Introduction

The design document, "The Hyperscaler on a Workstation: An Automated Approach to Emulating an Advanced AI Infrastructure," presents a comprehensive and meticulously architected blueprint for emulating a modern, dual-stack AI platform on a single physical machine.1 The document's strength lies in its prescriptive detail, providing a clear, reproducible path for creating a sophisticated development and testing environment.
The objective of this report is to identify and analyze existing open-source repositories that align with the core principles of this design. The analysis will explore projects that offer fully integrated solutions, composable frameworks that provide the necessary building blocks, and alternative architectural paradigms that challenge the design's foundational assumptions. This report will provide a comparative framework to evaluate architectural trade-offs, identify the closest existing analogues, and explore alternative paradigms, ultimately informing future development or adoption strategies for such an environment.

Section 1: Deconstruction of the "Hyperscaler on a Workstation" Blueprint

To establish a baseline for comparison, it is essential to first deconstruct the core architectural pillars of the "Hyperscaler on a Workstation" blueprint. This design is not merely an abstract concept but a detailed, implementation-ready guide.

Pillar 1: The Automated Local Virtualization Fabric

The foundation of the entire emulation is a robust, automated virtualization layer built on standard, powerful open-source tools.1
Core Components: The design specifies a host machine running Debian 12 "Bookworm," chosen for its stability and modern kernel features. This host must have hardware virtualization extensions (Intel VT-x/AMD-V) and, critically, IOMMU support (Intel VT-d/AMD-Vi) enabled in the BIOS/UEFI.1 The IOMMU is non-negotiable as it provides the underlying mechanism for the hypervisor to grant virtual machines exclusive access to physical hardware, a prerequisite for GPU passthrough. The virtualization stack itself is comprised of the Kernel-based Virtual Machine (KVM), a Type-1 hypervisor integrated directly into the Linux kernel, paired with QEMU for hardware emulation and the
libvirt toolkit for high-level management.1
GPU Driver Criticality: The document correctly emphasizes that standard NVIDIA datacenter drivers are insufficient for this architecture. The specific NVIDIA vGPU software package is mandatory.1 This distinction is crucial because this package includes the
vGPU Manager, a component that installs specialized kernel modules. These modules create the necessary interfaces within the Linux sysfs filesystem to expose "mediated devices" (mdevs). Without the vGPU Manager, the host kernel has no mechanism to create these virtual GPU objects, making it impossible for libvirt and KVM to partition and assign GPU slices to guest VMs.1 This technical nuance is a frequent point of failure in similar setups and its explicit mention highlights the design's depth.
Automation Toolchain: A sophisticated, multi-layered automation strategy ensures reproducibility and minimizes manual configuration.
Packer: HashiCorp Packer is used to build a "golden image" of Debian 12. By using an unattended installation file (preseed.cfg), Packer automates the creation of a standardized QEMU qcow2 image that serves as the base for all virtual machines, embodying the principles of immutable infrastructure.1
Declarative Provisioning: The blueprint presents three alternative yet philosophically aligned Infrastructure-as-Code (IaC) methods for provisioning VMs from the golden image. This includes direct libvirt XML definitions, HashiCorp Terraform using the community dmacvicar/libvirt provider 3, and Vagrant with the
vagrant-libvirt plugin.1 This demonstrates flexibility while strictly adhering to IaC best practices. The inclusion of a detailed, practical warning about the dangers of losing a local Terraform state file and a step-by-step recovery guide using
terraform import underscores a focus on operational robustness that is often born from real-world experience with such failures.1 This level of operational detail suggests the design has been tested beyond simple initial deployment.
Configuration Management: Ansible is the designated tool for all post-provisioning configuration. It is responsible for installing and configuring software stacks like SLURM and Kubernetes within the VMs, managing service states, and templating configuration files to ensure consistency across the clusters.1

Pillar 2: Granular GPU Resource Partitioning via MIG and mdev

The design's method for partitioning the physical NVIDIA A100 GPU demonstrates a "first principles" understanding of the Linux virtualization stack, deliberately choosing low-level control over potentially simpler, higher-level abstractions.
MIG Enablement: The process begins by programmatically enabling Multi-Instance GPU (MIG) mode on the A100 using the nvidia-smi command-line utility. This is a system-level change that reconfigures the GPU to allow for secure, hardware-level partitioning.1
Two-Stage Abstraction: The blueprint masterfully separates the process of making a GPU slice available to a VM into two distinct, necessary stages:
Hardware Partitioning (GPU Instances): The nvidia-smi mig -cgi command is used to create seven distinct 1g.5gb GPU Instances (GIs). Each GI is a true hardware partition with its own dedicated compute engines, memory, and cache, ensuring performance isolation.1
Hypervisor Virtual Device Creation (mdevs): For each hardware GI, a corresponding mediated device (mdev) is created. This is accomplished by writing a unique UUID to a specific path within the sysfs filesystem (e.g., /sys/bus/pci/devices/.../mdev_supported_types/.../create). This mdev is the critical kernel object that libvirt can recognize, manage, and attach as a device to a KVM guest VM.1 This explicit two-step process reveals a deep comprehension of the interaction between NVIDIA's proprietary tools and the standard Linux kernel virtualization frameworks.
Strategic Allocation: The seven resulting virtual GPUs are then methodically allocated between the two clusters according to a clear plan: four vGPUs are reserved for the SLURM HPC compute nodes, and three are assigned to the Kubernetes GPU worker nodes.1

Pillar 3: The Dual-Stack Scheduling Paradigm

The design achieves a true hybrid environment by creating two logically and operationally distinct clusters, each tailored for a specific purpose in the MLOps lifecycle.
Network Isolation: A foundational element of the dual-stack design is strict network separation. This is achieved by creating two distinct libvirt virtual network bridges, hpc-net (192.168.100.0/24) and ai-how-net (192.168.200.0/24). This creates two separate Layer 2 broadcast domains, preventing network interference and allowing for independent IP addressing and network policies, thereby emulating the logical separation of production HPC and cloud networks.1
Purpose-Built Clusters:
HPC (SLURM): A traditional High-Performance Computing cluster is deployed for large-scale model training. It consists of one controller and four GPU-enabled compute nodes. The entire deployment is automated by an Ansible playbook that installs SLURM and the MUNGE authentication service. Crucially, it uses Ansible's template module to dynamically generate GPU-aware SLURM configuration files like gres.conf and cgroup.conf, ensuring that GPU resources are correctly scheduled and isolated per job.1
Cloud (Kubernetes): A modern, heterogeneous Kubernetes cluster is deployed to host the MLOps control plane and inference services. This cluster includes a control plane node, a CPU-only worker node, and three GPU-enabled worker nodes. To make the partitioned MIG resources available to Kubernetes, the NVIDIA GPU Operator is deployed via a Helm chart. The design correctly specifies the use of the "mixed" MIG strategy for the operator, which is the appropriate choice for a heterogeneous cluster containing both GPU and non-GPU nodes, allowing the operator to correctly label and manage resources on each node type.1

Pillar 4: The Unified Orchestration Abstraction (Oumi)

The architecture culminates in a unified orchestration layer, "Oumi," which provides a single pane of glass for the entire MLOps workflow, abstracting the complexity of the underlying dual-stack infrastructure.
Launcher-Based Execution: Oumi utilizes a "launcher" system where users define complex jobs in version-controlled YAML "recipes".1 A simple command,
oumi launch, augmented with a launcher-specific flag (e.g., --launcher slurm or --launcher kubernetes), directs the job to the appropriate backend cluster without requiring the user to interact with sbatch or kubectl directly.1
End-to-End Workflow Validation: The design validates this concept by detailing a complete MLOps lifecycle:
A training job is submitted to the SLURM cluster using oumi launch.
The resulting model is tracked and promoted to "Production" in a central MLflow registry.
A KServe inference service is then deployed to the Kubernetes cluster using oumi launch, with the recipe requesting a specific MIG resource (nvidia.com/mig-1g.5gb: 1). The Kubernetes scheduler, informed by the NVIDIA GPU Operator, correctly places this workload on one of the GPU-enabled worker nodes.1 This seamless transition from a SLURM-based training environment to a Kubernetes-based inference environment via a single tool is the capstone of the design.

Section 2: Analysis of Integrated, "Batteries-Included" Platforms

This section evaluates monolithic, open-source projects that, like the user's design, aim to provide a complete, end-to-end solution for deploying GPU-accelerated clusters. These projects offer a "batteries-included" experience, contrasting with more modular approaches.

2.1. Deep Dive: NVIDIA DeepOps

NVIDIA's DeepOps project is arguably the most functionally complete and philosophically aligned public repository to the "Hyperscaler on a Workstation" design.
Project Philosophy and Scope: DeepOps is an open-source NVIDIA project that "encapsulates best practices in the deployment of GPU server clusters and sharing single powerful nodes" like NVIDIA DGX Systems.7 Its primary focus is the automated setup of on-premise, bare-metal clusters, but it is explicitly designed to be modular and adaptable for various use cases, from deploying KubeFlow on an existing cluster to setting up a single machine with only NVIDIA drivers.7
Architectural Alignment and Deviations: DeepOps shows remarkable alignment with the user's blueprint in its core technologies and goals.
Automation: The entire framework is built on Ansible, using playbooks to orchestrate complex deployments.7
Dual-Stack Support: DeepOps provides distinct, well-documented Ansible playbooks for deploying both Kubernetes (via the Kubespray project) and SLURM (using packages from SchedMD).7 This directly mirrors the dual-stack nature of the user's design.
GPU and MIG Focus: The project is purpose-built for GPU-accelerated environments. Its documentation and associated NVIDIA developer blogs confirm robust support for deploying Kubernetes with Multi-Instance GPU (MIG), even recommending the flexible "mixed" strategy for heterogeneous node types.11 The SLURM deployment guide also explicitly references MIG configuration documentation.10
Single-Machine Emulation: Most critically, DeepOps provides a virtual/ deployment path that uses Vagrant and KVM/libvirt to create a virtual cluster on a single host machine.13 This mode is specifically intended for learning, testing, and local development, which directly matches the user's "workstation" concept. The virtual deployment guide details the process of enabling GPU passthrough via VFIO to the guest VMs, allowing for a high-fidelity emulation of a physical GPU cluster.13
The primary point of divergence is that DeepOps officially does not test or support deploying both Kubernetes and SLURM on the same set of cluster nodes simultaneously, recommending NVIDIA Bright Cluster Manager for such hybrid scenarios.7 The user's design cleverly circumvents this limitation by using virtual machines as the fundamental unit of isolation, effectively creating two distinct virtual clusters that coexist on one physical machine. This highlights a key architectural innovation in the user's blueprint for achieving a true hybrid environment on a single host, a configuration that production-focused tools like DeepOps avoid due to the complexities of resource contention on bare metal.

2.2. Deep Dive: The StackHPC Slurm Appliance

The ansible-slurm-appliance from StackHPC represents another highly automated, production-ready framework, but with a singular focus on High-Performance Computing.
Project Philosophy and Scope: This project is designed to deploy a "fully functional and production ready HPC workload management environment" based entirely on SLURM.14 It is a comprehensive, IaC-driven solution for standing up a complete HPC software and management stack.
Architectural Alignment and Deviations: The appliance shares a similar modern toolchain with the user's design, leveraging Ansible for configuration management, Packer for creating node images, and OpenTofu (a fork of Terraform) for infrastructure provisioning.14 Its SLURM deployment is more comprehensive than the user's, including OpenHPC software packages, options for NFS or CephFS shared storage, MySQL for accounting, and an integrated monitoring stack with Prometheus and Grafana.14
However, the appliance deviates significantly from the user's design in its core architectural goals:
* No Native Kubernetes Support: The project is exclusively focused on SLURM. It does not contain any components for deploying a parallel Kubernetes cluster, meaning it does not embody the hybrid, dual-stack paradigm that is central to the user's blueprint.14

* Primary Target is OpenStack: While adaptable, the documentation and default OpenTofu configurations are heavily geared towards deployment on OpenStack infrastructure. They make frequent reference to OpenStack-specific resources like volumes, keypairs, and security groups.14 Adapting it for a local KVM deployment is possible but would require significant customization of the provisioning code and is not a documented or officially supported use case.
In essence, the StackHPC appliance is an excellent reference for a production-grade, "pure HPC" deployment. It serves as a strong counterpoint to the user's hybrid-native design, showcasing what a dedicated, non-hybrid IaC solution for SLURM looks like.

Section 3: Analysis of Composable Frameworks and Alternative Architectures

Beyond monolithic platforms, the open-source ecosystem provides a rich set of modular components that can be assembled to construct a similar environment. This section also explores alternative architectural patterns that challenge the core dual-stack assumption of the user's design.

3.1. Infrastructure-as-Code for Local KVM Clusters (The Composable Path)

This approach forgoes a single, integrated project in favor of assembling the desired environment from a collection of specialized, best-of-breed tools. This path offers maximum flexibility and transparency at the cost of increased integration effort. The ecosystem is largely fragmented between tools that handle infrastructure provisioning (creating VMs) and those that handle application configuration (installing software on the VMs).
Ansible-based KVM + Kubernetes: Several projects focus on using Ansible to configure Kubernetes on pre-existing nodes. techno-tim/k3s-ansible is a popular, well-maintained example for bootstrapping a high-availability K3s cluster.16 However, it does not provision the underlying VMs. A rare exception is
redhat-nfvpe/kube-ansible, which provides playbooks to both instantiate KVM virtual machines and then install a vanilla Kubernetes cluster on them.17 It is a strong example of an end-to-end Ansible workflow for a single stack, but it is CentOS-focused and lacks built-in support for SLURM or advanced GPU features like MIG.
Terraform-based KVM Provisioning: The foundational tool for this approach is the dmacvicar/terraform-provider-libvirt, which provides the core Terraform resources (libvirt_domain, libvirt_volume) needed to interact with a KVM hypervisor.3 Building on this, projects like
MonolithProjects/terraform-libvirt-vm offer reusable Terraform modules to simplify the creation of VM clusters.18 To create a full lab, repositories like
jamonation/terraform-libvirt-k8s-lab combine Terraform for VM provisioning with Ansible for the subsequent Kubernetes configuration, demonstrating a complete, composable workflow.19
Composable SLURM Roles: The Ansible ecosystem contains numerous high-quality, modular roles dedicated solely to deploying SLURM. Examples include galaxyproject.slurm 20,
mila.slurm 21, and
fgci-org/ansible-role-slurm.22
A fully composable implementation of the user's design would involve using Terraform to provision all VMs and then orchestrating a series of these specialized Ansible roles to configure the SLURM and Kubernetes stacks. The primary challenge in this approach is the integration: creating a unified inventory, managing shared variables, and ensuring a cohesive deployment sequence, which is the non-trivial work that integrated projects like the user's design and DeepOps have already done.

3.2. The "HPC-on-Kubernetes" Paradigm (The Consolidation Path)

This architecture presents a fundamental challenge to the user's dual-stack design. Instead of maintaining two separate schedulers for different workload types, it proposes consolidating all tasks, including batch HPC and AI training, onto a single, enhanced Kubernetes cluster. This approach trades the "purpose-built" nature of SLURM for the operational simplicity of a unified, cloud-native control plane.
The leading open-source project in this space is volcano-sh/volcano.4 As a CNCF-hosted project, Volcano is a "Kubernetes-native batch scheduling system" that extends the default Kubernetes scheduler with features essential for HPC and AI workloads that are historically lacking in Kubernetes.4 These features include gang-scheduling (ensuring all pods for a job start simultaneously), job queueing, fair-share scheduling, and other advanced policies that are standard in traditional batch systems like SLURM.
Adopting this paradigm would represent a significant architectural shift. The entire SLURM cluster from the user's design would be eliminated. Instead, Ansible playbooks would configure a single, larger Kubernetes cluster with the Volcano scheduler installed. This path represents a bet on the convergence of HPC and cloud-native ecosystems, offering the promise of a simpler, unified operational model, but potentially at the cost of some of the mature, highly-tuned scheduling performance of a dedicated SLURM environment. This presents a classic "best-of-breed vs. integrated suite" trade-off.

3.3. The Orchestration Layer: A Closer Look at oumi-ai/oumi

The user's concept of a top-level "Oumi" orchestrator is not fictional; it corresponds to a real, actively developed open-source project.
Project Validation: The oumi-ai/oumi repository is a real platform designed to streamline the entire lifecycle of foundation models, from data preparation to deployment.23 It is important to distinguish this project from other similarly named but unrelated projects, such as
JigsawStack/omiai (a TypeScript AI SDK) 26 or
BasedHardware/omi (an AI wearable device).27
Launcher Architecture and Backend Support: The official Oumi documentation confirms the existence and architecture of the launcher module, which is designed to "launch and manage jobs across various cloud platforms".28 The core concepts of the launcher are
Jobs, Clusters, and Clouds.23 Critically, the API documentation explicitly lists a
SlurmCloud class, described as "A resource pool for managing jobs in Slurm clusters".29 It also lists a
SkyCloud class that uses the SkyPilot framework to run jobs on major cloud providers (AWS, GCP, etc.).29 While a direct
KubernetesCloud class is not explicitly listed in the provided documentation snippets, the architecture is clearly pluggable, with distinct client and cluster implementations for each backend.28 Therefore, the user's proposal to use Oumi as a unified frontend to launch jobs on both SLURM and Kubernetes is highly plausible and directly aligned with the project's documented design and intent.

Section 4: Comparative Synthesis and Architectural Trade-offs

The analysis reveals four distinct approaches to building the target infrastructure: the user's tightly integrated emulation, NVIDIA's production-focused toolkit, a do-it-yourself composable method, and a consolidated cloud-native model. Each carries a unique philosophy and a specific set of practical trade-offs.

4.1. Narrative Comparison: Integrated vs. Composable vs. Consolidated

User's Design ("Integrated Emulation"): This is a highly opinionated, tightly integrated system built from the ground up for a specific purpose: high-fidelity, dual-stack emulation on a single workstation. Its strength is its cohesiveness, prescriptive detail, and innovative use of VM-level isolation to achieve a hybrid cluster on one machine. Its primary goal is the emulation itself.
NVIDIA DeepOps ("Integrated Toolkit"): This is a comprehensive, "batteries-included" toolkit designed for deploying production-scale, bare-metal GPU clusters. It is highly integrated but offers more modularity than the user's design. Its virtual deployment mode is a means to an end (testing and development), not the primary product.
Composable Approach ("DIY/Best-of-Breed"): This involves assembling a solution from individual, specialized Ansible roles and Terraform modules. This path offers maximum flexibility, transparency, and control, but places the entire burden of integration, maintenance, and ensuring interoperability on the end-user.
Consolidated Approach ("Cloud-Native HPC"): This is the Volcano-on-Kubernetes model. It represents a fundamentally different architectural philosophy that prioritizes a single, unified control plane for all workloads, betting on the convergence of HPC and cloud-native technologies.

4.2. Architectural Trade-offs Matrix

The following table synthesizes the analysis by comparing the four architectural patterns across key operational and design dimensions. This provides a structured framework for evaluating which approach best fits a given set of priorities.
Table 1: Architectural Feature Matrix of Alternative Implementations
Feature/Criterion
User's "Hyperscaler" Design
NVIDIA DeepOps
Composable (Best-of-Breed)
Consolidated (Volcano on K8s)
Primary Goal
High-fidelity local emulation
Production bare-metal deployment
Maximum flexibility and control
Unified cloud-native control plane
Core Automation Tech
Packer, Ansible, Terraform/Libvirt
Ansible, Packer, Vagrant
User's choice (e.g., Ansible, Terraform)
User's choice (e.g., Ansible, Helm)
KVM/Virtualization Support
Native, first-class citizen
Supported for testing/dev path
Requires manual integration
Requires manual integration
SLURM Support
Native, integrated via Ansible
Native, integrated via Ansible
Requires separate SLURM role
Not Applicable (Replaced by Volcano)
Kubernetes Support
Native, integrated via Ansible
Native, integrated via Ansible
Requires separate K8s role
Native (Foundation of the stack)
Hybrid Stack (K8s+Slurm) Model
VM-level Isolation
Officially Not Supported
Manual integration required
Consolidated (Single Scheduler)
MIG/vGPU Integration
Prescriptive, manual mdev creation
Supported, abstracted by playbooks
Fully manual configuration
Handled by NVIDIA GPU Operator
Flexibility/Modularity
Low (Tightly integrated)
Medium (Modular playbooks)
High (Independent components)
Medium (K8s-centric)
Integration Complexity
Low (Pre-integrated)
Low (Pre-integrated)
High (User responsible)
Medium (Requires Volcano setup)
Community/Vendor Support
Single User/Creator
NVIDIA / Open-Source Community
Individual Component Maintainers
CNCF / Open-Source Community


Section 5: Strategic Recommendations and Conclusion

The analysis of the open-source landscape reveals several viable paths for implementing an infrastructure similar to the "Hyperscaler on a Workstation." The optimal choice depends entirely on the user's primary goals, whether they be rapid deployment, deep learning and control, or future-proofing the architecture.

5.1. Path 1: The Turnkey Toolkit Approach (For Rapid, Supported Deployment)

Recommendation: Adopt NVIDIA DeepOps.
Rationale: For users whose primary goal is to get a functional, feature-rich, dual-stack environment running with minimal integration effort, DeepOps is the most direct and powerful option.7 It is the closest existing public repository in terms of scope and technology. It has a supported virtual deployment path using Vagrant and KVM, which mirrors the workstation concept, and provides mature, vendor-backed playbooks for setting up both SLURM and Kubernetes in GPU-accelerated environments, including MIG support.10 This path leverages the best practices of a major industry player. The trade-off is a slight loss of fine-grained control and a design philosophy that is ultimately geared towards production bare-metal clusters rather than being "emulation-first."

5.2. Path 2: The Modular Construction Approach (For Maximum Control and Learning)

Recommendation: Assemble the system from best-of-breed composable components.
Rationale: This path is ideal for the user who wishes to retain full control over every component, understand the system from first principles, and avoid the overhead and opinionated nature of a large, integrated project like DeepOps. It involves using Terraform with the dmacvicar/libvirt provider for VM provisioning 3 and then selecting high-quality, independent Ansible roles for SLURM (e.g.,
galaxyproject/slurm 20) and Kubernetes (e.g.,
geerlingguy/ansible-role-kubernetes 30). This approach is, in essence, an implementation of the user's own design but leverages the maintenance and focus of individual component communities. The primary cost is the user's own time and effort to perform the integration.

5.3. Path 3: The Cloud-Native Consolidation Approach (For Future-Proofing and Simplicity)

Recommendation: Explore replacing the SLURM stack with Volcano on Kubernetes.
Rationale: This is the most forward-looking and architecturally divergent path. If the user's interest lies in the dominant trends of the cloud-native ecosystem and they value operational simplicity, consolidating all workloads onto a single Kubernetes control plane is a powerful strategy. This approach leverages Volcano to bring mature batch scheduling capabilities to Kubernetes, eliminating the need to deploy, manage, secure, and learn a completely separate SLURM cluster.4 This significantly simplifies the overall architecture and aligns with the industry's broader move towards unified, container-native platforms. It represents a bet on the convergence of the HPC and cloud-native worlds.

5.4. Conclusion

The "Hyperscaler on a Workstation" design document is a unique and valuable contribution to the field of AI infrastructure emulation. Its novelty lies not in the invention of new components, but in the specific, highly-integrated, and deeply knowledgeable synthesis of existing, powerful open-source technologies—KVM with vGPU, MIG with mdev creation, Packer, Ansible, SLURM, and Kubernetes—all orchestrated by a unified MLOps layer in Oumi.
While comprehensive projects like NVIDIA DeepOps offer a similar end-to-end scope, the user's design is distinct and notable for its "emulation-first" philosophy, its elegant use of VM-level isolation to create a true hybrid cluster on a single host, and its prescriptive, tutorial-like detail that ensures reproducibility. This analysis has provided a map of the existing open-source landscape, situating the user's work within a broader context of integrated toolkits, composable frameworks, and alternative architectural paradigms. This map should empower strategic decisions about whether to adopt an existing framework, contribute to one, or continue to develop this unique and well-architected solution.
Works cited
V1-The Hyperscaler on a Workstation: An Automated Approach to Emulating an Advanced AI Infrastructure
Exploring and Provisioning Infrastructure With Packer - Unfriendly Grinch, accessed August 2, 2025, https://unfriendlygrinch.info/posts/exploring-and-provisioning-infra-with-packer/
Terraform provider to provision infrastructure with Linux's KVM using libvirt - GitHub, accessed August 2, 2025, https://github.com/dmacvicar/terraform-provider-libvirt
volcano-sh/volcano: A Cloud Native Batch System (Project under CNCF) - GitHub, accessed August 2, 2025, https://github.com/volcano-sh/volcano
A collection of Awesome HPC software and tools - GitHub, accessed August 2, 2025, https://github.com/dstdev/awesome-hpc
Ansible role for installing Kubernetes Controller Cluster - GitHub, accessed August 2, 2025, https://github.com/githubixx/ansible-role-kubernetes-controller
NVIDIA/deepops: Tools for building GPU clusters - GitHub, accessed August 2, 2025, https://github.com/NVIDIA/deepops
Deploying Rich Cluster API on DGX for Multi-User Sharing | NVIDIA Technical Blog, accessed August 2, 2025, https://developer.nvidia.com/blog/deploying-rich-cluster-api-on-dgx-for-multi-user-sharing/
[Literature Review] DeepOps & SLURM: Your GPU Cluster Guide, accessed August 2, 2025, https://www.themoonlight.io/en/review/deepops-slurm-your-gpu-cluster-guide
deepops/docs/slurm-cluster/README.md at master - GitHub, accessed August 2, 2025, https://github.com/NVIDIA/deepops/blob/master/docs/slurm-cluster/README.md
Deploying NVIDIA Triton at Scale with MIG and Kubernetes, accessed August 2, 2025, https://developer.nvidia.com/blog/deploying-nvidia-triton-at-scale-with-mig-and-kubernetes/
Getting Kubernetes Ready for the NVIDIA A100 GPU with Multi-Instance GPU, accessed August 2, 2025, https://developer.nvidia.com/blog/getting-kubernetes-ready-for-the-a100-gpu-with-multi-instance-gpu/
deepops/virtual/README.md at master - GitHub, accessed August 2, 2025, https://github.com/NVIDIA/deepops/blob/master/virtual/README.md
stackhpc/ansible-slurm-appliance: A Slurm-based HPC ... - GitHub, accessed August 2, 2025, https://github.com/stackhpc/ansible-slurm-appliance
An Ansible-driven Slurm "Appliance" for an HPC Environment - StackHPC, accessed August 2, 2025, https://stackhpc.com/slurm-app.html
techno-tim/k3s-ansible: The easiest way to bootstrap a self-hosted High Availability Kubernetes cluster. A fully automated HA k3s etcd install with kube-vip, MetalLB, and more. Build. Destroy. Repeat. - GitHub, accessed August 2, 2025, https://github.com/techno-tim/k3s-ansible
redhat-nfvpe/kube-ansible: Spin up a Kubernetes ... - GitHub, accessed August 2, 2025, https://github.com/redhat-nfvpe/kube-ansible
MonolithProjects/terraform-libvirt-vm: Terraform module for KVM/Libvirt Virtual Machine., accessed August 2, 2025, https://github.com/MonolithProjects/terraform-libvirt-vm
jamonation/terraform-libvirt-k8s-lab: A project to build nodes for a Kubernetes cluster using Terraform and the libvirt provider, and set up and configure Kubernetes on them using Ansible - GitHub, accessed August 2, 2025, https://github.com/jamonation/terraform-libvirt-k8s-lab
galaxyproject/ansible-slurm: Ansible role for installing and managing the Slurm Workload Manager - GitHub, accessed August 2, 2025, https://github.com/galaxyproject/ansible-slurm
mila.slurm - Ansible Galaxy, accessed August 2, 2025, https://galaxy.ansible.com/ui/standalone/roles/mila/slurm/
fgci-org/ansible-role-slurm: For installing and configuring SLURM - Simple Linux Utility for Resource Management - GitHub, accessed August 2, 2025, https://github.com/fgci-org/ansible-role-slurm
oumi/notebooks/Oumi - Running Jobs Remotely.ipynb at main - GitHub, accessed August 2, 2025, https://github.com/oumi-ai/oumi/blob/main/notebooks/Oumi%20-%20Running%20Jobs%20Remotely.ipynb
Oumi AI, accessed August 2, 2025, https://oumi.ai/
oumi/docs/get_started/core_concepts.md at main - GitHub, accessed August 2, 2025, https://github.com/oumi-ai/oumi/blob/main/docs/get_started/core_concepts.md?plain=1
JigsawStack/omiai: OmiAI is an opinionated AI SDK for Typescript that auto-picks the best model from a suite of curated models depending on the prompt. It includes built-in o3-like reasoning, curated tools, internet access and full multi-modal support with almost all media types - GitHub, accessed August 2, 2025, https://github.com/JigsawStack/omiai
BasedHardware/omi: AI wearables. Put it on, speak, transcribe, automatically - GitHub, accessed August 2, 2025, https://github.com/BasedHardware/omi
oumi.launcher, accessed August 2, 2025, https://oumi.ai/docs/en/latest/api/oumi.launcher.html
oumi.launcher.clouds, accessed August 2, 2025, https://oumi.ai/docs/en/latest/api/oumi.launcher.clouds.html
geerlingguy/ansible-role-kubernetes - GitHub, accessed August 2, 2025, https://github.com/geerlingguy/ansible-role-kubernetes

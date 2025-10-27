# Cloud Cluster Resource Requirements

**Last Updated:** 2025-10-27

## Overview

This document outlines the hardware, software, and network requirements for deploying the cloud cluster for Oumi
model inference.

---

## Hardware Requirements

### Minimum Configuration

**Host Machine:**

- **CPU:** 16 cores (Intel/AMD x86_64 with virtualization support)
- **RAM:** 64 GB
- **Storage:** 800 GB available disk space
- **GPUs:** 2x NVIDIA GPUs (compute capability 7.0+)
- **Network:** Gigabit Ethernet (1 Gbps)

**Notes:**

- Enables basic cloud cluster deployment
- Suitable for development and testing
- May require running HPC and cloud clusters sequentially

### Recommended Configuration

**Host Machine:**

- **CPU:** 24+ cores (Intel Xeon or AMD EPYC preferred)
- **RAM:** 128 GB
- **Storage:** 1.5 TB NVMe SSD
- **GPUs:** 2-4x NVIDIA GPUs (RTX A6000, Tesla T4, or better)
- **Network:** 10 Gigabit Ethernet

**Benefits:**

- Sufficient resources for both HPC and cloud clusters simultaneously
- Better performance for inference workloads
- Improved I/O for model storage and transfer

### Production Configuration

**Host Machine:**

- **CPU:** 32+ cores
- **RAM:** 256 GB
- **Storage:** 2+ TB NVMe SSD
- **GPUs:** 4-8x NVIDIA GPUs (A100, H100 for optimal performance)
- **Network:** 10+ Gigabit Ethernet with bonding

**Benefits:**

- Production-grade performance
- High availability and redundancy
- Scale to larger models and more concurrent requests

---

## Cloud Cluster VM Allocation

### Control Plane Node

| Resource | Allocation | Rationale |
|----------|------------|-----------|
| CPU | 6 cores | Kubernetes API server, etcd, controller-manager |
| RAM | 12 GB | Control plane components + system overhead |
| Disk | 150 GB | OS, Kubernetes binaries, logs |
| Network | 1 Gbps | Cluster management traffic |
| GPU | None | Not required for control plane |

### CPU Worker Node

| Resource | Allocation | Rationale |
|----------|------------|-----------|
| CPU | 6 cores | General workloads, MLOps stack services |
| RAM | 16 GB | MLflow, MinIO, PostgreSQL, system services |
| Disk | 150 GB | OS, container images, temporary storage |
| Network | 1 Gbps | Service-to-service communication |
| GPU | None | CPU-only workloads |

### GPU Worker Node 1 (Primary Inference)

| Resource | Allocation | Rationale |
|----------|------------|-----------|
| CPU | 12 cores | Inference preprocessing, model loading |
| RAM | 32 GB | Large model inference, batch processing |
| Disk | 300 GB | Model cache, container images |
| Network | 1+ Gbps | High-throughput inference traffic |
| GPU | 1x NVIDIA GPU | RTX A6000 (48 GB VRAM) or equivalent |

**GPU Selection Criteria:**

- VRAM: 24+ GB for large language models
- Compute Capability: 7.0+ (required for modern frameworks)
- TDP: Consider power and cooling requirements

### GPU Worker Node 2 (Secondary/Overflow)

| Resource | Allocation | Rationale |
|----------|------------|-----------|
| CPU | 12 cores | Inference preprocessing, model loading |
| RAM | 32 GB | Large model inference, batch processing |
| Disk | 300 GB | Model cache, container images |
| Network | 1+ Gbps | High-throughput inference traffic |
| GPU | 1x NVIDIA GPU | Tesla T4 (16 GB VRAM) or RTX A6000 |

---

## Total Resource Summary

### Minimum Configuration

| Resource | Per-VM Total | Host Required | Notes |
|----------|--------------|---------------|-------|
| CPU | 36 cores | 40+ cores | 4 cores for host OS + overhead |
| RAM | 92 GB | 96+ GB | 4+ GB for host OS |
| Disk | 900 GB | 1 TB | Additional space for images, logs |
| GPU | 2 GPUs | 2 GPUs | PCIe passthrough to VM workers |

### Concurrent HPC + Cloud Operation

If running both clusters simultaneously:

| Resource | HPC Cluster | Cloud Cluster | Total Required |
|----------|-------------|---------------|----------------|
| CPU | 44 cores | 36 cores | 80+ cores |
| RAM | 112 GB | 92 GB | 208+ GB |
| Disk | 1 TB | 900 GB | 2+ TB |
| GPU | 2-4 GPUs | 2 GPUs | 4-6 GPUs |

**Recommendation:** For resource-constrained environments, run clusters sequentially:

- Train on HPC cluster → Stop HPC cluster → Start cloud cluster → Deploy model

---

## Software Requirements

### Host System

| Component | Version | Purpose |
|-----------|---------|---------|
| Operating System | Debian 13 (Trixie) or Ubuntu 22.04+ | Host OS |
| Kernel | 6.12+ | KVM, GPU passthrough support |
| LibVirt | 9.0+ | VM management |
| QEMU/KVM | 8.0+ | Virtualization |
| NVIDIA Driver | 535+ | GPU support (if using NVIDIA GPUs) |
| Python | 3.11+ | AI-HOW CLI and automation |
| Ansible | 2.14+ | Configuration management |

### Cloud Cluster VMs

| Component | Version | Installed By |
|-----------|---------|--------------|
| Debian | 13 (Trixie) | Packer image |
| Containerd | 1.7.23+ | Packer/Kubespray |
| Kubernetes | 1.28.0 | Kubespray |
| Calico CNI | 3.30.3+ | Kubespray |
| NVIDIA Driver | 535+ | Packer or GPU Operator |
| CUDA Toolkit | 12.0+ (containerized) | GPU Operator |

### MLOps Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| MinIO | Latest stable | S3-compatible object storage |
| PostgreSQL | 15.4+ | MLflow backend database |
| MLflow | 2.9.2+ | Experiment tracking, model registry |
| KServe | 0.11.2+ | Model inference serving |
| Prometheus | Latest | Monitoring and metrics |
| Grafana | Latest | Visualization dashboards |

---

## Network Requirements

### Internal Network (VM-to-VM)

- **Network Type:** Bridged or NAT network
- **Subnet:** 192.168.200.0/24 (configurable)
- **Bandwidth:** 1 Gbps minimum
- **Latency:** <1ms within cluster

**Required Ports:**

| Service | Port(s) | Protocol | Purpose |
|---------|---------|----------|---------|
| Kubernetes API | 6443 | TCP | Cluster management |
| etcd | 2379-2380 | TCP | Distributed key-value store |
| Kubelet | 10250 | TCP | Node agent |
| NodePort Services | 30000-32767 | TCP | External service access |
| Calico BGP | 179 | TCP | Network policy |
| Calico VXLAN | 4789 | UDP | Overlay networking |

### External Access

- **Ingress Controller:** NGINX Ingress on NodePort or LoadBalancer
- **Services Requiring External Access:**
  - MLflow UI (port 5000 or via Ingress)
  - Grafana (port 3000 or via Ingress)
  - MinIO Console (port 9001 or via Ingress)
  - Inference API (via Ingress)

---

## Storage Requirements

### Per-Component Storage Breakdown

| Component | Storage | Type | Rationale |
|-----------|---------|------|-----------|
| Packer Base Image | 5-10 GB | Image | Debian + runtime |
| VM Root Disks (4x) | 600 GB | VM Disk | OS + applications |
| MinIO (models) | 100+ GB | PV | Model artifacts |
| PostgreSQL | 20 GB | PV | MLflow metadata |
| Prometheus | 50 GB | PV | Metrics retention (30 days) |
| Container Images | 50 GB | VM Disk | Cached container images |
| Logs | 20 GB | VM Disk | Application and system logs |

### Storage Growth Considerations

- **Model Storage:** ~5-50 GB per large language model
- **Metrics:** ~1-2 GB/day for comprehensive monitoring
- **Logs:** ~500 MB/day for typical workload

**Recommended:** Plan for 2x storage for growth over 6 months.

---

## Performance Targets

### Inference Performance

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Cold Start Latency | <10 seconds | Time from InferenceService creation to first request |
| Warm Inference Latency (P95) | <500ms | 95th percentile response time |
| Throughput | >50 req/s per GPU | Concurrent requests handling |
| GPU Utilization | >70% | Average during peak load |
| Autoscaling Response Time | <2 minutes | Time to scale from min to desired replicas |

### Cluster Performance

| Metric | Target | Notes |
|--------|--------|-------|
| Pod Startup Time | <30 seconds | For standard workloads |
| GPU Pod Startup Time | <2 minutes | Including driver initialization |
| DNS Resolution | <50ms | Internal service discovery |
| Inter-Pod Latency | <1ms | Within same node |
| Cross-Node Latency | <5ms | Between nodes |

---

## Scaling Considerations

### Vertical Scaling (Per-VM)

Increase resources allocated to existing VMs:

- **Control Plane:** Up to 8 CPU, 16 GB RAM
- **Workers:** Up to 16 CPU, 64 GB RAM per worker
- **GPU Workers:** Up to 4 GPUs per worker (if host supports)

### Horizontal Scaling (Add VMs)

Add additional worker nodes:

- **CPU Workers:** Scale to 3-5 nodes for MLOps services
- **GPU Workers:** Scale to 4-8 nodes for inference capacity
- **Control Plane:** Consider HA with 3 control plane nodes

### Resource Limits

- **Maximum VMs:** Limited by host resources (typically 10-20 VMs)
- **Maximum GPUs per VM:** Typically 1-2 via PCIe passthrough
- **Network Bandwidth:** Shared among all VMs

---

## Cost Considerations

### Hardware Investment

Approximate costs for recommended configuration:

| Component | Est. Cost | Notes |
|-----------|-----------|-------|
| Server (24-32 cores) | $3,000-$8,000 | Dell, HP, Supermicro |
| RAM (128-256 GB) | $500-$1,500 | DDR4/DDR5 |
| Storage (1.5-2 TB NVMe) | $200-$500 | Enterprise SSDs |
| GPUs (2-4x RTX A6000) | $8,000-$20,000 | Or Tesla T4 for lower cost |
| Networking | $200-$1,000 | 10GbE NICs, switches |
| **Total** | **$12,000-$31,000** | One-time investment |

### Operational Costs

- **Power:** ~$50-150/month (depending on utilization and local rates)
- **Cooling:** Included in data center or office HVAC
- **Maintenance:** Minimal (self-hosted)
- **Software:** All open-source (no licensing costs)

### Cloud Comparison

Running equivalent infrastructure in cloud:

| Provider | Monthly Cost (est.) | Annual Cost |
|----------|---------------------|-------------|
| AWS | $2,000-$5,000 | $24,000-$60,000 |
| GCP | $1,800-$4,500 | $21,600-$54,000 |
| Azure | $2,200-$5,500 | $26,400-$66,000 |

**ROI:** Self-hosted infrastructure pays for itself in 6-12 months for sustained workloads.

---

## References

- **Main Implementation Plan:** [cloud-cluster-oumi-inference.md](../../../design-docs/cloud-cluster-oumi-inference.md)
- **Cluster Configuration:** `config/example-multi-gpu-clusters.yaml`
- **VM Management:** `python/ai_how/src/ai_how/vm/`

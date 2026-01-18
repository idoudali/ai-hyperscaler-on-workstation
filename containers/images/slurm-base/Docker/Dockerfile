# Slurm Base Container for Kubernetes
# Base image with Slurm packages installed, configurable for different roles
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV SLURM_VERSION=24.11.0

# Install system dependencies and Slurm runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    systemd \
    systemd-sysv \
    libmunge2 \
    munge \
    libmariadb3 \
    mariadb-client \
    libpmix2 \
    libpam0g \
    libhwloc15 \
    liblua5.3-0 \
    libjson-c5 \
    libhdf5-310 \
    libhdf5-hl-310 \
    libfreeipmi17 \
    libipmimonitoring6 \
    libjwt2 \
    librdkafka1 \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Create Slurm and MUNGE users
RUN useradd -r -s /usr/sbin/nologin -d /var/lib/slurm -c "SLURM Resource Manager" slurm && \
    useradd -r -s /usr/sbin/nologin -d /var/lib/munge -c "MUNGE authentication service" munge

# Create necessary directories
RUN mkdir -p /etc/slurm \
    /var/spool/slurmd \
    /var/spool/slurmctld \
    /var/spool/slurmdbd \
    /var/lib/slurm \
    /var/log/slurm \
    /etc/munge \
    /var/lib/munge \
    /var/log/munge \
    /var/run/munge \
    /tmp/slurm-packages && \
    chown -R slurm:slurm /etc/slurm /var/spool/slurmd /var/spool/slurmctld /var/spool/slurmdbd /var/lib/slurm /var/log/slurm && \
    chown -R munge:munge /etc/munge /var/lib/munge /var/log/munge /var/run/munge

# Copy entrypoint script that configures the container for its role
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy install script that installs Slurm packages from /tmp/slurm-packages
COPY install-slurm.sh /usr/local/bin/install-slurm.sh
RUN chmod +x /usr/local/bin/install-slurm.sh

WORKDIR /tmp/slurm-packages

# Default to installing Slurm packages and then running entrypoint
CMD ["/usr/local/bin/entrypoint.sh"]


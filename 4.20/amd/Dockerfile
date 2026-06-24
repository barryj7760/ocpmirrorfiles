# ========================
# Builder stage
# ========================
FROM registry.access.redhat.com/ubi9/ubi:9.6 as builder

# Arguments
ARG KERNEL_FULL_VERSION=5.14.0-570.112.1.el9_6.x86_64
ARG DRIVERS_VERSION=6.14.14-2247874.el9
ARG RHEL_VERSION=9.6
ARG REPO_URL=https://repo.radeon.com

# Copy in kernel RPMs
COPY ./rpms/*.rpm /root/rpms/
RUN rpm -ivh /root/rpms/kernel-devel-${KERNEL_FULL_VERSION}.rpm --nodeps && \
    rpm -ivh /root/rpms/kernel-core-${KERNEL_FULL_VERSION}.rpm --nodeps && \
    rpm -ivh /root/rpms/kernel-headers-${KERNEL_FULL_VERSION}.rpm --nodeps

# Import AMD GPG key
RUN rpm --import ${REPO_URL}/rocm/rocm.gpg.key

COPY amdgpu.repo /etc/yum.repos.d/amdgpu.repo

# Install build dependencies + dkms (from EPEL)
RUN dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    dnf -y install \
    bc \
    bison \
    flex \
    elfutils-libelf-devel \
    git \
    make \
    gcc \
    wget \
    dkms && \
    dnf clean all


# Install AMDGPU DKMS source package
RUN dnf install -y amdgpu-dkms && \
    dnf clean all

# Set up kernel source symlinks for dkms
RUN mkdir -p /lib/modules/${KERNEL_FULL_VERSION} && \
    ln -s /usr/src/kernels/${KERNEL_FULL_VERSION} /lib/modules/${KERNEL_FULL_VERSION}/build && \
    ln -s /usr/src/kernels/${KERNEL_FULL_VERSION} /lib/modules/${KERNEL_FULL_VERSION}/source

# Explicitly build/install for ARG kernel
RUN dkms build -m amdgpu -v ${DRIVERS_VERSION} -k ${KERNEL_FULL_VERSION} && \
    dkms install -m amdgpu -v ${DRIVERS_VERSION} -k ${KERNEL_FULL_VERSION} && \
    depmod -b / ${KERNEL_FULL_VERSION}


# ========================
# Final stage
# ========================
FROM registry.access.redhat.com/ubi9/ubi:9.6

ARG KERNEL_FULL_VERSION=5.14.0-570.112.1.el9_6.x86_64

RUN dnf -y install kmod && dnf clean all

# Copy built kernel modules
RUN mkdir -p /opt/lib/modules/${KERNEL_FULL_VERSION}/extra/
COPY --from=builder /lib/modules/${KERNEL_FULL_VERSION}/extra/* /opt/lib/modules/${KERNEL_FULL_VERSION}/extra/
COPY --from=builder /lib/modules/${KERNEL_FULL_VERSION}/modules.* /opt/lib/modules/${KERNEL_FULL_VERSION}/
RUN ln -s /lib/modules/${KERNEL_FULL_VERSION}/kernel /opt/lib/modules/${KERNEL_FULL_VERSION}/kernel

# Copy firmware
RUN mkdir -p /firmwareDir/updates/amdgpu
COPY --from=builder /lib/firmware/updates/amdgpu /firmwareDir/updates/amdgpu

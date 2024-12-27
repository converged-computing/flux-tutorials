#!/bin/bash

set -euo pipefail

################################################################
#
# Flux, Singularity, and Infiniband dependenciess
#

/usr/bin/cloud-init status --wait

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update && \
    sudo apt-get install -y apt-transport-https ca-certificates curl jq apt-utils wget \
         libelf-dev libpcap-dev libbfd-dev binutils-dev build-essential make \
         linux-tools-common linux-tools-$(uname -r)  \
         python3-pip git net-tools

# Microsoft packages for 24.04
# curl https://packages.microsoft.com/config/ubuntu/24.04/prod.list > ./microsoft-prod.list
# sudo cp ./microsoft-prod.list /etc/apt/sources.list.d/

# Install the Microsoft GPG public key
# Note I'm commenting this out - I don't see any microsoft packages I want / need
# curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
# sudo cp ./microsoft.gpg /etc/apt/trusted.gpg.d/
# sudo cp ./microsoft.gpg /usr/share/keyrings/microsoft-prod.gpg
# gpg --refresh-keys

# cmake is needed for flux-sched, and make sure to choose arm or x86
export CMAKE=3.23.1
export ARCH=x86_64
export ORAS_ARCH=amd64

curl -s -L https://github.com/Kitware/CMake/releases/download/v$CMAKE/cmake-$CMAKE-linux-$ARCH.sh > cmake.sh && \
    sudo sh cmake.sh --prefix=/usr/local --skip-license && \
    sudo apt-get update && \
    sudo apt-get install -y man flex ssh sudo vim luarocks munge lcov ccache lua5.4 \
         valgrind build-essential pkg-config autotools-dev libtool \
         libffi-dev autoconf automake make clang clang-tidy \
         gcc g++ libpam-dev apt-utils lua-posix \
         libsodium-dev libzmq3-dev libczmq-dev libjansson-dev libmunge-dev \
         libncursesw5-dev liblua5.4-dev liblz4-dev libsqlite3-dev uuid-dev \
         libhwloc-dev libs3-dev libevent-dev libarchive-dev \
         libboost-graph-dev libboost-system-dev libboost-filesystem-dev \
         libboost-regex-dev libyaml-cpp-dev libedit-dev uidmap dbus-user-session python3-cffi

# Azure hpc-images deps added here - not clear if all of these are needed
# sudo apt-get install -y numactl rpm libnuma-dev libmpc-dev libmpfr-dev libxml2-dev m4 byacc \
#         libnl-3-dev libnl-route-3-dev libnl-3-200 libnl-genl-3-dev libnl-genl-3-200 libnl-route-3-200 bison \
#         libsecret-1-0 dkms libyaml-dev libreadline-dev libkeyutils1 libkeyutils-dev libmount-dev nfs-common pssh \
#         libvulkan1 hwloc selinux-policy-dev nvme-cli # vulkan is for nvidia gpu driver

sudo ldconfig
# Other Microsoft helpers
# Not installing:
# azcopy
# kvp client
# torset-tool
# lustre

# First manual test build 12/26/2024
# $ lspci
# 0101:00:00.0 Infiniband controller: Mellanox Technologies MT28908 Family [ConnectX-6 Virtual Function]
# 3532:00:00.0 Non-Volatile memory controller: Microsoft Corporation Device b111
# 78a8:00:00.0 Non-Volatile memory controller: Microsoft Corporation Device b111
# cc4c:00:02.0 Ethernet controller: Mellanox Technologies MT27710 Family [ConnectX-4 Lx Virtual Function] (rev 80)

# https://docs.nvidia.com/doca/archive/2-8-0/nvidia+doca+installation+guide+for+linux/index.html
# wget https://developer.nvidia.com/downloads/networking/secure/doca-sdk/DOCA_2.8/doca-host_2.8.0-204000-24.07-ubuntu2404_amd64.deb
# sudo dpkg -i doca-host_2.8.0-204000-24.07-ubuntu2404_amd64.deb
# rm doca-host_2.8.0-204000-24.07-ubuntu2404_amd64.deb

#  ofed_info -s
# MLNX_OFED_LINUX-23.04-1.1.3.0

# Install ORAS client
VERSION="1.2.2"
curl -LO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz"
mkdir -p oras-install/
tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/
sudo mv oras-install/oras /usr/local/bin/
rm -rf oras_${VERSION}_*.tar.gz oras-install/

# /etc/init.d/openibd status
#   HCA driver loaded

# Configured IPoIB devices:
# ib0

# Currently active IPoIB devices:
# Configured Mellanox EN devices:
# eth1

# Currently active Mellanox devices:
# eth1
# ib0

# The following OFED modules are loaded:

#   rdma_ucm
#   rdma_cm
#   ib_ipoib
#   mlx5_core
#   mlx5_ib
#   ib_uverbs
#   ib_umad
#   ib_cm
#   ib_core
#   mlxfw
sudo locale-gen en_US.UTF-8

# HPC-x (MPI)
# Located at 
. /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/hpcx-mt-init.sh
hpcx_load
env | grep HPCX

################################################################
## Install Flux and dependencies

# QUESTION: Do we still need this given packages above?
# sudo chown -R $(whoami) /opt && \
#    mkdir -p /opt/prrte && \
#    cd /opt/prrte && \
#    git clone https://github.com/openpmix/openpmix.git && \
#    git clone https://github.com/openpmix/prrte.git && \
#    cd openpmix && \
#    git checkout fefaed568f33bf86f28afb6e45237f1ec5e4de93 && \
#    ./autogen.pl && \
#    ./configure --prefix=/usr --disable-static && sudo make install && \
#    sudo ldconfig

# cd /opt/prrte/prrte && \
#    git checkout 477894f4720d822b15cab56eee7665107832921c && \
#    ./autogen.pl && \
#    ./configure --prefix=/usr && sudo make -j install

# flux security
sudo mkdir -p /opt/flux
sudo chown -R $(whoami) /opt/flux
wget https://github.com/flux-framework/flux-security/releases/download/v0.13.0/flux-security-0.13.0.tar.gz && \
    tar -xzvf flux-security-0.13.0.tar.gz && \
    mv flux-security-0.13.0 /opt/flux/flux-security && \
    cd /opt/flux/flux-security && \
    ./configure --prefix=/usr --sysconfdir=/etc && \
    make -j && sudo make install

# The VMs will share the same munge key
sudo mkdir -p /var/run/munge && \
    dd if=/dev/urandom bs=1 count=1024 > munge.key && \
    sudo mv munge.key /etc/munge/munge.key && \
    sudo chown -R munge /etc/munge/munge.key /var/run/munge && \
    sudo chmod 600 /etc/munge/munge.key

# Make the flux run directory
ls /home
whoami
sudo mkdir -p /home/azureuser/run/flux
sudo chown azureuser /home/azureuser

# Flux core
wget https://github.com/flux-framework/flux-core/releases/download/v0.68.0/flux-core-0.68.0.tar.gz && \
    tar -xzvf flux-core-0.68.0.tar.gz && \
    mv flux-core-0.68.0 /opt/flux/flux-core && \
    cd /opt/flux/flux-core && \
    ./configure --prefix=/usr --sysconfdir=/etc --with-flux-security && \
    make clean && \
    make -j && sudo make install

# Flux pmix (must be installed after flux core)
# wget https://github.com/flux-framework/flux-pmix/releases/download/v0.5.0/flux-pmix-0.5.0.tar.gz && \
#     tar -xzvf flux-pmix-0.5.0.tar.gz && \
#     mv flux-pmix-0.5.0 /opt/flux/flux-pmix && \
#     cd /opt/flux/flux-pmix && \
#     ./configure --prefix=/usr && \
#     make -j && \
#     sudo make install

# Flux sched (later than this requires newer gcc and clang)
wget https://github.com/flux-framework/flux-sched/releases/download/v0.37.0/flux-sched-0.37.0.tar.gz && \
    tar -xzvf flux-sched-0.37.0.tar.gz && \
    mv flux-sched-0.37.0 /opt/flux/flux-sched && \
    cd /opt/flux/flux-sched && \
    mkdir build && \
    cd build && \
    cmake ../ && make -j && sudo make install && sudo ldconfig && \
    echo "DONE flux build"

# Flux curve.cert
# Ensure we have a shared curve certificate
flux keygen /tmp/curve.cert && \
    sudo mkdir -p /etc/flux/system && \
    sudo cp /tmp/curve.cert /etc/flux/system/curve.cert && \
    sudo chown azureuser /etc/flux/system/curve.cert && \
    sudo chmod o-r /etc/flux/system/curve.cert && \
    sudo chmod g-r /etc/flux/system/curve.cert && \
    # Permissions for imp
    sudo chmod u+s /usr/libexec/flux/flux-imp && \
    sudo chmod 4755 /usr/libexec/flux/flux-imp && \
    # /var/lib/flux needs to be owned by the instance owner
    sudo mkdir -p /var/lib/flux && \
    sudo chown azureuser -R /var/lib/flux && \
    # clean up (and make space)
    cd /opt
    sudo rm -rf /opt/flux

# Install Singularity
# flux start mpirun -n 6 singularity exec singularity-mpi_mpich.sif /opt/mpitest
sudo apt-get update && sudo apt-get install -y libseccomp-dev libglib2.0-dev cryptsetup \
   libfuse-dev \
   squashfs-tools \
   squashfs-tools-ng \
   uidmap \
   zlib1g-dev \
   iperf3

sudo apt-get install -y \
   autoconf \
   automake \
   cryptsetup \
   git \
   libfuse-dev \
   libglib2.0-dev \
   libseccomp-dev \
   libtool \
   pkg-config \
   runc \
   squashfs-tools \
   squashfs-tools-ng \
   uidmap \
   wget \
   zlib1g-dev

# install go
cd /tmp
wget https://go.dev/dl/go1.21.0.linux-${ORAS_ARCH}.tar.gz
tar -xvf go1.21.0.linux-${ORAS_ARCH}.tar.gz
sudo mv go /usr/local && rm go1.21.0.linux-${ORAS_ARCH}.tar.gz
export PATH=/usr/local/go/bin:$PATH

# Install singularity
export VERSION=4.0.1 && \
    wget https://github.com/sylabs/singularity/releases/download/v${VERSION}/singularity-ce-${VERSION}.tar.gz && \
    tar -xzf singularity-ce-${VERSION}.tar.gz && \
    cd singularity-ce-${VERSION}

./mconfig && \
 make -C builddir && \
 sudo make -C builddir install

/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync

# Ensure the flux uri is exported for all users
# The build should be done as azureuser, but don't assume it.
export FLUX_URI=local:///opt/run/flux/local
echo "export FLUX_URI=local:///opt/run/flux/local" >> /home/$(whoami)/.bashrc
echo "export FLUX_URI=local:///opt/run/flux/local" >> /home/azureuser/.bashrc

# Ensure we source the environment.
echo ". /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/hpcx-mt-init.sh" >> /home/$(whoami)/.bashrc
echo ". /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/hpcx-mt-init.sh" >> /home/azureuser/.bashrc
echo "hpcx_load" >> /home/$(whoami)/.bashrc
echo "hpcx_load" >> /home/azureuser/.bashrc

# The flux uri needs to be set for all users that logic
echo "FLUX_URI        DEFAULT=local:///opt/run/flux/local" >> ./environment
sudo mv ./environment /etc/security/pam_env.conf

# 
# At this point we have what we need!

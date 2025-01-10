#!/bin/bash

set -euo pipefail

################################################################
#
# Flux, Singularity, and Infiniband dependencies
# Starting on ubuntu 24.04
#

# In practice I haven't seen needing this
# /usr/bin/cloud-init status --wait

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update && \
    sudo apt-get install -y apt-transport-https ca-certificates curl jq apt-utils wget curl jq \
         build-essential make linux-tools-common linux-tools-$(uname -r)

# Install ORAS client
VERSION="1.2.2"
curl -LO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz"
mkdir -p oras-install/
tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/
sudo mv oras-install/oras /usr/local/bin/
rm -rf oras_${VERSION}_*.tar.gz oras-install/

# Infiniband
# make sure secure boot is disabled 
# mokutil --sb-state
sudo chown -R azureuser /opt

# https://docs.nvidia.com/networking/display/mlnxofedv24101140lts/installing+the+driver#src-3411296587_InstallingtheDriver-InstallationScript
# check we have devices 
# lspci -v | grep Mellanox
cd /opt
oras pull ghcr.io/converged-computing/rdma-infiniband:ubuntu-24.04-tgz
tar -xzvf MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64.tgz
touch MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64.txt
mv MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64 mlnx
rm MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64.tgz 
cd mlnx
sudo ./mlnxofedinstall --force
sudo /etc/init.d/openibd restart

# Rename device to ib0
cd /opt
wget https://raw.githubusercontent.com/converged-computing/aks-infiniband-install/main/ubuntu22.04/parse-links.py
sudo python3 parse-links.py
ip link

cd /opt
wget https://github.com/openucx/ucx/releases/download/v1.17.0/ucx-1.17.0.tar.gz && \
    tar -xzvf ucx-1.17.0.tar.gz && \
    cd ucx-1.17.0 && \
    ./configure --disable-logging --disable-debug --disable-assertions --disable-params-check --enable-mt --prefix=/usr --enable-examples --without-java --without-go --without-xpmem --without-cuda --with-rc --with-ud --with-dc \
    --with-mlx5-dv --with-verbs --with-ib-hw-tm --with-dm --with-devx && \
    make -j && sudo make install && sudo ldconfig

wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.2.tar.gz && \
    tar -xzvf openmpi-4.1.2.tar.gz && \
    cd openmpi-4.1.2 && \
    ./configure --with-ucx=/usr && \
    make -j && sudo make install && sudo ldconfig

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

# /etc/init.d/openibd status
#  HCA driver loaded

# Configured IPoIB devices:
# ib0

# Currently active IPoIB devices:
# Configured Mellanox EN devices:
# enP54485s1

# Currently active Mellanox devices:
# enP54485s1
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

################################################################
## Install Flux and dependencies

mkdir -p /opt/prrte && \
    cd /opt/prrte && \
    git clone https://github.com/openpmix/openpmix.git && \
    git clone https://github.com/openpmix/prrte.git && \
    cd openpmix && \
    git checkout fefaed568f33bf86f28afb6e45237f1ec5e4de93 && \
    ./autogen.pl && \
    ./configure --prefix=/usr --disable-static && sudo make install && \
    sudo ldconfig

cd /opt/prrte/prrte && \
    git checkout 477894f4720d822b15cab56eee7665107832921c && \
    ./autogen.pl && \
    ./configure --prefix=/usr && sudo make -j install

# flux security
cd /opt
wget https://github.com/flux-framework/flux-security/releases/download/v0.13.0/flux-security-0.13.0.tar.gz && \
    tar -xzvf flux-security-0.13.0.tar.gz && \
    mv flux-security-0.13.0 /opt/flux-security && \
    cd /opt/flux-security && \
    ./configure --prefix=/usr --sysconfdir=/etc && \
    make -j && sudo make install

# The VMs will share the same munge key
sudo mkdir -p /var/run/munge && \
    dd if=/dev/urandom bs=1 count=1024 > munge.key && \
    sudo mv munge.key /etc/munge/munge.key && \
    sudo chown -R munge /etc/munge/munge.key /var/run/munge && \
    sudo chmod 600 /etc/munge/munge.key

# Make the flux run directory
mkdir -p /home/azureuser/run/flux

# Flux core
sudo apt-get install -y python3-pip
cd /opt
wget https://github.com/flux-framework/flux-core/releases/download/v0.68.0/flux-core-0.68.0.tar.gz && \
    tar -xzvf flux-core-0.68.0.tar.gz && \
    mv flux-core-0.68.0 /opt/flux-core && \
    cd /opt/flux-core && \
    ./configure --prefix=/usr --sysconfdir=/etc --with-flux-security && \
    make clean && \
    make -j && sudo make install

# Flux pmix (must be installed after flux core)
cd /opt
wget https://github.com/flux-framework/flux-pmix/releases/download/v0.5.0/flux-pmix-0.5.0.tar.gz && \
     tar -xzvf flux-pmix-0.5.0.tar.gz && \
     mv flux-pmix-0.5.0 /opt/flux-pmix && \
     cd /opt/flux-pmix && \
     ./configure --prefix=/usr && \
     make -j && \
     sudo make install

# Flux sched
cd /opt
wget https://github.com/flux-framework/flux-sched/releases/download/v0.40.0/flux-sched-0.40.0.tar.gz && \
    tar -xzvf flux-sched-0.40.0.tar.gz && \
    mv flux-sched-0.40.0 /opt/flux-sched && \
    cd /opt/flux-sched && \
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
    cd /opt

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

# Ensure the flux uri is exported for all users
# The build should be done as azureuser, but don't assume it.
export FLUX_URI=local:///opt/run/flux/local
echo "export FLUX_URI=local:///opt/run/flux/local" >> /home/$(whoami)/.bashrc
echo "export FLUX_URI=local:///opt/run/flux/local" >> /home/azureuser/.bashrc

# The flux uri needs to be set for all users that logic
echo "FLUX_URI        DEFAULT=local:///opt/run/flux/local" >> ./environment
sudo mv ./environment /etc/security/pam_env.conf

# https://ubuntu.com/blog/ubuntu-23-10-restricted-unprivileged-user-namespaces
sudo sysctl -w kernel.apparmor_restrict_unprivileged_unconfined=0
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0

sudo sysctl -p
sudo systemctl daemon-reload
# 
# At this point we have what we need!

/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync

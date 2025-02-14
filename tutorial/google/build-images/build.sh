#!/bin/bash

set -euo pipefail

################################################################
#
# Flux, Singularity, and ORAS
#

# Google cloud doesn't use cloud init, but any system that does needs this
# /usr/bin/cloud-init status --wait

sudo dnf update -y && sudo dnf clean all
sudo dnf group install -y "Development Tools"
sudo dnf config-manager --set-enabled powertools
sudo dnf install -y epel-release

sudo tee /etc/yum.repos.d/gcsfuse.repo > /dev/null <<EOF
[gcsfuse]
name=gcsfuse (packages.cloud.google.com)
baseurl=https://packages.cloud.google.com/yum/repos/gcsfuse-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
      https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

sudo yum install -y fuse
sudo yum install -y gcsfuse
sudo dnf install -y \
    munge \
    munge-devel \
    hwloc \
    hwloc-devel \
    pmix \
    pmix-devel \
    lua \
    lua-devel \
    lua-posix \
    libevent-devel \
    czmq-devel \
    jansson-devel \
    lz4-devel \
    sqlite-devel \
    ncurses-devel \
    libarchive-devel \
    libxml2-devel \
    yaml-cpp-devel \
    boost-devel \
    libedit-devel \
    systemd \
    systemd-devel \
    nfs-utils \
    python3-devel \
    python3-cffi \
    python3-yaml \
    python3-jsonschema \
    python3-sphinx \
    python3-docutils \
    aspell \
    aspell-en \
    valgrind-devel \
    openmpi.x86_64 \
    openmpi-devel.x86_64 \
    wget \
    jq

sudo dnf install -y gcc-toolset-12
. /opt/rh/gcc-toolset-12/enable

# IMPORTANT: the flux user/group must match!
# useradd -M -r -s /bin/false -c "flux-framework identity" flux
sudo groupadd -g 1004 flux
sudo useradd -u 1004 -g 1004 -M -r -s /bin/false -c "flux-framework identity" flux

sudo chown -R $(whoami) /opt
cd /opt

# Update grub
# cat /etc/default/grub | grep GRUB_CMDLINE_LINUX=
# sed -i -e 's/^GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
# update-grub
sudo dnf install -y grubby 
sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=1"

# cmake is needed for flux-sched, and make sure to choose arm or x86
export CMAKE=3.23.1
export ARCH=x86_64
export ORAS_ARCH=amd64

curl -s -L https://github.com/Kitware/CMake/releases/download/v$CMAKE/cmake-$CMAKE-linux-$ARCH.sh > cmake.sh && \
    sudo sh cmake.sh --prefix=/usr/local --skip-license 

################################################################
## Install Flux and dependencies
#
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
wget https://github.com/flux-framework/flux-security/releases/download/v0.13.0/flux-security-0.13.0.tar.gz && \
    tar -xzvf flux-security-0.13.0.tar.gz && \
    mv flux-security-0.13.0 /opt/flux-security && \
    cd /opt/flux-security && \
    PYTHON=$(which python3) ./configure --prefix=/usr --sysconfdir=/etc && \
    make -j && sudo make install

# The VMs will share the same munge key
sudo mkdir -p /var/run/munge && \
    dd if=/dev/urandom bs=1 count=1024 > munge.key && \
    sudo mv munge.key /etc/munge/munge.key && \
    sudo chown -R munge /etc/munge/munge.key /var/run/munge && \
    sudo chmod 600 /etc/munge/munge.key

# Make a root directory for flux (this is run directory)
# Google cloud does weird stuff with /home
mkdir -p /opt/flux/run/flux

# Flux core
wget https://github.com/flux-framework/flux-core/releases/download/v0.68.0/flux-core-0.68.0.tar.gz && \
    tar -xzvf flux-core-0.68.0.tar.gz && \
    mv flux-core-0.68.0 /opt/flux-core && \
    cd /opt/flux-core && \
    PYTHON=$(which python3) ./configure --prefix=/usr --sysconfdir=/etc --runstatedir=/opt/flux/run --with-flux-security && \
    make clean && \
    make -j && sudo make install

# Flux pmix (must be installed after flux core)
wget https://github.com/flux-framework/flux-pmix/releases/download/v0.5.0/flux-pmix-0.5.0.tar.gz && \
    tar -xzvf flux-pmix-0.5.0.tar.gz && \
    mv flux-pmix-0.5.0 /opt/flux-pmix && \
    cd /opt/flux-pmix && \
    PYTHON=$(which python3) ./configure --prefix=/usr && \
    make -j && \
    sudo make install

# Flux sched (not updated because require higher version of gcc (12x) and clang (15)
wget https://github.com/flux-framework/flux-sched/releases/download/v0.40.0/flux-sched-0.40.0.tar.gz && \
    tar -xzvf flux-sched-0.40.0.tar.gz && \
    mv flux-sched-0.40.0 /opt/flux-sched && \
    cd /opt/flux-sched && \
    PYTHON=$(which python3) ./configure --prefix=/usr && \
    make -j && \
    sudo make install && sudo ldconfig && \
    echo "DONE flux build"

# Flux curve.cert
# Ensure we have a shared curve certificate
flux keygen /tmp/curve.cert && \
    sudo mkdir -p /etc/flux/system && \
    sudo cp /tmp/curve.cert /etc/flux/system/curve.cert && \
    sudo chown flux /etc/flux/system/curve.cert && \
    sudo chmod o-r /etc/flux/system/curve.cert && \
    sudo chmod g-r /etc/flux/system/curve.cert && \
    # Permissions for imp
    sudo chmod u+s /usr/libexec/flux/flux-imp && \
    sudo chmod 4755 /usr/libexec/flux/flux-imp && \
    # /var/lib/flux needs to be owned by the instance owner
    sudo mkdir -p /var/lib/flux && \
    sudo chown flux -R /var/lib/flux && \
    # clean up (and make space)
    cd /opt
    sudo rm -rf /opt/flux-core /opt/flux-sched /opt/prrte /opt/flux-security /opt/flux-pmix

# IMPORANT: the above installs to /usr/lib64 but you will get a flux_open error if it's
# not found in /usr/lib. So we put in both places :)
sudo cp -R /usr/lib64/flux /usr/lib/flux
sudo cp -R /usr/lib64/libflux-* /usr/lib/

# Install oras and singularity
export VERSION="1.1.0" && \
curl -LO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_${ORAS_ARCH}.tar.gz" && \
mkdir -p oras-install/ && \
tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/ && \
sudo mv oras-install/oras /usr/local/bin/ && \
rm -rf oras_${VERSION}_*.tar.gz oras-install/

cd /opt

sudo yum update -y && \
    sudo yum groupinstall -y 'Development Tools' && \
    sudo yum install -y \
    openssl-devel \
    libuuid-devel \
    libseccomp-devel \
    wget \
    squashfs-tools \
    glib2-devel \
    fuse3-devel

# install go
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

# Note that broker.toml is written in the startup script now
# Along with the /etc/flux/system/R
sudo mkdir -p /etc/flux/system

# Memory / file limits
cat <<EOF | tee /tmp/memory
*	soft	nproc	unlimited
*	hard	nproc	unlimited
*	soft	memlock	unlimited
*	hard	memlock	unlimited
*	soft	stack	unlimited
*	hard	stack	unlimited
*	soft	nofile	unlimited
*	hard	nofile	unlimited
*	soft	cpu	unlimited
*	hard	cpu	unlimited
*	soft	rtprio	unlimited
*	hard	rtprio	unlimited
EOF

sudo cp /tmp/memory /etc/security/limits.d/98-google-hpc-image.conf
sudo cp /tmp/memory /etc/security/limits.conf

# 
# At this point we have what we need!

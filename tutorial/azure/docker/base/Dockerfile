FROM ubuntu:22.04

# docker build -t ghcr.io/converged-computing/flux-tutorials:azurehpc-2204 .
# docker push ghcr.io/converged-computing/flux-tutorials:azurehpc-2204

WORKDIR /opt
RUN apt-get update && apt-get install -y munge git curl wget unzip gpg debian-archive-keyring \  
    pkg-config vim ubuntu-keyring systemctl && apt-get clean
RUN export VERSION="1.2.2" && \
    curl -LO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz" && \
    mkdir -p oras-install/ && \
    tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/ && \
    mv oras-install/oras /usr/local/bin/ && \
    rm -rf oras_${VERSION}_*.tar.gz oras-install/

# Azure hpc-images deps added here - not clear if all of these are needed
RUN apt-get update && apt-get install -y numactl rpm libnuma-dev libmpc-dev libmpfr-dev libxml2-dev m4 byacc \
         libnl-3-dev libnl-route-3-dev libnl-3-200 libnl-genl-3-dev libnl-genl-3-200 libnl-route-3-200 bison \
         libsecret-1-0 dkms libyaml-dev libreadline-dev libkeyutils1 libkeyutils-dev libmount-dev nfs-common pssh \
         libvulkan1 hwloc selinux-policy-dev nvme-cli && apt-get clean # vulkan is for nvidia gpu driver
ENV DEBIAN_FRONTEND=noninteractive

# OSU Benchmarks in hpcx-v2.19-gcc-mlnx_ofed-ubuntu22.04-cuda12-x86_64/ompi/tests/
RUN oras pull ghcr.io/converged-computing/rdma-infiniband:ubuntu-22.04-tgz --output /opt && \
    cd /opt && \
    tar -xzvf MLNX_OFED_LINUX-24.04-0.7.0.0-ubuntu22.04-x86_64.tgz && \
    cd MLNX_OFED_LINUX-24.04-0.7.0.0-ubuntu22.04-x86_64/DEBS/ && \
    dpkg -i mpitests_3.2.23-45a045b.2404066_amd64.deb && \
    dpkg -i libibverbs1* && \
    dpkg -i ibverbs-providers* && \
    dpkg -i libibverbs* && \
    dpkg -i librdmacm* && \
    dpkg -i ucx_1.17.0-1.2404066_amd64.deb && \
    dpkg -i libibumad3* && \
    dpkg -i sharp_3.7.0.MLNX20240421.48444036-1.2404066_amd64.deb && \
    dpkg -i hcoll_4.8.3227-1.2404066_amd64.deb 

# This was extracted into separate lines, below, to avoid one large layer (and debug each)
# RUN ./install.sh
ENV GPU=NVIDIA

# Install only what we need as we go (so change to single file doesn't require complete rebuild)
WORKDIR /opt/azhpc-images/ubuntu/ubuntu-22.x/ubuntu-22.04-hpc
COPY ./azhpc-images/ubuntu/ubuntu-22.x/ubuntu-22.04-hpc/install_prerequisites.sh ./install_prerequisites.sh

# install pre-requisites
RUN ./install_prerequisites.sh
COPY ./azhpc-images/versions.json /opt/azhpc-images/versions.json

COPY ./azhpc-images/ubuntu/ubuntu-22.x/ubuntu-22.04-hpc/set_properties.sh ./
COPY ./azhpc-images/ubuntu/ubuntu-22.x/ubuntu-22.04-hpc/install_utils.sh ./
COPY ./azhpc-images/ubuntu/common/remove_unused_packages.sh /opt/azhpc-images/ubuntu/common/remove_unused_packages.sh
COPY ./azhpc-images/ubuntu/common/install_utils.sh /opt/azhpc-images/ubuntu/common/install_utils.sh
COPY ./azhpc-images/ubuntu/common/install_pmix.sh /opt/azhpc-images/ubuntu/common/install_pmix.sh
COPY ./azhpc-images/ubuntu/common/install_pmix.sh /opt/azhpc-images/ubuntu/common/install_mpis.sh
COPY ./azhpc-images/common/ /opt/azhpc-images/common/
COPY ./azhpc-images/tools/ /opt/azhpc-images/tools/

# remove packages requiring Ubuntu Pro for security updates
RUN . ./set_properties.sh && \
    /bin/bash $UBUNTU_COMMON_DIR/remove_unused_packages.sh && \
    ./install_utils.sh

COPY ./azhpc-images/ubuntu/common/install_docker.sh /opt/azhpc-images/ubuntu/common/install_docker.sh
COPY ./azhpc-images/ubuntu/common/* /opt/azhpc-images/ubuntu/common/
RUN . ./set_properties.sh && \
    /bin/bash $UBUNTU_COMMON_DIR/install_docker.sh

# install diagnostic script, optimizations
RUN . ./set_properties.sh && \
    /bin/bash $COMMON_DIR/install_hpcdiag.sh && \
    /bin/bash $COMMON_DIR/install_azure_persistent_rdma_naming.sh

RUN . ./set_properties.sh && \
    /bin/bash $UBUNTU_COMMON_DIR/hpc-tuning.sh

COPY ./azhpc-images/tests/ /opt/azhpc-images/tests
COPY ./azhpc-images/customizations/ /opt/azhpc-images/customizations
COPY ./azhpc-images/topology/ /opt/azhpc-images/topology

RUN . ./set_properties.sh && \
    /bin/bash $COMMON_DIR/copy_test_file.sh && \
    /bin/bash $COMMON_DIR/install_monitoring_tools.sh && \
    /bin/bash $COMMON_DIR/install_amd_libs.sh

RUN . ./set_properties.sh && \
    /bin/bash $COMMON_DIR/setup_sku_customizations.sh

RUN . ./set_properties.sh && \
    /bin/bash $UBUNTU_COMMON_DIR/install_pmix.sh

# For some reason this command, when moved higher up, was flaky. 
# Watch it and make sure it doesn't skip (if it does the build will fail later)
RUN . ./set_properties.sh && \
    /bin/bash $UBUNTU_COMMON_DIR/install_mpis.sh

# cleanup downloaded tarballs - clear some space
RUN rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh && \
    rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf* && \
    rm -rf /var/intel/ /var/cache/* && \
    rm -Rf -- */

# INFO: Building OMPI with HCOLL
# Ready to rebuild
#  HPCX_ROOT:      /opt/hpcx-v2.19-gcc-mlnx_ofed-ubuntu22.04-cuda12-x86_64
#  OMPI PREFIX:    /opt/hpcx-v2.19-gcc-mlnx_ofed-ubuntu22.04-cuda12-x86_64/hpcx-rebuild
#  UCX location:   /opt/hpcx-v2.19-gcc-mlnx_ofed-ubuntu22.04-cuda12-x86_64/ucx
#  UCC location:   /opt/hpcx-v2.19-gcc-mlnx_ofed-ubuntu22.04-cuda12-x86_64/ucc
#  HCOLL location: /opt/hpcx-v2.19-gcc-mlnx_ofed-ubuntu22.04-cuda12-x86_64/hcoll

ENV LANG=C.UTF-8
RUN apt-get update && apt-get install -y locales && locale-gen en_US.UTF-8 && apt-get clean

# Add an azureuser
ARG USER=azureuser
ARG UID=1000
ARG GID=1000
RUN set -x && groupadd -g $UID $USER && \
    useradd -g $USER -u $UID -d /home/$USER -m $USER && \
    printf "$USER ALL= NOPASSWD: ALL\\n" >> /etc/sudoers

# flux security
WORKDIR /opt/flux
RUN . /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/hpcx-mt-init.sh && hpcx_load && \
    wget https://github.com/flux-framework/flux-security/releases/download/v0.13.0/flux-security-0.13.0.tar.gz && \
    tar -xzvf flux-security-0.13.0.tar.gz && \
    mv flux-security-0.13.0 /opt/flux/flux-security && \
    cd /opt/flux/flux-security && \
    ./configure --prefix=/usr --sysconfdir=/etc && \
    make -j && make install

# The VMs will share the same munge key
RUN mkdir -p /var/run/munge && \
    dd if=/dev/urandom bs=1 count=1024 > munge.key && \
    mv munge.key /etc/munge/munge.key && \
    chown -R munge /etc/munge/munge.key /var/run/munge && \
     chmod 600 /etc/munge/munge.key

# Make the flux run directory
RUN mkdir -p /home/azureuser/run/flux && chown azureuser /home/azureuser

# Flux core
RUN . /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/hpcx-mt-init.sh && hpcx_load && \
    wget https://github.com/flux-framework/flux-core/releases/download/v0.68.0/flux-core-0.68.0.tar.gz && \
    tar -xzvf flux-core-0.68.0.tar.gz && \
    mv flux-core-0.68.0 /opt/flux/flux-core && \
    cd /opt/flux/flux-core && \
    ./configure --prefix=/usr --sysconfdir=/etc --with-flux-security && \
    make clean && \
    make -j && sudo make install

# Flux sched (later than this requires newer gcc and clang)
RUN . /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/hpcx-mt-init.sh && hpcx_load && \
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
RUN flux keygen /tmp/curve.cert && \
    mkdir -p /etc/flux/system && \
    cp /tmp/curve.cert /etc/flux/system/curve.cert && \
    chown azureuser /etc/flux/system/curve.cert && \
    chmod o-r /etc/flux/system/curve.cert && \
    chmod g-r /etc/flux/system/curve.cert && \
    # Permissions for imp
    chmod u+s /usr/libexec/flux/flux-imp && \
    chmod 4755 /usr/libexec/flux/flux-imp && \
    # /var/lib/flux needs to be owned by the instance owner
    mkdir -p /var/lib/flux && \
    chown azureuser -R /var/lib/flux && \
    # clean up (and make space)
    cd /opt && \
    rm -rf /opt/flux

# Ensure we source the environment.
RUN echo ". /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/hpcx-mt-init.sh" >> /home/$(whoami)/.bashrc && \
    echo ". /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/hpcx-mt-init.sh" >> /home/azureuser/.bashrc && \
    echo "hpcx_load" >> /home/$(whoami)/.bashrc && \
    echo "hpcx_load" >> /home/azureuser/.bashrc && \
    echo "FLUX_URI        DEFAULT=local:///opt/run/flux/local" >> ./environment && \
    mv ./environment /etc/security/pam_env.conf
WORKDIR /opt

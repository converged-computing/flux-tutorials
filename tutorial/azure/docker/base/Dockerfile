FROM ubuntu:24.04

# Build command
# docker build -t ghcr.io/converged-computing/flux-tutorials:azure-2404-base .

ENV DEBIAN_FRONTEND=noninteractive
ENV UCX_NET_DEVICES=mlx5_0:1

RUN apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl jq apt-utils wget curl jq \
         build-essential make linux-tools-common linux-tools-$(uname -r)

# Install ORAS client
RUN export VERSION="1.2.2" && \
    curl -LO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz" && \
    mkdir -p oras-install/ && \
    tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/ && \
    mv oras-install/oras /usr/local/bin/ && \
    rm -rf oras_${VERSION}_*.tar.gz oras-install/

WORKDIR /opt
RUN oras pull ghcr.io/converged-computing/rdma-infiniband:ubuntu-24.04-tgz && \
    tar -xzvf MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64.tgz && \
    touch MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64.txt && \
    mv MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64 mlnx && \
    rm MLNX_OFED_LINUX-24.10-1.1.4.0-ubuntu24.04-x86_64.tgz  && \
    cd mlnx && \
    ./mlnxofedinstall --force

#  /etc/init.d/openibd restart

ENV CMAKE=3.23.1
ENV ARCH=x86_64
ENV ORAS_ARCH=amd64

RUN wget https://github.com/openucx/ucx/releases/download/v1.17.0/ucx-1.17.0.tar.gz && \
    tar -xzvf ucx-1.17.0.tar.gz && \
    cd ucx-1.17.0 && \
    ./configure --disable-logging --disable-debug --disable-assertions --disable-params-check --enable-mt --prefix=/usr --enable-examples --without-java --without-go --without-xpmem --without-cuda --with-rc --with-ud --with-dc \
    --with-mlx5-dv --with-verbs --with-ib-hw-tm --with-dm --with-devx && \
    make -j 12 && sudo make install && sudo ldconfig

RUN wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.2.tar.gz && \
    tar -xzvf openmpi-4.1.2.tar.gz && \
    cd openmpi-4.1.2 && \
    ./configure --with-ucx=/usr && \
    make -j 12 && make install && sudo ldconfig

RUN curl -s -L https://github.com/Kitware/CMake/releases/download/v$CMAKE/cmake-3.23.1-linux-x86_64.sh > cmake.sh && \
    sh cmake.sh --prefix=/usr/local --skip-license && \
    apt-get update && \
    apt-get install -y man flex ssh sudo vim luarocks munge lcov ccache lua5.4 \
         valgrind build-essential pkg-config autotools-dev libtool \
         libffi-dev autoconf automake make clang clang-tidy \
         gcc g++ libpam-dev apt-utils lua-posix \
         libsodium-dev libzmq3-dev libczmq-dev libjansson-dev libmunge-dev \
         libncursesw5-dev liblua5.4-dev liblz4-dev libsqlite3-dev uuid-dev \
         libhwloc-dev libs3-dev libevent-dev libarchive-dev \
         libboost-graph-dev libboost-system-dev libboost-filesystem-dev \
         libboost-regex-dev libyaml-cpp-dev libedit-dev uidmap dbus-user-session python3-cffi \
         python3-pip python3-jsonschema locales git

RUN locale-gen en_US.UTF-8

################################################################
## Install Flux and dependencies

RUN mkdir -p /opt/prrte && \
    cd /opt/prrte && \
    git clone https://github.com/openpmix/openpmix.git && \
    git clone https://github.com/openpmix/prrte.git && \
    cd openpmix && \
    git checkout fefaed568f33bf86f28afb6e45237f1ec5e4de93 && \
    ./autogen.pl && \
    ./configure --prefix=/usr --disable-static &&  make install && \
    ldconfig

RUN cd /opt/prrte/prrte && \
    git checkout 477894f4720d822b15cab56eee7665107832921c && \
    ./autogen.pl && \
    ./configure --prefix=/usr && make -j 12 install

# flux security
RUN wget https://github.com/flux-framework/flux-security/releases/download/v0.13.0/flux-security-0.13.0.tar.gz && \
    tar -xzvf flux-security-0.13.0.tar.gz && \
    mv flux-security-0.13.0 /opt/flux-security && \
    cd /opt/flux-security && \
    ./configure --prefix=/usr --sysconfdir=/etc && \
    make -j && make install

# The VMs will share the same munge key
RUN mkdir -p /var/run/munge && \
    dd if=/dev/urandom bs=1 count=1024 > munge.key && \
    mv munge.key /etc/munge/munge.key && \
    chown -R munge /etc/munge/munge.key /var/run/munge && \
    chmod 600 /etc/munge/munge.key

# Flux core
RUN wget https://github.com/flux-framework/flux-core/releases/download/v0.68.0/flux-core-0.68.0.tar.gz && \
    tar -xzvf flux-core-0.68.0.tar.gz && \
    mv flux-core-0.68.0 /opt/flux-core && \
    cd /opt/flux-core && \
    ./configure --prefix=/usr --sysconfdir=/etc --with-flux-security && \
    make clean && \
    make -j 12 && make install

# Flux pmix (must be installed after flux core)
RUN wget https://github.com/flux-framework/flux-pmix/releases/download/v0.5.0/flux-pmix-0.5.0.tar.gz && \
     tar -xzvf flux-pmix-0.5.0.tar.gz && \
     mv flux-pmix-0.5.0 /opt/flux-pmix && \
     cd /opt/flux-pmix && \
     ./configure --prefix=/usr && \
     make -j && \
     make install

# Flux sched
RUN wget https://github.com/flux-framework/flux-sched/releases/download/v0.40.0/flux-sched-0.40.0.tar.gz && \
    tar -xzvf flux-sched-0.40.0.tar.gz && \
    mv flux-sched-0.40.0 /opt/flux-sched && \
    cd /opt/flux-sched && \
    mkdir build && \
    cd build && \
    cmake ../ && make -j && make install && ldconfig && \
    echo "DONE flux build"

# Flux curve.cert
# Ensure we have a shared curve certificate
RUN flux keygen /tmp/curve.cert && \
    mkdir -p /etc/flux/system && \
    cp /tmp/curve.cert /etc/flux/system/curve.cert && \
    chown root /etc/flux/system/curve.cert && \
    chmod o-r /etc/flux/system/curve.cert && \
    chmod g-r /etc/flux/system/curve.cert && \
    # Permissions for imp
    chmod u+s /usr/libexec/flux/flux-imp && \
    chmod 4755 /usr/libexec/flux/flux-imp && \
    # /var/lib/flux needs to be owned by the instance owner
    mkdir -p /var/lib/flux && \
    chown root -R /var/lib/flux && \
    cd /opt

# Ensure the flux uri is exported for all users
# The build should be done as azureuser, but don't assume it.
RUN export FLUX_URI=local:///opt/run/flux/local && \
    echo "export FLUX_URI=local:///opt/run/flux/local" >> /root/.bashrc

# The flux uri needs to be set for all users that logic
RUN echo "FLUX_URI        DEFAULT=local:///opt/run/flux/local" >> ./environment && \
    mv ./environment /etc/security/pam_env.conf

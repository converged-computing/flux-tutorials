#!/bin/bash
#
# Build an Ubuntu 26.04 arm64 AMI with:
#   flux-core   v0.87.0            (release tarball)
#   flux-sched  vsoch@add-hold     (hold/release RPC + custom resource types)
#   flux-quantum converged-computing@add-mock  (CLI plugin, scout, backends)
#
# Version pins are NOT arbitrary:
#   - flux-core 0.87.0 is the version flux-quantum documents/tests against, and
#     the version flux-sched@add-hold was built against.
#   - flux-core 0.87 requires flux-security >= 0.13.0 (configure.ac). The older
#     tutorial images pinned 0.11.0, which will fail ./configure here.
#
# Deliberately NOT installed (present in the hpc7g tutorial image, unnecessary
# for coscheduling tests and slow to build): EFA, openpmix/prrte, flux-pmix,
# singularity, go, oras. Re-add from tf-hpc7g/build/build.sh if you need MPI.

set -euo pipefail

/usr/bin/cloud-init status --wait

export DEBIAN_FRONTEND=noninteractive

# Pins (override with packer vars if desired)
FLUX_CORE_VERSION="${FLUX_CORE_VERSION:-0.87.0}"
FLUX_SECURITY_VERSION="${FLUX_SECURITY_VERSION:-0.15.0}"
FLUX_SCHED_REPO="${FLUX_SCHED_REPO:-https://github.com/vsoch/flux-sched}"
FLUX_SCHED_BRANCH="${FLUX_SCHED_BRANCH:-add-hold}"
FLUX_QUANTUM_REPO="${FLUX_QUANTUM_REPO:-https://github.com/converged-computing/flux-quantum}"
FLUX_QUANTUM_BRANCH="${FLUX_QUANTUM_BRANCH:-add-mock}"

echo "=== base packages ==="
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https ca-certificates curl jq apt-utils wget git net-tools \
    man flex ssh sudo vim luarocks munge lcov ccache lua5.4 \
    build-essential pkg-config autotools-dev libtool \
    libffi-dev autoconf automake make clang \
    gcc g++ libpam-dev lua-posix \
    libsodium-dev libzmq3-dev libczmq-dev libjansson-dev libmunge-dev \
    libncursesw5-dev liblua5.4-dev liblz4-dev libsqlite3-dev uuid-dev \
    libhwloc-dev libs3-dev libevent-dev libarchive-dev \
    libboost-graph-dev libboost-system-dev libboost-filesystem-dev \
    libboost-regex-dev libyaml-cpp-dev libedit-dev \
    uidmap dbus-user-session \
    python3-dev python3-pip python3-cffi python3-yaml \
    cmake \
    nfs-kernel-server nfs-common

sudo locale-gen en_US.UTF-8

# awscli is used by the boot script to discover peer nodes. Baking it in keeps
# first boot fast (and works if the instance has no egress to PyPI).
python3 -m pip install --upgrade awscli --break-system-packages
python3 -m pip install ply --break-system-packages
python3 -m pip install sphinx --break-system-packages

# flux-sched needs cmake >= 3.18; jammy ships 3.22. Kept explicit for parity
# with the tutorial image in case you move to an older base.
cmake --version

echo "=== flux-security ${FLUX_SECURITY_VERSION} ==="
sudo chown -R "$USER" /opt
cd /opt
wget -q "https://github.com/flux-framework/flux-security/releases/download/v${FLUX_SECURITY_VERSION}/flux-security-${FLUX_SECURITY_VERSION}.tar.gz"
tar -xzf "flux-security-${FLUX_SECURITY_VERSION}.tar.gz"
mv "flux-security-${FLUX_SECURITY_VERSION}" /opt/flux-security
cd /opt/flux-security
./configure --prefix=/usr --sysconfdir=/etc
make -j"$(nproc)"
sudo make install
sudo ldconfig

echo "=== shared munge key (baked into the AMI so every node matches) ==="
sudo mkdir -p /var/run/munge
dd if=/dev/urandom bs=1 count=1024 > munge.key 2>/dev/null
sudo mv munge.key /etc/munge/munge.key
sudo chown -R munge /etc/munge/munge.key /var/run/munge
sudo chmod 600 /etc/munge/munge.key

mkdir -p /home/ubuntu/run/flux

echo "=== flux-core ${FLUX_CORE_VERSION} ==="
cd /opt
wget -q "https://github.com/flux-framework/flux-core/releases/download/v${FLUX_CORE_VERSION}/flux-core-${FLUX_CORE_VERSION}.tar.gz"
tar -xzf "flux-core-${FLUX_CORE_VERSION}.tar.gz"
mv "flux-core-${FLUX_CORE_VERSION}" /opt/flux-core
cd /opt/flux-core
./configure --prefix=/usr --sysconfdir=/etc --runstatedir=/run/flux --with-flux-security
make -j"$(nproc)"
sudo make install
sudo ldconfig

echo "=== flux-sched (${FLUX_SCHED_BRANCH}) ==="
cd /opt
git clone --depth 1 -b "${FLUX_SCHED_BRANCH}" "${FLUX_SCHED_REPO}" /opt/flux-sched
cd /opt/flux-sched
git log --oneline -1
mkdir -p build && cd build
# CMAKE_INSTALL_SYSCONFDIR MUST be absolute /etc.
#   flux-sched sets FLUX_RC1_DIR = ${CMAKE_INSTALL_SYSCONFDIR}/flux/rc1.d and
#   includes GNUInstallDirs BEFORE it adopts flux-core's prefix, so a plain
#   `cmake ../` leaves SYSCONFDIR relative ("etc") and installs the fluxion rc1
#   script to /usr/etc/flux/rc1.d -- which flux-core (--sysconfdir=/etc) never
#   reads, so fluxion silently never loads and you stay on sched-simple.
cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_SYSCONFDIR=/etc
make -j"$(nproc)"
sudo make install
sudo ldconfig

# Fail the image build now (not at 3am on a cluster) if fluxion landed wrong.
test -x /etc/flux/rc1.d/01-sched-fluxion \
    || { echo "FATAL: fluxion rc1 script not in /etc/flux/rc1.d"; exit 1; }
echo "OK: fluxion rc1 script installed where flux-core reads it"

echo "=== flux-quantum (${FLUX_QUANTUM_BRANCH}) ==="
git clone --depth 1 -b "${FLUX_QUANTUM_BRANCH}" "${FLUX_QUANTUM_REPO}" /opt/flux-quantum
cd /opt/flux-quantum
git log --oneline -1
# Install into the python that `flux python` uses. Editable so you can
# `git pull` on the node and re-test without rebuilding the image.
sudo flux python -m pip install -e /opt/flux-quantum --break-system-packages \
    || sudo flux python -m pip install --break-system-packages -e /opt/flux-quantum
sudo chown -R ubuntu /opt/flux-quantum

# Verify the plugin actually imports from flux's python (catches a bad install
# now rather than as a confusing "no --quantum options" at submit time).
flux python -c "from flux_quantum.cli import QuantumCLIPlugin; print('OK: flux_quantum importable')"

echo "=== flux curve cert + imp permissions ==="
flux keygen /tmp/curve.cert
sudo mkdir -p /etc/flux/system
sudo cp /tmp/curve.cert /etc/flux/system/curve.cert
sudo chown ubuntu /etc/flux/system/curve.cert
sudo chmod o-r /etc/flux/system/curve.cert
sudo chmod g-r /etc/flux/system/curve.cert
sudo chmod u+s /usr/libexec/flux/flux-imp
sudo chmod 4755 /usr/libexec/flux/flux-imp
sudo mkdir -p /var/lib/flux
sudo chown ubuntu -R /var/lib/flux

# Shared dir used for the quantum session handoff (see start-script.sh). On a
# multi-node instance this is NFS-exported by the lead broker at boot.
sudo mkdir -p /shared
sudo chown ubuntu /shared

echo "=== environment defaults for all users ==="
sudo tee /etc/profile.d/flux-quantum.sh >/dev/null <<'PROFILE'
# flux-quantum: CLI plugin discovery. This dir holds ONLY the discovery shim
# (quantum.py); never point it at the flux_quantum package itself.
export FLUX_CLI_PLUGINPATH=/opt/flux-quantum/cli-plugins

# Token-free mock vendor. Unset (and export real vendor creds) for IBM/Braket.
export FLUX_QUANTUM_MOCK=1

# Session handoff dir. MUST be visible to both the scout and the classical --
# they can land on different nodes, so this points at the shared mount.
export FLUX_QUANTUM_RENDEZVOUS=/shared/qrdv

export FLUX_URI=local:///home/ubuntu/run/flux/local
PROFILE

# clean up sources to keep the image small
cd /opt
# sudo rm -rf /opt/flux-core /opt/flux-security /opt/flux-core-*.tar.gz /opt/flux-security-*.tar.gz
# NOTE: /opt/flux-sched and /opt/flux-quantum are intentionally KEPT so you can
# pull new commits on the node (flux-quantum is an editable install).

echo "=== done: flux + fluxion(add-hold) + flux-quantum(add-mock) ==="
flux version || true

# === done: flux + fluxion(add-hold) + flux-quantum(add-mock) ===
# commands:    		0.87.0
# libflux-core:		0.87.0
# libflux-security:	0.15.0
# build-options:		+systemd+hwloc.api==2.12.0+zmq==4.3.5

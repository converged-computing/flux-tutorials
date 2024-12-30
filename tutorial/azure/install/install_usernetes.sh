#!/bin/bash 

set -euo pipefail

# Uninstall docker on the host
sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin
sudo apt-get purge -y docker-engine docker docker.io
sudo apt autoremove -y
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# Install Usernetes
cd /tmp
echo "START updating cgroups2"
cat /etc/default/grub | grep GRUB_CMDLINE_LINUX=
GRUB_CMDLINE_LINUX=""
sudo sed -i -e 's/^GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
sudo update-grub
sudo mkdir -p /etc/systemd/system/user@.service.d

cat <<EOF | tee delegate.conf
[Service]
Delegate=cpu cpuset io memory pids
EOF
sudo mv ./delegate.conf /etc/systemd/system/user@.service.d/delegate.conf

sudo systemctl daemon-reload
echo "DONE updating cgroups2"

echo "START updating kernel modules"
sudo modprobe ip_tables
tee ./usernetes.conf <<EOF >/dev/null
br_netfilter
vxlan
EOF

sudo mv ./usernetes.conf /etc/modules-load.d/usernetes.conf
sudo systemctl restart systemd-modules-load.service
echo "DONE updating kernel modules"

echo "START 99-usernetes.conf"
echo "net.ipv4.conf.default.rp_filter = 2" > /tmp/99-usernetes.conf
sudo mv /tmp/99-usernetes.conf /etc/sysctl.d/99-usernetes.conf
sudo sysctl --system
echo "DONE 99-usernetes.conf"

echo "START modprobe"
sudo modprobe vxlan
sudo systemctl daemon-reload

# https://github.com/rootless-containers/rootlesskit/blob/master/docs/port.md#exposing-privileged-ports
cp /etc/sysctl.conf ./sysctl.conf
echo "net.ipv4.ip_unprivileged_port_start=0" | tee -a ./sysctl.conf
echo "net.ipv4.conf.default.rp_filter=2" | tee -a ./sysctl.conf
sudo mv ./sysctl.conf /etc/sysctl.conf

sudo sysctl -p
sudo systemctl daemon-reload
echo "DONE modprobe"

echo "START kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/bin/kubectl
echo "DONE kubectl"

# We need to reinstall docker, the one on the VM does not have compose :/
echo "Installing docker"
curl -o install.sh -fsSL https://get.docker.com
chmod +x install.sh
sudo ./install.sh
echo "done installing docker"

echo "Setting up usernetes"
echo "export PATH=/usr/bin:$PATH" >> /home/azureuser/.bashrc
echo "export XDG_RUNTIME_DIR=/home/azureuser/.docker/run" >> /home/azureuser/.bashrc
# This wants to write into run, which is probably OK (under userid)
echo "export DOCKER_HOST=unix:///home/azureuser/.docker/run/docker.sock" >> /home/azureuser/.bashrc

echo "Installing docker user"
sudo loginctl enable-linger azureuser
ls /var/lib/systemd/linger
mkdir -p /home/azureuser/.docker/run

# Install rootless docker
# curl -fsSL https://get.docker.com/rootless | sh
dockerd-rootless-setuptool.sh install
sleep 10
systemctl --user enable docker.service
systemctl --user start docker.service
ln -s /run/user/1000/docker.sock /home/azureuser/.docker/run/docker.sock
docker run hello-world

# Clone usernetes and usernetes-python
git clone https://github.com/rootless-containers/usernetes /home/azureuser/usernetes
git clone https://github.com/converged-computing/usernetes-python /home/azureuser/usernetes-python
cd /home/azureuser/usernetes-python
sudo python3 -m pip install -e .

# 
# At this point we have what we need!

compute_family = "flux-framework-amd64"
compute_node_specs = [
  {
    name_prefix  = "flux"
    machine_arch = "x86-64"
    machine_type = "c2d-standard-112"
    gpu_type     = null
    gpu_count    = 0
    compact      = false
    instances    = 2
    properties   = []
    boot_script  = <<BOOT_SCRIPT
#!/bin/sh

# This is already built into the image
fluxuser=flux
fluxuid=$(id -u flux)

echo "flux ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
printf "flux user identifiers:\n$(id flux)\n"

echo "Flux username: flux"
echo "Flux install root: /usr"

# Generate the flux resource file
# We make this arbitrarily large
sudo rm -rf /etc/flux/system/R
flux R encode --hosts=flux-[001-999] --local > R
sudo mv R /etc/flux/system/R
sudo chown $fluxuser /etc/flux/system/R

# Make the run directories in case not made yet
sudo mkdir -p /run/flux
mkdir -p /opt/run/flux
sudo chown -R flux /run/flux /opt/run/flux

# Write updated broker.toml
cat <<EOF | tee /tmp/broker.toml
# Flux needs to know the path to the IMP executable
[exec]
imp = "/usr/libexec/flux/flux-imp"

# Allow users other than the instance owner (guests) to connect to Flux
# Optionally, root may be given "owner privileges" for convenience
[access]
allow-guest-user = true
allow-root-owner = true

# Point to resource definition generated with flux-R(1).
# Uncomment to exclude nodes (e.g. mgmt, login), from eligibility to run jobs.
[resource]
path = "/etc/flux/system/R"

# Point to shared network certificate generated flux-keygen(1).
# Define the network endpoints for Flux's tree based overlay network
# and inform Flux of the hostnames that will start flux-broker(1).
[bootstrap]
curve_cert = "/etc/flux/system/curve.cert"

# TODO need to look at network interface
# ubuntu does not have eth0
default_port = 8050
default_bind = "tcp://eth0:%p"
default_connect = "tcp://%h:%p"
# This one sometimes is needed
# default_connect = "tcp://%h:%p"

# Rank 0 is the TBON parent of all brokers unless explicitly set with
# parent directives.
# The actual ip addresses (for both) need to be added to /etc/hosts
# of each VM for now.
hosts = [
   { host = "flux-[001-999]" },
]
# Speed up detection of crashed network peers (system default is around 20m)
[tbon]
tcp_user_timeout = "2m"
EOF

sudo mkdir -p /etc/flux/system/conf.d /etc/flux/system/cron.d
sudo mv /tmp/broker.toml /etc/flux/system/conf.d/broker.toml

# Write new service file
cat <<EOF | tee /tmp/flux.service
[Unit]
Description=Flux message broker
Wants=munge.service

[Service]
Type=notify
NotifyAccess=main
TimeoutStopSec=90
KillMode=mixed
ExecStart=/bin/bash -c '/usr/bin/flux broker \
  --config-path=/etc/flux/system/conf.d \
  -Scron.directory=/etc/flux/system/cron.d \
  -Srundir=/opt/run/flux \
  -Sstatedir=/var/lib/flux \
  -Slocal-uri=local:///opt/run/flux/local \
  -Slog-stderr-level=7 \
  -Slog-stderr-mode=local \
  -Sbroker.rc2_none \
  -Sbroker.quorum=1 \
  -Sbroker.sd-notify=1 \
  -Sbroker.quorum-timeout=none \
  -Sbroker.exit-norestart=42 \
  -Scontent.restore=auto'
SyslogIdentifier=flux
ExecReload=/usr/bin/flux config reload
LimitMEMLOCK=infinity
TasksMax=infinity
LimitNPROC=infinity
Restart=always
RestartSec=5s
RestartPreventExitStatus=42
SuccessExitStatus=42
User=flux
RuntimeDirectory=flux
RuntimeDirectoryMode=0755
StateDirectory=flux
StateDirectoryMode=0700
PermissionsStartOnly=true
# ExecStartPre=/usr/bin/loginctl enable-linger flux
# ExecStartPre=bash -c 'systemctl start user@$(id -u flux).service'

#
# Delegate cgroup control to user flux, so that systemd doesn't reset
#  cgroups for flux initiated processes, and to allow (some) cgroup
#  manipulation as user flux.
#
Delegate=yes

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/flux.service /lib/systemd/system/flux.service
sudo mkdir -p /home/flux
sudo chown -R flux /home/flux

# Now setup nfs, etc.
mkdir -p /var/nfs/home || true
chown nobody:nobody /var/nfs/home || true

# /usr/sbin/create-munge-key
# sudo service munge start

# This enables NFS
nfsmounts=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/nfs-mounts" -H "Metadata-Flavor: Google")

if [[ "X$nfsmounts" != "X" ]]; then
    echo "Enabling NFS mounts"
    share=$(echo $nfsmounts | jq -r '.share')
    mountpoint=$(echo $nfsmounts | jq -r '.mountpoint')

    bash -c "sudo echo $share $mountpoint nfs defaults,hard,intr,_netdev 0 0 >> /etc/fstab"
    mount -a
fi

# See the README.md for commands how to set this manually without systemd
sudo systemctl daemon-reload
sudo systemctl restart flux.service
sudo systemctl status flux.service

# Not sure why it's not taking my URI request above!
export FLUX_URI=local:///opt/run/flux/local
echo "export FLUX_URI=local:///opt/run/flux/local" >> /home/$(whoami)/.bashrc
echo "export FLUX_URI=local:///opt/run/flux/local" >> /home/flux/.bashrc

# The flux uri needs to be set for all users that logic
echo "FLUX_URI        DEFAULT=local:///opt/run/flux/local" >> ./environment
sudo mv ./environment /etc/security/pam_env.conf
BOOT_SCRIPT

  },
]
compute_scopes = ["cloud-platform"]

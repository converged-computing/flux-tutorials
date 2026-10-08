#!/bin/bash

# Install AWS client
python3 -m pip install awscli --break-system-packages

# Wait for the count to be up
while [[ $(aws ec2 describe-instances --region ${region} --filters "Name=tag:selector,Values=${selector_name}-selector" | jq .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateDnsName | wc -l) -ne ${desired_size} ]]
do
   echo "Desired count not reached, sleeping."
   sleep 10
done
found_count=$(aws ec2 describe-instances --region ${region} --filters "Name=tag:selector,Values=${selector_name}-selector" | jq .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddress | wc -l)
echo "Desired count $found_count is reached"

# Update the flux config files with our hosts - we need the ones from hostname
hosts=$(aws ec2 describe-instances --region ${region} --filters "Name=tag:selector,Values=${selector_name}-selector" | jq -r .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateDnsName)

# Hack them together into comma separated list, also get the lead broker
NODELIST=""
lead_broker=""
for host in $hosts; do
   barehost=$(python3 -c "print('$host'.split('.')[0])")
   if [[ "$NODELIST" == "" ]]; then
      NODELIST=$barehost
      lead_broker=$barehost
   else
      NODELIST=$NODELIST,$barehost
   fi
done

# Generate the flux resource file
# This is just in case it exists
sudo rm -rf /etc/flux/system/R
flux R encode --hosts=$NODELIST --local > R
sudo mv R /etc/flux/system/R
sudo chown ubuntu /etc/flux/system/R

# Figure out the lead broker, the first in the list
echo "The lead broker is $lead_broker"
host=$(hostname)
echo "The host is $host"

# Make the run directories in case not made yet
sudo mkdir -p /run/flux
mkdir -p /home/ubuntu/run/flux
sudo chown -R ubuntu /run/flux

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

# ubuntu does not have eth0
default_port = 8050
default_bind = "tcp://${ethernet_device}:%p"
default_connect = "tcp://%h:%p"
# This one sometimes is needed
# default_connect = "tcp://%h.ec2.internal:%p"

# Rank 0 is the TBON parent of all brokers unless explicitly set with
# parent directives.
# The actual ip addresses (for both) need to be added to /etc/hosts
# of each VM for now.
hosts = [
   { host = NODELIST },
]
# Speed up detection of crashed network peers (system default is around 20m)
[tbon]
tcp_user_timeout = "2m"
EOF

sudo mkdir -p /etc/flux/system/conf.d

# Replace in hostlist
sed -i 's/NODELIST/"'"$NODELIST"'"/g' /tmp/broker.toml
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
ExecStart=/bin/bash -c '\
  XDG_RUNTIME_DIR=/run/user/$UID \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/bus \
  /usr/bin/flux broker \
  --config-path=/etc/flux/system/conf.d \
  -Scron.directory=/etc/flux/system/cron.d \
  -Srundir=/home/ubuntu/run/flux \
  -Sstatedir=/var/lib/flux \
  -Slocal-uri=local:///home/ubuntu/run/flux/local \
  -Slog-stderr-level=6 \
  -Slog-stderr-mode=local \
  -Sbroker.rc2_none \
  -Sbroker.quorum=1 \
  -Sbroker.exit-norestart=42 \
  -Sbroker.sd-notify=1 \
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
User=ubuntu
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

echo "=== rebuild flux-sched ==="
sudo rm -rf /opt/flux-sched
sudo git clone --depth 1 -b add-hold https://github.com/vsoch/flux-sched /opt/flux-sched
sudo chown -R ubuntu:ubuntu /opt/flux-sched
cd /opt/flux-sched

# no prefix on purpose, cmake forces it to flux-core's prefix
cmake -B build                                                    # watch for "using /usr"
make -C build -j"$(nproc)"                                        # no >/dev/null
sudo make -C build install
sudo ldconfig

# flux-quantum branch and qrmi
rm -rf /opt/flux-quantum
sudo git clone --depth 1 -b braket-hybrid https://github.com/converged-computing/flux-quantum /opt/flux-quantum
chown -R ubuntu:ubuntu /opt/flux-quantum
ln -sfn /opt/flux-quantum/examples/qrmi/ibm-run.sh /usr/local/bin/ibm-run

echo "=== build the jobtap plugin ==="
make -C /opt/flux-quantum/flux_quantum/jobtap \
    || echo "WARNING the jobtap plugin did not build, admission control will be absent"

# somewhere the job manager will find it without an absolute path
sudo mkdir -p /etc/flux/system/jobtap
sudo cp /opt/flux-quantum/flux_quantum/jobtap/quantum.so /etc/flux/system/jobtap/ 2>/dev/null \
    || echo "WARNING no quantum.so to install"

# cores across the whole instance, which is what a pair is budgeted against
TOTAL_CORES=$(( $(nproc) * ${desired_size} ))
echo "=== instance has $TOTAL_CORES cores across ${desired_size} nodes ==="

cat <<EOF | tee /tmp/coschedule.toml
# Reserve for held jobs. Under fcfs a held job is skipped and never reserves,
# which is the one policy where coscheduling silently does not work.
[sched-fluxion-qmanager]
queue-policy = "coschedule"

# Admission control. A pair reserves its cores plus one for the scout, and a
# pair that would exceed the budget is rejected at submit rather than admitted
# and left waiting with a vendor session already open.
#
# preempt_after is deliberately absent. Setting it lets the plugin cancel
# unprotected jobs to make room, and a cancelled job loses its work.
[job-manager]
plugins = [
{ load = "/etc/flux/system/jobtap/quantum.so", conf = { vendors = "ibm,braket,mock,ionq", protect_types = "qpu", total_cores = $TOTAL_CORES, reserve_cores = 0, preempt_after = 5 } }
]
EOF
sudo mv /tmp/coschedule.toml /etc/flux/system/conf.d/coschedule.toml

echo "=== reload so the config takes ==="
# See the README.md for commands how to set this manually without systemd
sudo systemctl daemon-reload
sudo systemctl restart flux.service
sudo systemctl status flux.service
sleep 5

echo "=== verify ==="
flux module list | grep -E "fluxion|sched" || echo "WARNING fluxion is not loaded"
flux jobtap list | grep -q quantum \
    && echo "  jobtap plugin loaded" \
    || echo "WARNING the quantum jobtap plugin did not load, check flux dmesg"
flux config get sched-fluxion-qmanager.queue-policy 2>/dev/null \
    || echo "WARNING could not read back the queue policy"

echo "=== add vendor devices to the graph, before any job runs ==="
flux python -m flux_quantum.populate ibm braket mock ionq --qpus 4 \
    || echo "WARNING populate failed, the first quantum submit will be refused"

# Just sanity check we own everything still
sudo chown -R $USER /home/ubuntu

# These won't take from the build
echo "export LD_LIBRARY_PATH=/opt/amazon/efa/lib:\$LD_LIBRARY_PATH" >> /home/ubuntu/.bashrc
echo "export PATH=/opt/amazon/openmpi/bin:\$PATH" >> /home/ubuntu/.bashrc

# Not sure why it's not taking my URI request above!
export FLUX_URI=local:///home/ubuntu/run/flux/local
echo "export FLUX_URI=local:///home/ubuntu/run/flux/local" >> /home/ubuntu/.bashrc

# Try librdmacm
sudo sysctl net.ipv4.conf.all.accept_local=1
sudo mknod /dev/infiniband/rdma_cm c 231 255
sudo chmod oug+w /dev/infiniband/rdma_cm

# qrmi deps just in case
sudo -u ubuntu -H flux python -m pip install --user --break-system-packages "qrmi[ibm]"
flux exec -r all sh -c 'flux python -m pip install --user --break-system-packages "qrmi[ibm]"'
flux exec -r all flux python -c "import qiskit, qrmi; print(qiskit.__version__)"

# if you need to update while running - this is run as user ubuntu
# flux exec -r all sh -c 'flux python -m pip install --user --break-system-packages "qrmi[ibm]"'
# flux exec -r all flux python -c "import qiskit, qrmi; print(qiskit.__version__)"

sudo mkdir -p /opt/quantum-py
sudo flux python -m pip install --break-system-packages --target /opt/quantum-py "qrmi[ibm]"

# Note this needs python 3.11 or newer
echo "=== qrmi ==="
if sudo flux python -m pip install --break-system-packages "qrmi[ibm]"; then
    flux python -c "
import qrmi, qiskit
from qrmi import ResourceType
print('qrmi ok', qrmi.__file__)
print('qiskit', qiskit.__version__)
print('types', [a for a in dir(ResourceType) if not a.startswith(chr(95))])"
else
    echo "WARNING qrmi did not install. python is $(flux python -c 'import sys; print(sys.version.split()[0])')"
    echo "WARNING qrmi needs 3.11 or newer, so the ibm backend will not work here."
    echo "WARNING the mock vendor is unaffected."
fi

flux python -c "from flux_quantum.cli import QuantumCLIPlugin; print('flux_quantum ok')"

sudo tee /usr/local/bin/flux-quantum-smoke >/dev/null <<'EOF'
#!/bin/bash
# thin wrapper: the test itself lives with the code it tests
exec /opt/flux-quantum/tests/integration/test-system-instance.sh "$@"
EOF
sudo chmod +x /usr/local/bin/flux-quantum-smoke

# Install ibmcloud interface
curl -fsSL https://clis.cloud.ibm.com/install/linux | sudo sh

# How to run
# flux alloc -N2 --exclusive bash /opt/flux-quantum/tests/integration/test-mock-e2e.sh

chmod +x /opt/flux-quantum/examples/qrmi/ibm-run.sh
ln -sf /opt/flux-quantum/examples/qrmi/ibm-run.sh /usr/local/bin/ibm-run

# install rootless docker and start usernetes 
# this needs to be run interactively.
sudo chown -R ubuntu /home/ubuntu

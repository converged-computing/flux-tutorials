#!/bin/bash

# We need the azure client - the instance names aren't predictable
# az vmss run-command --resource-group <resource-group-name> --name <vmss-name> --command "bash -s" --script-path "update_brokers.sh"

template_name=${1}
lead_broker=${2}
template_username=${3:-azureuser}
template_ethernet_device=${4:-eth0}
start_number=$(echo "${lead_broker/flux/""}")
start_number=$(echo "${start_number/000/""}")

# Assume a huge number. This will error with Azure because they 
# eventually dive into alpha numeric, but this works for a small demo
NODELIST=${template_name}000[$start_number-999]

# Write updated resource file
flux R encode --hosts=$NODELIST --local > R
sudo mv R /etc/flux/system/R
sudo chown ${template_username} /etc/flux/system/R

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

default_port = 8050
default_bind = "tcp://${template_ethernet_device}:%p"
default_connect = "tcp://%h:%p"

# Rank 0 is the TBON parent of all brokers unless explicitly set with
# parent directives.
# The actual ip addresses (for both) need to be added to /etc/hosts
# of each VM for now.
hosts = [
   { host = "$NODELIST" },
]
# Speed up detection of crashed network peers (system default is around 20m)
[tbon]
tcp_user_timeout = "2m"
EOF

sudo mv /tmp/broker.toml /etc/flux/system/conf.d/broker.toml

# See the README.md for commands how to set this manually without systemd
sudo systemctl daemon-reload
sudo systemctl restart flux.service
sleep 2
sudo systemctl status flux.service

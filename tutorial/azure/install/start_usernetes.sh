#!/bin/bash 

set -euo pipefail

# The worker count should be one less than the size, the total cluster size minus the control plane (one node)
worker_count=${1}

# The listing of ranks that don't include the control plane (e.g., 1, or 1-N)
ranks="${2}"

export CONTAINER_ENGINE=docker

# This is a system level install
usernetes_root=/home/azureuser/usernetes
cd $usernetes_root

# These are inputs for now
# Get the count of worker nodes (minus the lead broker) - you could also just know this :)
# nodes=$(flux hostlist -x $(hostname) avail)
# counter=(${nodes//","/ })
# count=${#counter[@]}

# Start the control plane and generate the join-command
usernetes start-control-plane --workdir $usernetes_root --worker-count ${worker_count} --serial

# Share the join-command with the workers
flux archive create --name join-command --directory $usernetes_root join-command
flux exec -x 0 -r ${ranks} flux archive extract --name join-command --directory $usernetes_root
flux exec -x 0 -r ${ranks} usernetes start-worker --workdir $usernetes_root

# Go to town!
make -C $usernetes_root sync-external-ip
export KUBECONFIG=/home/azureuser/usernetes/kubeconfig
echo "export KUBECONFIG=/home/azureuser/usernetes/kubeconfig" >> /home/azureuser/.bashrc
kubectl get nodes

# 
# At this point we have what we need!

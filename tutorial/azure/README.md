# Flux on Azure

## Usage

### 1. Build Images

Note that you should [build](build) the images first. Follow the instructions in the README there.

### 2. Deploy Terraform

Check the [start-script.sh](start-script.sh) and variables at the top of [main.tf](main.tf). You'll need to export the image full identifier to the environment:

```bash
export TF_VAR_vm_image_storage_reference=/subscriptions/xxxxxxx/resourceGroups/xxxxx/providers/Microsoft.Compute/images/flux-framework
```

Note that I needed to clone this and do from the cloud shell in the Azure portal.

```bash
git clone https://github.com/converged-computing/flux-tutorials
cd flux-tutorials/tutorial/azure
```

and then:

```bash
make
```

The shell can be buggy - if it seems like it's hanging, it's that terraform is waiting for you to enter "yes." You can type it (despite not seeing it) and press enter and it works every time... 50% of the time. :) I added a command to the Makefile to get around this:

```bash
make apply-approved
```

You can also run each command separately:

```bash
# Terraform init
make init

# Terraform validate
make validate

# Create
make apply

# Destroy
make destroy
```

When it's done, save the public and private key to local files:

```bash
terraform output -json public_key | jq -r > id_azure.pub
terraform output -json private_key | jq -r > id_azure
chmod 600 id_azure*
```

Then get the instance ip addresses from the command line (or portal), and ssh in!

```bash
ip_address=$(az vmss list-instance-public-ips -g terraform-testing -n flux | jq -r .[0].ipAddress)
ssh -i ./id_azure azureuser@${ip_address}
```

To get a difference instance, just use the index (e.g., index 1 is the second instance)

```bash
follower_address=$(az vmss list-instance-public-ips -g terraform-testing -n flux | jq -r .[1].ipAddress)
ssh -i ./id_azure azureuser@${follower_address}
```

Note that if the lead broker doesn't come up as flux_0 (flux with all zeros, Azure is not predicable like that) we will need to update.

```bash
lead_broker=$(az vmss list-instances -g terraform-testing -n flux | jq -r .[0].osProfile.computerName)
echo "The lead broker is ${lead_broker}"
```

#### Scripts

For any of the scripts below, you can run in parallel as follows:

```bash
pip install parallel-ssh
pssh -h hosts.txt -i "command"
```

Here is how you can fix all your brokers:

```bash
for address in $(az vmss list-instance-public-ips -g terraform-testing -n flux | jq -r .[].ipAddress)
 do
   echo "Updating $address"
   scp -i ./id_azure update_brokers.sh azureuser@${address}:/tmp/update_brokers.sh
   ssh -i ./id_azure azureuser@$address "/bin/bash /tmp/update_brokers.sh flux $lead_broker"
done
```

Note that I've also provided a script to install the OSU benchmarks with the same strategy above:

```bash
for address in $(az vmss list-instance-public-ips -g terraform-testing -n flux | jq -r .[].ipAddress)
 do
   echo "Updating $address"
   scp -i ./id_azure install_osu.sh azureuser@${address}:/tmp/install_osu.sh
   ssh -i ./id_azure azureuser@$address "/bin/bash /tmp/install_osu.sh"
done
```

This installs to /usr/local/libexec/osu-benchmarks/mpi. And lammps:

```bash
for address in $(az vmss list-instance-public-ips -g terraform-testing -n flux | jq -r .[].ipAddress)
 do
   echo "Updating $address"
   scp -i ./id_azure install_lammps.sh azureuser@${address}:/tmp/install_lammps.sh
   ssh -i ./id_azure azureuser@$address "/bin/bash /tmp/install_lammps.sh"
done
```



### 3. Checks

Check the cluster status, the overlay status, and try running a job:

```bash
flux resource list
```
```bash
flux run -N 2 hostname
```

### 4. Benchmarks

Try running a benchmark!

#### OSU

```bash
flux run -N2 /usr/local/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce 
flux run -N2 -n2 /usr/local/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_latency
```
```console
# OSU MPI Latency Test v5.8
# Size          Latency (us)
0                       1.57
1                       1.56
2                       1.56
4                       1.56
8                       1.57
16                      1.57
32                      1.70
64                      1.76
128                     1.80
256                     2.31
512                     2.36
1024                    2.52
2048                    2.70
4096                    3.46
8192                    3.96
16384                   5.24
32768                   6.85
65536                   9.18
131072                 14.20
262144                 17.30
524288                 27.94
1048576                50.00
2097152                92.04
4194304               177.34
```

#### LAMMPS

### 4. Cleanup

This should work (but see [debugging](#debugging)).

```bash
make destroy
```

But if not, you can either delete the resource group from the console, or the command line:

```bash
az group delete --name terraform-testing
```

Note that this current build does not have flux-pmix, which might lead to issues with MPI. It's an issue of the VM base being compiled with a libpmix.so that has a different ABI than what flux is expecting. I will be looking into it.

### Debugging

Depending on your environment, terraform (e.g., `make` or `make destroy` doesn't always work. I get this error from the Azure Cloud Shell:

```console
terraform destroy
random_pet.id: Refreshing state... [id=usable-grouper]
random_string.fqdn: Refreshing state... [id=lhppiw]
╷
│ Error: building account: could not acquire access token to parse claims: running Azure CLI: exit status 1: ERROR: Failed to connect to MSI. Please make sure MSI is configured correctly.
│ Get Token request returned: <Response [400]>
│ 
│   with provider["registry.terraform.io/hashicorp/azurerm"],
│   on main.tf line 28, in provider "azurerm":
│   28: provider "azurerm" {
│ 
╵
make: *** [Makefile:22: destroy] Error 1
```

If I open a new cloud shell, it seems to magically go away. But you can also interact with the `az` tool (that does seem to to work) or issue commands via clicking directly in the portal.

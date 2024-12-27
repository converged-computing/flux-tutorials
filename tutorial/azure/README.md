# Flux on Azure

## Usage

### 1. Build Images

Note that you should [build](build) the images first. Follow the instructions in the README there.

### 2. Deploy Terraform

Check the [start-script.sh](start-script.sh) and variables at the top of [main.tf](main.tf). You'll need to export the image full identifier to the environment:

```bash
export TF_VAR_vm_image_storage_reference=/subscriptions/xxxxxxx/resourceGroups/xxxxx/providers/Microsoft.Compute/disks/xxxx
```

and then:

```bash
make
```
Note that I needed to clone this and do from the cloud shell in the Azure portal.

```bash
git clone https://github.com/converged-computing/flux-tutorials
cd flux-tutorials/tutorial/azure
```

You can also run each command separately:

```
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

Then get the flux-0* instance id from the console, and ssh in!

```bash
ssh -i ./id_azure azureuser@52.171.210.230
```

### 3. Checks

Check the cluster status, the overlay status, and try running a job:

```bash
$ flux resource list
```
```bash
$ flux run -N 2 hostname
```

### 4. Cleanup

Depending on your environment, `make destroy` doesn't always work. I get this error from the Azure Cloud Shell:

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

You can either delete the resource group from the console, or the command line:

```bash
az group delete --name terraform-testing
```

Note that this current build does not have flux-pmix, which might lead to issues with MPI. It's an issue of the VM base being compiled with a libpmix.so that has a different ABI than what flux is expecting. I will be looking into it.

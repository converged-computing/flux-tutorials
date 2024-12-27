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

### 3. Checks

Check the cluster status, the overlay status, and try running a job:

```bash
$ flux resource list
```
```bash
$ flux run -N 2 hostname
```

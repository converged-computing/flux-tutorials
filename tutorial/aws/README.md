# Flux on AWS

These Terraform recipes make it easy to deploy an entire cluster with Flux Framework on AWS! We provide recipes with [packer](https://developer.hashicorp.com/packer/install) to build base images for Flux, and the Terraform configuration files to deploy. 

## Usage

First, choose a subdirectory that corresponds to the instance type you are interested in.

### 1. Build Images

Within the subdirectory, you likely want to build your images first. This will use [packer](https://developer.hashicorp.com/packer/install), so you should install it first. You can export your AWS credentials to the environment, but I prefer to use long term credentials, as [described here](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-files.html). Then, saying we want to build the hpc6a: 

```bash
cd tf-hpc6a/build
make
```

You can also look in the makefile to see the respective commands

```bash
packer init .
packer fmt .
packer validate .
packer build flux-build.pkr.hcl
```

The build logic is in the corresponding `build.sh` script, so if you want to add additional stuff (adding an application or other library install) write to the end of that file! Note that during the build you will see blocks of red and green. Red does *not* neccesarily indicate an error. But if you do run into one that stops the build, please [open an issue](https://github.com/converged-computing/flux-tutorials/issues) to ask for help. When the build is complete it will generate what is called an AMI, an "Amazon 
Machine Image" that you can use in the next step.

### 2. Terraform Recipe

We next want to update our terraform recipe, which is the `main.tf` file in each respective subdirectory.
The build step should provide an ami, and you will want to put that into the locals.ami field:

```hcl
locals {
  name      = "flux"
  pwd       = basename(path.cwd)
  region    = "us-east-2"
  # Here!
  ami       = "ami-0ce1a562c586219e6"
  placement = "eks-efa-testing"
...
}
```

For better networking you'll want to make a placement group (the last field shown above), which you can do in the web interface or just:

```bash
aws ec2 create-placement-group --group-name eks-efa-testing --strategy cluster
```

### 3. Deploy with Terraform

Then you can just cd to where the `main.tf` is (e.g., for tf-hpc6a) and:

```bash
cd tf-hpc6a
make
```

You can then shell into any node, and check the status of Flux. I usually grab the instance
name via "Connect" in the portal, but you could likely use the AWS client for this too.

```bash
$ ssh -o 'IdentitiesOnly yes' -i "mykey.pem" ubuntu@ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com
```

### 4. Check Flux

Check the cluster status, the overlay status, and try running a job:

```bash
$ flux resource list
     STATE NNODES   NCORES    NGPUS NODELIST
      free      2      192        0 i-0c13eb61596ffd5c6,i-0f4fe028d6c3036c0
 allocated      0        0        0 
      down      0        0        0
```
```bash
$ flux run -N 2 hostname
i-0c13eb61596ffd5c6
i-0f4fe028d6c3036c0
```

You can look at the startup script logs like this if you need to debug.

```bash
$ cat /var/log/cloud-init-output.log
```

# Flux on Google Cloud

This is a setup akin to Cluster Toolkit (using Terraform) to run Flux on Google Cloud.
Google Cloud does not support any kind of special networking, so we will rely on ethernet. This setup comes also with Singularity and ORAS. You'll need to build from [build-images](build-images). Since we can change the instance on the fly (generally speaking) we just have one build and terraform directory. 

## Usage

### 1. Create Google Service Accounts

Create default application credentials (just once):

```bash
gcloud auth application-default login
```

### 2. Build Base Image

You can build the base VM with [build-images](build-images). This is working with packer (!) so you should look at the main packer HCL files, see if you want to customize anything, and then just:

```bash
make
```

The install script is in [build-images/build.sh](build-images/build.sh), and you can customize it as you like. Note that the Makefile has a setting so that when a command fails, it waits for your response. I recommend that you shell into the VM if this happens to debug, and then do it again when you've found and fixed the issue. If you don't change anything, it should work as is.

### 3. Terraform

Next, cd into [tf](tf) and again open [tf/basic.tfvars](tf/basic.tfvars) to look at the metadata and update anything as needed. I recommend starting at a small scale first.  Then bring it up!

```bash
make
```

When you are done:

```bash
make destroy
```

Note that I had issues with a fully terraform teardown, so I wrote a script that asks for the number of instances, and uses gcloud to supplement.

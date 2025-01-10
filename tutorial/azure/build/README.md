# Build Packer Images

Note that I needed to do this build from a cloud shell, so clone and then:

```bash
git clone https://github.com/converged-computing/flux-tutorials
cd flux-tutorials/tutorial/azure/build
```

And install packer

```bash
wget https://releases.hashicorp.com/packer/1.11.2/packer_1.11.2_linux_amd64.zip
unzip packer_1.11.2_linux_amd64.zip
mkdir -p ./bin
mv ./packer ./bin/
export PATH=$(pwd)/bin:$PATH
```

Get your account information for azure as follows:

```bash
az account show 
```

And export variables in the following format. Note that the resource group needs to actually exist - I created mine in the console UI.

```bash
export AZURE_SUBSCRIPTION_ID=xxxxxxxxx
export AZURE_TENANT_ID=xxxxxxxxxxx
export AZURE_RESOURCE_GROUP_NAME=packer-testing
```

Then build!

```bash
make
```

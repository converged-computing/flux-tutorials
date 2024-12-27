packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

variable client_id {
  type    = string
  default = null
}
variable client_secret {
  type    = string
  default = null
}

variable subscription_id {
  type    = string
  default = env("AZURE_SUBSCRIPTION_ID")
}

variable tenant_id {
  type    = string
  default = env("AZURE_TENANT_ID")
}

variable "image_resource_group_name" {
  description = "Name of the resource group in which the Packer image will be created"
  default = env("AZURE_RESOURCE_GROUP_NAME")
}

# az vm image list --publisher microsoft-dsvm --offer ubuntu-hpc --output table --all
# x64             ubuntu-hpc  microsoft-dsvm  2204-preview-ndv5  microsoft-dsvm:ubuntu-hpc:2204-preview-ndv5:22.04.2023080201  22.04.2023080201
source "azure-arm" "builder" {

  # Uncomment if you aren't using managed identity (in cloud shell)
  # client_id                         = var.client_id
  # client_secret                     = var.client_secret
  # And comment this line (or set to false)
  use_azure_cli_auth                = true
  image_offer                       = "ubuntu-hpc"
  image_publisher                   = "microsoft-dsvm"
  image_sku                         = "2204-preview-ndv5"
  location                          = "southcentralus"
  managed_image_name                = "flux-framework"
  managed_image_resource_group_name = var.image_resource_group_name
  os_type                           = "Linux"
  subscription_id                   = var.subscription_id
  tenant_id                         = var.tenant_id
  # If you aren't sure about size, put something wrong :)
  # You will need to have quota for this family, and the location
  vm_size                           = "Standard_HB120-96rs_v3"
  ssh_username                      = "azureuser"
  azure_tags = {
    "flux" : "0.68.0",
  }
}

build {
  sources = ["source.azure-arm.builder"]
  provisioner "shell" {
    # This will likely run as sudo
    # execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    script = "build.sh"
  }
}

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
  default = null
}

variable tenant_id {
  type    = string
  default = null
}

variable "image_resource_group_name" {
  description = "Name of the resource group in which the Packer image will be created"
  default     = "myPackerImages"
}

# az vm image list --publisher microsoft-dsvm --offer ubuntu-hpc --output table --all
# x64             ubuntu-hpc  microsoft-dsvm  2204-preview-ndv5  microsoft-dsvm:ubuntu-hpc:2204-preview-ndv5:22.04.2023080201  22.04.2023080201
source "azure-arm" "builder" {
  client_id                         = var.client_id
  client_secret                     = var.client_secret
  image_offer                       = "ubuntu-hpc"
  image_publisher                   = "microsoft-dsvm"
  image_sku                         = "2204-preview-ndv5"
  location                          = "southcentralus"
  managed_image_name                = "flux-framework"
  managed_image_resource_group_name = var.image_resource_group_name
  os_type                           = "Linux"
  subscription_id                   = var.subscription_id
  tenant_id                         = var.tenant_id
  vm_size                           = "Standard_DS2_v2"
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

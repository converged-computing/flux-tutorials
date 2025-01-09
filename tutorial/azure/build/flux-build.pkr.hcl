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

# az vm image list
source "azure-arm" "builder" {

  # Uncomment if you aren't using managed identity (in cloud shell)
  # client_id                         = var.client_id
  # client_secret                     = var.client_secret
  # And comment this line (or set to false)
  use_azure_cli_auth                = true
  image_offer                       = "ubuntu-24_04-lts"
  image_publisher                   = "Canonical"
  image_sku                         = "server"
  location                          = "southcentralus"
  managed_image_name                = "flux-framework-2404"
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
    "flux-sched": "0.40.0"
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

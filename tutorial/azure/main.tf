terraform {

  required_version = ">=0.12"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Export to environment:
# export TF_VAR_vm_image_storage_reference="/subscriptions/xxxxxxx/resourceGroups/xxxxx/providers/Microsoft.Compute/disks/xxxx"
# e.g., "/subscriptions/xxxxxxx/resourceGroups/xxxxx/providers/Microsoft.Compute/disks/xxxx"
variable "vm_image_storage_reference" {
  type = string
}

locals {
  admin_user = "azureuser"
  # How many VMs in the VM Scale set
  size         = 2
  name         = "flux"
  disk_size_gb = 100

  # This will be newly created
  resource_group_name = "terraform-testing"

  # Custom Build variables (the packer build)
  vm_image_name           = "flux-framework"
  vm_image_resource_group = "packer-testing"

  # This is also called the SKU
  vm_image_size = "Standard_HB120-96rs_v3"
  location      = "southcentralus"
  tags = {
    flux_core = "0-68-0"
  }
  application_port = 8081
}

resource "random_pet" "id" {}

resource "azurerm_resource_group" "vmss" {
  name     = coalesce(local.resource_group_name, "${local.name}-${random_pet.id.id}")
  location = local.location
  tags     = local.tags
}

resource "random_string" "fqdn" {
  length  = 6
  special = false
  upper   = false
  numeric = false
}

resource "azurerm_virtual_network" "vmss" {
  name                = "vmss-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = local.location
  resource_group_name = azurerm_resource_group.vmss.name
  tags                = local.tags
}

resource "azurerm_subnet" "vmss" {
  name                 = "vmss-subnet"
  resource_group_name  = azurerm_resource_group.vmss.name
  virtual_network_name = azurerm_virtual_network.vmss.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "vmss" {
  name                = "vmss-public-ip"
  location            = local.location
  resource_group_name = azurerm_resource_group.vmss.name
  allocation_method   = "Static"
  domain_name_label   = random_string.fqdn.result
  tags                = local.tags
}

resource "azurerm_lb" "vmss" {
  name                = "vmss-lb"
  location            = local.location
  resource_group_name = azurerm_resource_group.vmss.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vmss.id
  }
  tags = local.tags
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  loadbalancer_id = azurerm_lb.vmss.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "vmss" {
  loadbalancer_id = azurerm_lb.vmss.id
  name            = "ssh-running-probe"
  port            = local.application_port
}

resource "azurerm_lb_rule" "lbnatrule" {
  loadbalancer_id                = azurerm_lb.vmss.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = local.application_port
  backend_port                   = local.application_port
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bpepool.id]
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.vmss.id
}

data "azurerm_resource_group" "image" {
  name = local.vm_image_resource_group
}

data "azurerm_image" "image" {
  name                = local.vm_image_name
  resource_group_name = data.azurerm_resource_group.image.name
}

resource "azapi_resource" "ssh_public_key" {
  type      = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  name      = random_pet.id.id
  location  = azurerm_resource_group.vmss.location
  parent_id = azurerm_resource_group.vmss.id
}

resource "azapi_resource_action" "ssh_public_key_gen" {
  type                   = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  resource_id            = azapi_resource.ssh_public_key.id
  action                 = "generateKeyPair"
  method                 = "POST"
  response_export_values = ["publicKey", "privateKey"]
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  # compute_name_prefix defaults to this
  # Important for startup with flux
  name                = local.name
  resource_group_name = azurerm_resource_group.vmss.name
  location            = azurerm_resource_group.vmss.location
  sku                 = local.vm_image_size
  instances           = local.size
  custom_data         = base64encode(file("start-script.sh"))

  # We want this to be ssh key
  admin_username                  = local.admin_user
  admin_password                  = null
  disable_password_authentication = true
  # This is the default, but I want to put it explicitly
  upgrade_mode = "Manual"

  # This is a standalone image (not a gallery image)
  # "/subscriptions/***/resourceGroups/test/providers/Microsoft.Compute/images/image-0"
  source_image_id = var.vm_image_storage_reference

  data_disk {
    # Logical unit of the disk in the scale set
    lun                  = 0
    caching              = "ReadWrite"
    create_option        = "Empty"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = local.disk_size_gb
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  admin_ssh_key {
    username   = local.admin_user
    public_key = azapi_resource_action.ssh_public_key_gen.output.publicKey
  }

  network_interface {
    name    = local.name
    primary = true

    ip_configuration {
      name      = "ipConfiguration1"
      primary   = true
      subnet_id = azurerm_subnet.vmss.id
      # load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      public_ip_address {
        name = "publicIpAddress1"
      }
    }
  }
  tags = local.tags
}

resource "azurerm_public_ip" "flux" {
  name                = "${local.name}-public-ip"
  location            = local.location
  resource_group_name = azurerm_resource_group.vmss.name
  allocation_method   = "Static"
  domain_name_label   = "${random_string.fqdn.result}-ssh"
  tags                = local.tags
}

resource "azurerm_network_interface" "flux" {
  name                = "${local.name}-nic"
  location            = local.location
  resource_group_name = azurerm_resource_group.vmss.name

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = azurerm_subnet.vmss.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.flux.id
  }
  tags = local.tags
}

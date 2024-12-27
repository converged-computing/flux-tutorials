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

locals {
  admin_user     = "azureuser"
  # How many VMs in the VM Scale set
  size         = 2
  name         = "flux"
  disk_size_gb = 100
  # TODO does it work if these are different (move across groups)
  # Where we want to create the VM scale set
  resource_group_name = "packer-testing"

  # Custom Build variables (the packer build)
  vm_image_name = "flux-framework"
  # e.g., "/subscriptions/xxxxxxx/resourceGroups/xxxxx/providers/Microsoft.Compute/disks/xxxx"
  # vm_image_storage_reference = env("AZURE_VM_IMAGE_STORAGE_REFERENCE")
  vm_image_resource_group = "packer-testing"
  vm_image_size           = "Standard_HB120-96rs_v3"
  location                = "southcentralus"
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

resource "random_password" "password" {
  count  = 0
  length = 20
}

resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = "vmscaleset"
  location            = local.location
  resource_group_name = azurerm_resource_group.vmss.name
  upgrade_policy_mode = "Manual"
  custom_data         = file("start_script.sh")

  sku {
    name     = "Standard_HB120-96rs_v3"
    tier     = "Standard"
    capacity = local.size
  }

  storage_profile_image_reference {
    id = data.azurerm_image.image.id
  }

  # storage_image_reference {
  #    id = local.vm_image_storage_reference
  #  }

  storage_profile_os_disk {
    name              = "flux-framework"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    # disk_size_gb      = 75
  }

  storage_profile_data_disk {
    # Logical unit of the disk in the scale set
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = local.disk_size_gb
  }

  os_profile {
    computer_name_prefix = "vmlab"
    admin_username       = local.admin_user
    admin_password       = null
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = azapi_resource_action.ssh_public_key_gen.output.publicKey
    }
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = azurerm_subnet.vmss.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      primary                                = true
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

#resource "azurerm_virtual_machine" "flux" {
#  name                  = local.vm_image_name
#  location              = local.location
#  resource_group_name   = azurerm_resource_group.vmss.name
#  network_interface_ids = [azurerm_network_interface.flux.id]
#  vm_size               = local.vm_image_size

#  storage_image_reference {
#    publisher = "Canonical"
#    offer     = "UbuntuServer"
#    sku       = "16.04-LTS"
#    version   = "latest"
#  }

#  storage_os_disk {
#    name              = "${local.name}-osdisk"
#    caching           = "ReadWrite"
#    create_option     = "FromImage"
#    managed_disk_type = "Standard_LRS"
#  }

# storage_image_reference {
#    id = local.vm_image_storage_reference
#  }

#  os_profile {
#    computer_name  = local.name
#    admin_username = var.admin_user
#    admin_password = local.admin_password
#  }

#  os_profile_linux_config {
#    disable_password_authentication = true

#    ssh_keys {
#      path     = "/home/azureuser/.ssh/authorized_keys"
#      key_data = azapi_resource_action.ssh_public_key_gen.output.publicKey
#    }
#  }

#  tags = local.tags
#}

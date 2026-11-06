terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

############################################
# DATA SOURCES: risorse già esistenti
############################################

# Informazioni sul contesto corrente (tenant, subscription, principal)
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Resource group esistente
data "azurerm_resource_group" "existing" {
  name = var.existing_rg_name
}

# VNet esistente nel resource group
data "azurerm_virtual_network" "existing" {
  name                = var.existing_vnet_name
  resource_group_name = data.azurerm_resource_group.existing.name
}

# Subnet esistente nella VNet
data "azurerm_subnet" "existing" {
  name                 = var.existing_subnet_name
  virtual_network_name = data.azurerm_virtual_network.existing.name
  resource_group_name  = data.azurerm_resource_group.existing.name
}

# Key Vault esistente (per leggere un segreto)
data "azurerm_key_vault" "existing" {
  name                = var.existing_kv_name
  resource_group_name = data.azurerm_resource_group.existing.name
}

data "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  key_vault_id = data.azurerm_key_vault.existing.id
}

# Log Analytics workspace esistente
data "azurerm_log_analytics_workspace" "existing" {
  name                = var.existing_law_name
  resource_group_name = data.azurerm_resource_group.existing.name
}

############################################
# RISORSE NUOVE che usano i dati letti
############################################

resource "azurerm_network_interface" "vm" {
  name                = "nic-demo-vm"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.existing.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.tags
}

resource "azurerm_linux_virtual_machine" "demo" {
  name                            = "vm-demo-01"
  location                        = data.azurerm_resource_group.existing.location
  resource_group_name             = data.azurerm_resource_group.existing.name
  size                            = "Standard_B2s"
  admin_username                  = "azureadmin"
  admin_password                  = data.azurerm_key_vault_secret.vm_admin_password.value
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.vm.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  tags = local.tags
}

# Diagnostic settings verso il workspace esistente
resource "azurerm_monitor_diagnostic_setting" "vm" {
  name                       = "diag-vm-demo"
  target_resource_id         = azurerm_linux_virtual_machine.demo.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.existing.id

  enabled_metric {
    category = "AllMetrics"
  }
}

# Assegnazione ruolo usando l'object_id del principal corrente
resource "azurerm_role_assignment" "rg_reader" {
  scope                = data.azurerm_resource_group.existing.id
  role_definition_name = "Reader"
  principal_id         = data.azurerm_client_config.current.object_id
}

locals {
  tags = {
    environment  = "demo"
    managed_by   = "terraform"
    subscription = data.azurerm_subscription.current.display_name
  }
}
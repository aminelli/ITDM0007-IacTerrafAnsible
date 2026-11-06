### PROVIDERS

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.72.0"
    }
  }
}

provider "aws" {
  # Configuration options
  
}

# Provider di default (subscription principale)
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id_main
}

# Provider con alias per altre subscription
provider "azurerm" {
  alias           = "hub"
  features {}
  subscription_id = var.subscription_id_hub
}

provider "azurerm" {
  alias           = "spoke"
  features {}
  subscription_id = var.subscription_id_spoke
}

### VARIABILI

variable "subscription_id_main" {
  type = string
  default = "8855b22a-640a-41db-bdc5-byyyyyyyyyy"
}

variable "subscription_id_hub" {
  type = string
  default = "8855b22a-640a-41db-bdc5-bxxxxxxxxxx"
}

variable "subscription_id_spoke" {
  type = string
  default = "8855b22a-640a-41db-bdc5-bzzzzzzzzzz"
}

### risorse Azure

# Usa il provider di default
resource "azurerm_resource_group" "main" {
  name     = "rg-main"
  location = "westeurope"
}

# Usa l'alias "hub"
resource "azurerm_resource_group" "hub" {
  provider = azurerm.hub
  name     = "rg-hub-network"
  location = "westeurope"
}

resource "azurerm_virtual_network" "hub" {
  provider            = azurerm.hub
  name                = "vnet-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = ["10.0.0.0/16"]
}

# Data source su una subscription diversa
data "azurerm_virtual_network" "spoke" {
  provider            = azurerm.spoke
  name                = "vnet-spoke"
  resource_group_name = "rg-spoke-network"
}
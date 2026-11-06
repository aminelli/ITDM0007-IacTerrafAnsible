terraform {
  backend "local" {}

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "5.11.0"

    }
  }
}

provider "azurerm" {
  features {
  }
  subscription_id                 = "00000000-0000-0000-0000-000000000000"
  environment                     = "public"
  use_msi                         = false
  use_cli                         = true
  use_oidc                        = false
  resource_provider_registrations = "none"
}

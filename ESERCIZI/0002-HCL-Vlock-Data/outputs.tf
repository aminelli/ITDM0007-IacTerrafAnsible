output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "subscription_name" {
  value = data.azurerm_subscription.current.display_name
}

output "vnet_address_space" {
  value = data.azurerm_virtual_network.existing.address_space
}

output "subnet_prefixes" {
  value = data.azurerm_subnet.existing.address_prefixes
}

output "vm_private_ip" {
  value = azurerm_network_interface.vm.private_ip_address
}
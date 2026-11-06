output "id"         { value = azurerm_linux_virtual_machine.this.id }
output "private_ip" { value = azurerm_network_interface.this.private_ip_address }

output "public_ip" {
  value = var.enable_public_ip ? azurerm_public_ip.this[0].ip_address : null
}
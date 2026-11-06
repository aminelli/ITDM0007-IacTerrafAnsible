output "rg_name" {
  description = "Nome del gruppo creato"
  value       = azurerm_resource_group.main.name
}

output "rg_id" {
  description = "Id del gruppo creato"
  value       = azurerm_resource_group.main.id
}

# output "rg_name_2" {
#   description = "Nome del gruppo creato"
#   value       = azurerm_resource_group.azgroup2.name
# }
# 
# output "rg_id_2" {
#   description = "Id del gruppo creato"
#   value       = azurerm_resource_group.azgroup2.id
# }

# output "vm_name" {
#   description = "Name of the provisioned virtual machine."
#   value       = azurerm_linux_virtual_machine.main.name
# }
# 
# output "vm_id" {
#   description = "Azure resource ID of the virtual machine."
#   value       = azurerm_linux_virtual_machine.main.id
# }
# 
# output "public_ip_address" {
#   description = "Public IPv4 address assigned to the VM."
#   value       = azurerm_public_ip.main.ip_address
# }
# 
# output "tomcat_url" {
#   description = "HTTP URL for Tomcat. Traffic is unencrypted."
#   value       = "http://${azurerm_public_ip.main.ip_address}:8080/"
# }

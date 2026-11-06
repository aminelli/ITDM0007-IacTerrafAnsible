output "resource_group" {
  value = module.rg.name
}

output "subnet_ids" {
  value = module.network.subnet_ids
}

output "storage_blob_endpoint" {
  value = module.storage.primary_blob_endpoint
}

#output "vm_private_ips" {
#  value = { for k, m in module.vm : k => m.private_ip }
#}

output "vm_private_ips" {
  value = { for k, m in module.vm : k => m.private_ip }
}

output "vm_public_ips" {
  value = { for k, m in module.vm : k => m.public_ip }
}

output "ssh_commands" {
  value = {
    for k, m in module.vm : k => m.public_ip == null ? null : "ssh azureadmin@${m.public_ip}"
  }
}
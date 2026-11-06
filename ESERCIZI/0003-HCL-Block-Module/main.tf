locals {
  name_suffix = "${var.project}-${var.environment}"

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

# 1) Resource group
module "rg" {
  source = "./modules/resource-group"

  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.tags
}


# 2) Rete: dipende dall'output del modulo rg
module "network" {
  source = "./modules/network"

  name                        = "vnet-${local.name_suffix}"
  resource_group_name         = module.rg.name
  location                    = module.rg.location
  address_space               = var.vnet_address_space
  subnets                     = var.subnets
  ssh_allowed_source_prefixes = var.ssh_allowed_source_prefixes
  tags                        = local.tags
}

# # 3) Monitoring
# module "monitoring" {
#   source = "./modules/monitoring"
# 
#   name                = "law-${local.name_suffix}"
#   resource_group_name = module.rg.name
#   location            = module.rg.location
#   retention_in_days   = 30
#   tags                = local.tags
# }
 
# 4) Storage: accessibile solo dalle subnet della VNet
module "storage" {
  source = "./modules/storage"

  name                = "st${var.project}${var.environment}${random_string.suffix.result}"
  resource_group_name = module.rg.name
  location            = module.rg.location
  containers          = ["backups", "logs"]
  allowed_subnet_ids  = values(module.network.subnet_ids)
  tags                = local.tags
}

# 5) VM: un'istanza del modulo per ogni voce di var.vms
module "vm" {
  source   = "./modules/vm"
  for_each = var.vms

  name                       = "vm-${each.key}-${var.environment}"
  resource_group_name        = module.rg.name
  location                   = module.rg.location
  size                       = each.value.size
  subnet_id                  = module.network.subnet_ids[each.value.subnet]
  enable_public_ip           = each.value.enable_public_ip
  admin_ssh_public_key       = var.admin_ssh_public_key
  log_analytics_workspace_id = null #module.monitoring.workspace_id
  tags                       = merge(local.tags, { role = each.key })
}
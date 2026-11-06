# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/publicIPAddresses/pip-vm-web01-dev"
resource "azurerm_public_ip" "pip_vm_web01_dev" {
  allocation_method       = "Static"
  ddos_protection_mode    = "VirtualNetworkInherited"
  ddos_protection_plan_id = null
  domain_name_label       = null
  domain_name_label_scope = null
  edge_zone               = null
  idle_timeout_in_minutes = 4
  ip_tags                 = {}
  ip_version              = "IPv4"
  location                = "northeurope"
  name                    = "pip-vm-web01-dev"
  public_ip_prefix_id     = null
  resource_group_name     = "rg-demo-dev"
  reverse_fqdn            = null
  sku                     = "Standard"
  sku_tier                = "Regional"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web01"
  }
  zones = []
}

# __generated__ by Terraform from "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/publicIPAddresses/pip-vm-db01-dev"
resource "azurerm_public_ip" "pip_vm_db01_dev" {
  allocation_method       = "Static"
  ddos_protection_mode    = "VirtualNetworkInherited"
  ddos_protection_plan_id = null
  domain_name_label       = null
  domain_name_label_scope = null
  edge_zone               = null
  idle_timeout_in_minutes = 4
  ip_tags                 = {}
  ip_version              = "IPv4"
  location                = "northeurope"
  name                    = "pip-vm-db01-dev"
  public_ip_prefix_id     = null
  resource_group_name     = "rg-demo-dev"
  reverse_fqdn            = null
  sku                     = "Standard"
  sku_tier                = "Regional"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "db01"
  }
  zones = []
}

# __generated__ by Terraform from "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-web02-dev"
resource "azurerm_network_interface" "nic_vm_web02_dev" {
  accelerated_networking_enabled = false
  auxiliary_mode                 = null
  auxiliary_sku                  = null
  dns_servers                    = []
  edge_zone                      = null
  internal_dns_name_label        = null
  ip_forwarding_enabled          = false
  location                       = "northeurope"
  name                           = "nic-vm-web02-dev"
  resource_group_name            = "rg-demo-dev"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web02"
  }
  ip_configuration {
    name                          = "internal"
    primary                       = true
    private_ip_address            = "10.10.1.4"
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    public_ip_address_id          = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/publicIPAddresses/pip-vm-web02-dev"
    subnet_id                     = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/virtualNetworks/vnet-demo-dev/subnets/snet-app"
  }
}

# __generated__ by Terraform from "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-db01-dev"
resource "azurerm_network_interface" "nic_vm_db01_dev" {
  accelerated_networking_enabled = false
  auxiliary_mode                 = null
  auxiliary_sku                  = null
  dns_servers                    = []
  edge_zone                      = null
  internal_dns_name_label        = null
  ip_forwarding_enabled          = false
  location                       = "northeurope"
  name                           = "nic-vm-db01-dev"
  resource_group_name            = "rg-demo-dev"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "db01"
  }
  ip_configuration {
    name                          = "internal"
    primary                       = true
    private_ip_address            = "10.10.2.4"
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    public_ip_address_id          = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/publicIPAddresses/pip-vm-db01-dev"
    subnet_id                     = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/virtualNetworks/vnet-demo-dev/subnets/snet-data"
  }
}

# __generated__ by Terraform
resource "azurerm_virtual_network" "vnet_demo_dev" {
  address_space                  = ["10.10.0.0/16"]
  bgp_community                  = null
  dns_servers                    = []
  edge_zone                      = null
  flow_timeout_in_minutes        = 0
  location                       = "northeurope"
  name                           = "vnet-demo-dev"
  private_endpoint_vnet_policies = "Disabled"
  resource_group_name            = "rg-demo-dev"
  subnet = [{
    address_prefixes                              = ["10.10.1.0/24"]
    default_outbound_access_enabled               = true
    delegation                                    = []
    id                                            = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/virtualNetworks/vnet-demo-dev/subnets/snet-app"
    name                                          = "snet-app"
    private_endpoint_network_policies             = "Disabled"
    private_link_service_network_policies_enabled = true
    route_table_id                                = ""
    security_group                                = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkSecurityGroups/nsg-app"
    service_endpoint = [{
      network_identifier = ""
      service            = "Microsoft.Storage"
    }]
    service_endpoint_policy_ids = []
    }, {
    address_prefixes                              = ["10.10.2.0/24"]
    default_outbound_access_enabled               = true
    delegation                                    = []
    id                                            = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/virtualNetworks/vnet-demo-dev/subnets/snet-data"
    name                                          = "snet-data"
    private_endpoint_network_policies             = "Disabled"
    private_link_service_network_policies_enabled = true
    route_table_id                                = ""
    security_group                                = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkSecurityGroups/nsg-data"
    service_endpoint = [{
      network_identifier = ""
      service            = "Microsoft.Storage"
    }]
    service_endpoint_policy_ids = []
  }]
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
  }
}

# __generated__ by Terraform from "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkSecurityGroups/nsg-app"
resource "azurerm_network_security_group" "nsg_app" {
  location            = "northeurope"
  name                = "nsg-app"
  resource_group_name = "rg-demo-dev"
  security_rule = [{
    access                                     = "Allow"
    description                                = ""
    destination_address_prefix                 = "*"
    destination_address_prefixes               = []
    destination_application_security_group_ids = []
    destination_port_range                     = "22"
    destination_port_ranges                    = []
    direction                                  = "Inbound"
    name                                       = "Allow-SSH-Inbound"
    priority                                   = 200
    protocol                                   = "Tcp"
    source_address_prefix                      = ""
    source_address_prefixes                    = ["77.244.183.55"]
    source_application_security_group_ids      = []
    source_port_range                          = "*"
    source_port_ranges                         = []
  }]
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
  }
}

# __generated__ by Terraform from "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/virtualMachines/vm-web02-dev"
resource "azurerm_virtual_machine" "vm_web02_dev" {
  delete_data_disks_on_termination = null
  delete_os_disk_on_termination    = null
  location                         = "northeurope"
  name                             = "vm-web02-dev"
  network_interface_ids            = ["/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-web02-dev"]
  primary_network_interface_id     = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-web02-dev"
  proximity_placement_group_id     = null
  resource_group_name              = "rg-demo-dev"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web02"
  }
  vm_size = "Standard_B2s"
  zones   = []
  boot_diagnostics {
    enabled     = false
    storage_uri = ""
  }
  os_profile {
    admin_password = null # sensitive
    admin_username = "azureadmin"
    computer_name  = "vm-web02-dev"
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP8urLHkU1Ocsbpw4XaNfewEly3+2MDKy2I86OikDPv4 azureadmin@demo"
      path     = "/home/azureadmin/.ssh/authorized_keys"
    }
  }
  storage_image_reference {
    id        = null
    offer     = "ubuntu-24_04-lts"
    publisher = "Canonical"
    sku       = "server"
    version   = "latest"
  }
  storage_os_disk {
    caching                   = "ReadWrite"
    create_option             = "FromImage"
    disk_size_gb              = 30
    image_uri                 = null
    managed_disk_id           = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/disks/vm-web02-dev_disk1_944cd2e04dad4cbe9f8c15c78423e61a"
    managed_disk_type         = "Standard_LRS"
    name                      = "vm-web02-dev_disk1_944cd2e04dad4cbe9f8c15c78423e61a"
    os_type                   = "Linux"
    vhd_uri                   = null
    write_accelerator_enabled = false
  }
}

# __generated__ by Terraform from "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-web01-dev"
resource "azurerm_network_interface" "nic_vm_web01_dev" {
  accelerated_networking_enabled = false
  auxiliary_mode                 = null
  auxiliary_sku                  = null
  dns_servers                    = []
  edge_zone                      = null
  internal_dns_name_label        = null
  ip_forwarding_enabled          = false
  location                       = "northeurope"
  name                           = "nic-vm-web01-dev"
  resource_group_name            = "rg-demo-dev"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web01"
  }
  ip_configuration {
    name                          = "internal"
    primary                       = true
    private_ip_address            = "10.10.1.5"
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    public_ip_address_id          = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/publicIPAddresses/pip-vm-web01-dev"
    subnet_id                     = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/virtualNetworks/vnet-demo-dev/subnets/snet-app"
  }
}

# __generated__ by Terraform from "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/publicIPAddresses/pip-vm-web02-dev"
resource "azurerm_public_ip" "pip_vm_web02_dev" {
  allocation_method       = "Static"
  ddos_protection_mode    = "VirtualNetworkInherited"
  ddos_protection_plan_id = null
  domain_name_label       = null
  domain_name_label_scope = null
  edge_zone               = null
  idle_timeout_in_minutes = 4
  ip_tags                 = {}
  ip_version              = "IPv4"
  location                = "northeurope"
  name                    = "pip-vm-web02-dev"
  public_ip_prefix_id     = null
  resource_group_name     = "rg-demo-dev"
  reverse_fqdn            = null
  sku                     = "Standard"
  sku_tier                = "Regional"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web02"
  }
  zones = []
}

# __generated__ by Terraform from "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/virtualMachines/vm-web01-dev"
resource "azurerm_virtual_machine" "vm_web01_dev" {
  delete_data_disks_on_termination = null
  delete_os_disk_on_termination    = null
  location                         = "northeurope"
  name                             = "vm-web01-dev"
  network_interface_ids            = ["/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-web01-dev"]
  primary_network_interface_id     = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-web01-dev"
  proximity_placement_group_id     = null
  resource_group_name              = "rg-demo-dev"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web01"
  }
  vm_size = "Standard_B2s"
  zones   = []
  boot_diagnostics {
    enabled     = false
    storage_uri = ""
  }
  os_profile {
    admin_password = null # sensitive
    admin_username = "azureadmin"
    computer_name  = "vm-web01-dev"
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP8urLHkU1Ocsbpw4XaNfewEly3+2MDKy2I86OikDPv4 azureadmin@demo"
      path     = "/home/azureadmin/.ssh/authorized_keys"
    }
  }
  storage_image_reference {
    id        = null
    offer     = "ubuntu-24_04-lts"
    publisher = "Canonical"
    sku       = "server"
    version   = "latest"
  }
  storage_os_disk {
    caching                   = "ReadWrite"
    create_option             = "FromImage"
    disk_size_gb              = 30
    image_uri                 = null
    managed_disk_id           = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/disks/vm-web01-dev_disk1_1653d3aa8c58464981fd8af02167d116"
    managed_disk_type         = "Standard_LRS"
    name                      = "vm-web01-dev_disk1_1653d3aa8c58464981fd8af02167d116"
    os_type                   = "Linux"
    vhd_uri                   = null
    write_accelerator_enabled = false
  }
}

# __generated__ by Terraform from "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/virtualMachines/vm-db01-dev"
resource "azurerm_virtual_machine" "vm_db01_dev" {
  delete_data_disks_on_termination = null
  delete_os_disk_on_termination    = null
  location                         = "northeurope"
  name                             = "vm-db01-dev"
  network_interface_ids            = ["/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-db01-dev"]
  primary_network_interface_id     = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-db01-dev"
  proximity_placement_group_id     = null
  resource_group_name              = "rg-demo-dev"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "db01"
  }
  vm_size = "Standard_B2ms"
  zones   = []
  boot_diagnostics {
    enabled     = false
    storage_uri = ""
  }
  os_profile {
    admin_password = null # sensitive
    admin_username = "azureadmin"
    computer_name  = "vm-db01-dev"
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP8urLHkU1Ocsbpw4XaNfewEly3+2MDKy2I86OikDPv4 azureadmin@demo"
      path     = "/home/azureadmin/.ssh/authorized_keys"
    }
  }
  storage_image_reference {
    id        = null
    offer     = "ubuntu-24_04-lts"
    publisher = "Canonical"
    sku       = "server"
    version   = "latest"
  }
  storage_os_disk {
    caching                   = "ReadWrite"
    create_option             = "FromImage"
    disk_size_gb              = 30
    image_uri                 = null
    managed_disk_id           = "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/disks/vm-db01-dev_OsDisk_1_fcc3834246a24a09a132250cabba9bae"
    managed_disk_type         = "Standard_LRS"
    name                      = "vm-db01-dev_OsDisk_1_fcc3834246a24a09a132250cabba9bae"
    os_type                   = "Linux"
    vhd_uri                   = null
    write_accelerator_enabled = false
  }
}

# __generated__ by Terraform
resource "azurerm_storage_account" "stdemodevrzouc" {
  access_tier                       = "Hot"
  account_kind                      = "StorageV2"
  account_replication_type          = "LRS"
  account_tier                      = "Standard"
  allow_nested_items_to_be_public   = false
  allowed_copy_scope                = null
  cross_tenant_replication_enabled  = false
  default_to_oauth_authentication   = false
  dns_endpoint_type                 = "Standard"
  edge_zone                         = null
  https_traffic_only_enabled        = true
  infrastructure_encryption_enabled = false
  is_hns_enabled                    = false
  large_file_share_enabled          = false
  local_user_enabled                = true
  location                          = "northeurope"
  min_tls_version                   = "TLS1_2"
  name                              = "stdemodevrzouc"
  nfsv3_enabled                     = false
  provisioned_billing_model_version = null
  public_network_access             = "Enabled"
  queue_encryption_key_type         = "Service"
  resource_group_name               = "rg-demo-dev"
  sftp_enabled                      = false
  shared_access_key_enabled         = true
  table_encryption_key_type         = "Service"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
  }
  blob_properties {
    change_feed_enabled           = false
    change_feed_retention_in_days = 0
    last_access_time_enabled      = false
    versioning_enabled            = false
  }
  network_rules {
    bypass                     = ["AzureServices"]
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = ["/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/virtualNetworks/vnet-demo-dev/subnets/snet-app", "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/virtualNetworks/vnet-demo-dev/subnets/snet-data"]
  }
  share_properties {
    retention_policy {
      days = 7
    }
  }
}

# __generated__ by Terraform from "/subscriptions/xxxx/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkSecurityGroups/nsg-data"
resource "azurerm_network_security_group" "nsg_data" {
  location            = "northeurope"
  name                = "nsg-data"
  resource_group_name = "rg-demo-dev"
  security_rule = [{
    access                                     = "Allow"
    description                                = ""
    destination_address_prefix                 = "*"
    destination_address_prefixes               = []
    destination_application_security_group_ids = []
    destination_port_range                     = "22"
    destination_port_ranges                    = []
    direction                                  = "Inbound"
    name                                       = "Allow-SSH-Inbound"
    priority                                   = 200
    protocol                                   = "Tcp"
    source_address_prefix                      = ""
    source_address_prefixes                    = ["77.244.183.55"]
    source_application_security_group_ids      = []
    source_port_range                          = "*"
    source_port_ranges                         = []
  }]
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
  }
}

resource "azurerm_resource_group" "res-1" {
  location = "northeurope"
  name     = "rg-demo-dev"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
  }
}
resource "azurerm_linux_virtual_machine" "res-1" {
  admin_username        = "azureadmin"
  location              = "northeurope"
  name                  = "vm-db01-dev"
  network_interface_ids = [azurerm_network_interface.res-1.id]
  os_managed_disk_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/disks/vm-db01-dev_OsDisk_1_fcc3834246a24a09a132250cabba9bae"
  resource_group_name   = azurerm_resource_group.res-1.name
  size                  = "Standard_B2ms"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "db01"
  }
  admin_ssh_key {
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP8urLHkU1Ocsbpw4XaNfewEly3+2MDKy2I86OikDPv4 azureadmin@demo"
    username   = "azureadmin"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    offer     = "ubuntu-24_04-lts"
    publisher = "Canonical"
    sku       = "server"
    version   = "latest"
  }
}
resource "azurerm_linux_virtual_machine" "res-2" {
  admin_username        = "azureadmin"
  location              = "northeurope"
  name                  = "vm-web01-dev"
  network_interface_ids = [azurerm_network_interface.res-2.id]
  os_managed_disk_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/disks/vm-web01-dev_disk1_1653d3aa8c58464981fd8af02167d116"
  resource_group_name   = azurerm_resource_group.res-1.name
  size                  = "Standard_B2s"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web01"
  }
  admin_ssh_key {
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP8urLHkU1Ocsbpw4XaNfewEly3+2MDKy2I86OikDPv4 azureadmin@demo"
    username   = "azureadmin"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    offer     = "ubuntu-24_04-lts"
    publisher = "Canonical"
    sku       = "server"
    version   = "latest"
  }
}
resource "azurerm_linux_virtual_machine" "res-3" {
  admin_username        = "azureadmin"
  location              = "northeurope"
  name                  = "vm-web02-dev"
  network_interface_ids = [azurerm_network_interface.res-3.id]
  os_managed_disk_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/disks/vm-web02-dev_disk1_944cd2e04dad4cbe9f8c15c78423e61a"
  resource_group_name   = azurerm_resource_group.res-1.name
  size                  = "Standard_B2s"
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web02"
  }
  admin_ssh_key {
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP8urLHkU1Ocsbpw4XaNfewEly3+2MDKy2I86OikDPv4 azureadmin@demo"
    username   = "azureadmin"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    offer     = "ubuntu-24_04-lts"
    publisher = "Canonical"
    sku       = "server"
    version   = "latest"
  }
}
resource "azurerm_network_interface" "res-1" {
  location            = "northeurope"
  name                = "nic-vm-db01-dev"
  resource_group_name = azurerm_resource_group.res-1.name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "db01"
  }
  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.res-1.id
    subnet_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-dev/providers/Microsoft.Network/virtualNetworks/vnet-demo-dev/subnets/snet-data"
  }
  depends_on = [
    # One of azurerm_subnet.res-2,azurerm_subnet_network_security_group_association.res-2 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_network_interface" "res-2" {
  location            = "northeurope"
  name                = "nic-vm-web01-dev"
  resource_group_name = azurerm_resource_group.res-1.name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web01"
  }
  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.res-2.id
    subnet_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-dev/providers/Microsoft.Network/virtualNetworks/vnet-demo-dev/subnets/snet-app"
  }
  depends_on = [
    # One of azurerm_subnet.res-1,azurerm_subnet_network_security_group_association.res-1 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_network_interface" "res-3" {
  location            = "northeurope"
  name                = "nic-vm-web02-dev"
  resource_group_name = azurerm_resource_group.res-1.name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web02"
  }
  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.res-3.id
    subnet_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-dev/providers/Microsoft.Network/virtualNetworks/vnet-demo-dev/subnets/snet-app"
  }
  depends_on = [
    # One of azurerm_subnet.res-1,azurerm_subnet_network_security_group_association.res-1 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_network_security_group" "res-1" {
  location            = "northeurope"
  name                = "nsg-app"
  resource_group_name = azurerm_resource_group.res-1.name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
  }
}
resource "azurerm_network_security_rule" "res-1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  direction                   = "Inbound"
  name                        = "Allow-SSH-Inbound"
  network_security_group_name = "nsg-app"
  priority                    = 200
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.res-1.name
  source_address_prefixes     = ["77.244.183.55"]
  source_port_range           = "*"
  depends_on = [
    azurerm_network_security_group.res-1,
  ]
}
resource "azurerm_network_security_group" "res-2" {
  location            = "northeurope"
  name                = "nsg-data"
  resource_group_name = azurerm_resource_group.res-1.name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
  }
}
resource "azurerm_network_security_rule" "res-2" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  direction                   = "Inbound"
  name                        = "Allow-SSH-Inbound"
  network_security_group_name = "nsg-data"
  priority                    = 200
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.res-1.name
  source_address_prefixes     = ["77.244.183.55"]
  source_port_range           = "*"
  depends_on = [
    azurerm_network_security_group.res-2,
  ]
}
resource "azurerm_public_ip" "res-1" {
  allocation_method   = "Static"
  location            = "northeurope"
  name                = "pip-vm-db01-dev"
  resource_group_name = azurerm_resource_group.res-1.name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "db01"
  }
}
resource "azurerm_public_ip" "res-2" {
  allocation_method   = "Static"
  location            = "northeurope"
  name                = "pip-vm-web01-dev"
  resource_group_name = azurerm_resource_group.res-1.name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web01"
  }
}
resource "azurerm_public_ip" "res-3" {
  allocation_method   = "Static"
  location            = "northeurope"
  name                = "pip-vm-web02-dev"
  resource_group_name = azurerm_resource_group.res-1.name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
    role        = "web02"
  }
}
resource "azurerm_virtual_network" "res-1" {
  address_space       = ["10.10.0.0/16"]
  location            = "northeurope"
  name                = "vnet-demo-dev"
  resource_group_name = azurerm_resource_group.res-1.name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
  }
}
resource "azurerm_subnet" "res-1" {
  address_prefixes     = ["10.10.1.0/24"]
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.res-1.name
  virtual_network_name = "vnet-demo-dev"
  service_endpoint {
    service = "Microsoft.Storage"
  }
  depends_on = [
    azurerm_virtual_network.res-1,
  ]
}
resource "azurerm_subnet_network_security_group_association" "res-1" {
  network_security_group_id = azurerm_network_security_group.res-1.id
  subnet_id                 = azurerm_subnet.res-1.id
}
resource "azurerm_subnet" "res-2" {
  address_prefixes     = ["10.10.2.0/24"]
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.res-1.name
  virtual_network_name = "vnet-demo-dev"
  service_endpoint {
    service = "Microsoft.Storage"
  }
  depends_on = [
    azurerm_virtual_network.res-1,
  ]
}
resource "azurerm_subnet_network_security_group_association" "res-2" {
  network_security_group_id = azurerm_network_security_group.res-2.id
  subnet_id                 = azurerm_subnet.res-2.id
}
resource "azurerm_storage_account" "res-1" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = "northeurope"
  name                     = "stdemodevrzouc"
  resource_group_name      = azurerm_resource_group.res-1.name
  tags = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "demo"
  }
}
resource "azurerm_storage_container" "res-1" {
  name               = "backups"
  storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-dev/providers/Microsoft.Storage/storageAccounts/stdemodevrzouc"
  depends_on = [
    # One of azurerm_storage_account.res-1,azurerm_storage_account_queue_properties.res-1,azurerm_storage_account_table_properties.res-1 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_storage_container" "res-2" {
  name               = "logs"
  storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-dev/providers/Microsoft.Storage/storageAccounts/stdemodevrzouc"
  depends_on = [
    # One of azurerm_storage_account.res-1,azurerm_storage_account_queue_properties.res-1,azurerm_storage_account_table_properties.res-1 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_storage_account_queue_properties" "res-1" {
  storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-dev/providers/Microsoft.Storage/storageAccounts/stdemodevrzouc"
  hour_metrics {
    version = "1.0"
  }
  logging {
    delete  = false
    read    = false
    version = "1.0"
    write   = false
  }
  minute_metrics {
    version = "1.0"
  }
  depends_on = [
    azurerm_storage_account.res-1,
    # One of azurerm_storage_account.res-1,azurerm_storage_account_table_properties.res-1 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_storage_account_table_properties" "res-1" {
  storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-dev/providers/Microsoft.Storage/storageAccounts/stdemodevrzouc"
  depends_on = [
    azurerm_storage_account.res-1,
    # One of azurerm_storage_account.res-1,azurerm_storage_account_queue_properties.res-1 (can't auto-resolve as their ids are identical)
  ]
}

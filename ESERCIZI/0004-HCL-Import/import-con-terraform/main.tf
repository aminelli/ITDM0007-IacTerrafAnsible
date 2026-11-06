

import {
    to = azurerm_network_security_group.nsg_data
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkSecurityGroups/nsg-data"
}

import {
    to = azurerm_public_ip.pip_vm_web01_dev
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Network/publicIPAddresses/pip-vm-web01-dev"
}
import {
    to = azurerm_network_security_group.nsg_app
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkSecurityGroups/nsg-app"
}
import {
    to = azurerm_virtual_network.vnet_demo_dev
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Network/virtualNetworks/vnet-demo-dev"
}
import {
    to = azurerm_public_ip.pip_vm_db01_dev
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Network/publicIPAddresses/pip-vm-db01-dev"
}
import {
    to = azurerm_public_ip.pip_vm_web02_dev
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Network/publicIPAddresses/pip-vm-web02-dev"
}
import {
    to = azurerm_storage_account.stdemodevrzouc
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Storage/storageAccounts/stdemodevrzouc"
}
import {
    to = azurerm_network_interface.nic_vm_db01_dev
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-db01-dev"
}
import {
    to = azurerm_network_interface.nic_vm_web02_dev
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-web02-dev"
}
import {
    to = azurerm_network_interface.nic_vm_web01_dev
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Network/networkInterfaces/nic-vm-web01-dev"
}
import {
    to = azurerm_virtual_machine.vm_web02_dev
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/virtualMachines/vm-web02-dev"
}
import {
    to = azurerm_virtual_machine.vm_web01_dev
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/virtualMachines/vm-web01-dev"
}

import {
    to = azurerm_virtual_machine.vm_db01_dev
    id = "/subscriptions/${var.subscription_id}/resourceGroups/rg-demo-dev/providers/Microsoft.Compute/virtualMachines/vm-db01-dev"
}

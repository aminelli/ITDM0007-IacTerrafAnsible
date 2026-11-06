variable "resource_group_name" {
  description = "Name of the Azure resource group."
  type        = string
  default     = "rg-vm-test-tomcat"

  #validation {
  #  condition     = length(var.resource_group_name) > 0 && length(var.resource_group_name) <= 90
  #  error_message = "resource_group_name must be between 1 and 90 characters."
  #}
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "northeurope"
}

variable "vm_name" {
  description = "Name of the Linux virtual machine."
  type        = string
  default     = "vm-tomcat-test"

  validation {
    condition     = length(var.vm_name) >= 1 && length(var.vm_name) <= 64
    error_message = "vm_name must be between 1 and 64 characters."
  }
}

variable "vm_size" {
  description = "Azure VM SKU. Standard_B2s provides 2 vCPU and 4 GiB RAM; check regional quota and availability before deployment."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Linux administrator username. Azure-reserved usernames are not accepted."
  type        = string
  default     = "azureadmin"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.admin_username)) && !contains(["root", "admin", "administrator"], lower(var.admin_username))
    error_message = "Use a valid Linux username that is not root, admin, or administrator."
  }
}

variable "admin_password" {
  description = "Administrator password. Supply through TF_VAR_admin_password or a secret manager; Terraform state and saved plans still contain the value."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 12 && length(var.admin_password) <= 123
    error_message = "admin_password must be between 12 and 123 characters."
  }
}

variable "ssh_source_cidr" {
  description = "Source CIDR permitted to connect to SSH. 0.0.0.0/0 is intentionally not a default and is strongly discouraged."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_source_cidr, 0))
    error_message = "ssh_source_cidr must be a valid CIDR range."
  }
}

variable "tomcat_source_cidr" {
  description = "Source CIDR permitted to reach Tomcat on TCP/8080. Use 0.0.0.0/0 only if public access is intended."
  type        = string

  validation {
    condition     = can(cidrhost(var.tomcat_source_cidr, 0))
    error_message = "tomcat_source_cidr must be a valid CIDR range."
  }
}

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the VM subnet."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "os_disk_storage_account_type" {
  description = "Managed OS disk performance tier."
  type        = string
  default     = "Standard_LRS"

  validation {
    condition     = contains(["Standard_LRS", "Premium_LRS"], var.os_disk_storage_account_type)
    error_message = "os_disk_storage_account_type must be Standard_LRS or Premium_LRS."
  }
}

variable "ubuntu_publisher" {
  description = "Publisher of the Canonical Ubuntu platform image."
  type        = string
  default     = "Canonical"
}

variable "ubuntu_offer" {
  description = "Offer for the explicitly selected Ubuntu 26.04 LTS image."
  type        = string
  default     = "ubuntu-26_04-lts"
}

variable "ubuntu_sku" {
  description = "SKU for the explicitly selected Ubuntu 26.04 LTS image."
  type        = string
  default     = "server"
}

variable "ubuntu_image_version" {
 description = "Image build version. latest selects the newest build within the configured offer and SKU, not a different Ubuntu release."
 type        = string
 default     = "latest"
}

variable "common_tags" {
  description = "Tags applied to Azure resources that support tags."
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "Tomcat"
    ManagedBy   = "Terraform"
  }
}

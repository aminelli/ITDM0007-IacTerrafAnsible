variable "proxmox_endpoint" {
  description = "HTTPS endpoint of the Proxmox VE API, including port 8006."
  type        = string

  validation {
    condition     = can(regex("^https://", var.proxmox_endpoint))
    error_message = "proxmox_endpoint must use HTTPS."
  }
}

variable "proxmox_api_token" {
  description = "Proxmox API token in user@realm!tokenid=secret format."
  type        = string
  sensitive   = true
}

variable "proxmox_ssh_username" {
  description = "SSH account on the Proxmox node used to upload cloud-init snippets."
  type        = string
}

variable "proxmox_ssh_password" {
  description = "Password for the Proxmox node SSH account."
  type        = string
  sensitive   = true
}

variable "packer_image_path" {
  description = "Local path to the QCOW2 image produced by Packer."
  type        = string
}

variable "application_guest_username" {
  description = "Administrative Linux account created on the application VM."
  type        = string
}

variable "application_guest_password" {
  description = "Password for the application VM Linux account."
  type        = string
  sensitive   = true
}

variable "database_guest_username" {
  description = "Administrative Linux account created on the database VM."
  type        = string
}

variable "database_guest_password" {
  description = "Password for the database VM Linux account."
  type        = string
  sensitive   = true
}

variable "ssh_allowed_cidr" {
  description = "IPv4 CIDR allowed to connect to SSH on both VMs. Prefer a trusted /32."
  type        = string

  validation {
    condition     = !strcontains(var.ssh_allowed_cidr, ":") && can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr must be a valid IPv4 CIDR."
  }
}

variable "application_vm" {
  description = "Proxmox placement and IPv4 configuration for the application VM."
  type = object({
    node_name             = string
    vm_id                 = number
    image_datastore_id    = string
    disk_datastore_id     = string
    cloud_init_datastore  = string
    snippets_datastore_id = string
    bridge                = string
    ipv4_address          = string
    ipv4_gateway          = string
    dns_servers           = list(string)
    hostname              = string
    certificate_names     = list(string)
  })

  validation {
    condition = (
      var.application_vm.ipv4_address == "dhcp" &&
      var.application_vm.ipv4_gateway == ""
      ) || (
      var.application_vm.ipv4_address != "dhcp" &&
      !strcontains(var.application_vm.ipv4_address, ":") &&
      can(cidrhost(var.application_vm.ipv4_address, 0)) &&
      !strcontains(var.application_vm.ipv4_gateway, ":") &&
      can(cidrhost("${var.application_vm.ipv4_gateway}/32", 0))
    )
    error_message = "Use ipv4_address = \"dhcp\" with an empty gateway, or a valid IPv4 CIDR and gateway."
  }

  validation {
    condition = (
      can(regex("^[A-Za-z0-9][A-Za-z0-9.-]*$", var.application_vm.hostname)) &&
      length(var.application_vm.certificate_names) > 0 &&
      alltrue([
        for name in var.application_vm.certificate_names :
        can(regex("^[A-Za-z0-9][A-Za-z0-9.-]*$", name)) || can(cidrhost("${name}/32", 0))
      ])
    )
    error_message = "The application hostname must be a DNS-style name and certificate_names must contain valid DNS names or IPv4 addresses."
  }
}

variable "database_vm" {
  description = "Proxmox placement and IPv4 configuration for the dedicated MariaDB VM."
  type = object({
    node_name               = string
    vm_id                   = number
    image_datastore_id      = string
    disk_datastore_id       = string
    cloud_init_datastore    = string
    snippets_datastore_id   = string
    bridge                  = string
    ipv4_address            = string
    ipv4_gateway            = string
    dns_servers             = list(string)
    hostname                = string
    application_source_cidr = string
  })

  validation {
    condition = (
      var.database_vm.ipv4_address == "dhcp" &&
      var.database_vm.ipv4_gateway == ""
      ) || (
      var.database_vm.ipv4_address != "dhcp" &&
      !strcontains(var.database_vm.ipv4_address, ":") &&
      can(cidrhost(var.database_vm.ipv4_address, 0)) &&
      !strcontains(var.database_vm.ipv4_gateway, ":") &&
      can(cidrhost("${var.database_vm.ipv4_gateway}/32", 0))
    )
    error_message = "Use ipv4_address = \"dhcp\" with an empty gateway, or a valid IPv4 CIDR and gateway."
  }

  validation {
    condition = (
      can(regex("^[A-Za-z0-9][A-Za-z0-9.-]*$", var.database_vm.hostname)) &&
      !strcontains(var.database_vm.application_source_cidr, ":") &&
      can(cidrhost(var.database_vm.application_source_cidr, 0))
    )
    error_message = "The database hostname must be a valid DNS-style name and application_source_cidr must be a valid IPv4 CIDR."
  }
}

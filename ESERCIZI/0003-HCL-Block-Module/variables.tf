variable "subscription_id" { type = string }

variable "project" {
  type    = string
  default = "demo"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "northeurope"
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.10.0.0/16"]
}

variable "subnets" {
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
  }))
  default = {
    app = {
      address_prefixes  = ["10.10.1.0/24"]
      service_endpoints = ["Microsoft.Storage"]
    }
    data = {
      address_prefixes  = ["10.10.2.0/24"]
      service_endpoints = ["Microsoft.Storage"]
    }
  }
}

variable "vms" {
  description = "VM da creare: una chiamata al modulo per ciascuna"
  type = map(object({
    size   = string
    subnet = string
    enable_public_ip = optional(bool, true)
  }))
  default = {
    web01 = { size = "Standard_B2s", subnet = "app" }
    web02 = { size = "Standard_B2s", subnet = "app" }
    db01  = { size = "Standard_B2ms", subnet = "data" }
  }
}

variable "ssh_allowed_source_prefixes" {
  description = "IP/CIDR autorizzati a connettersi in SSH (es. il tuo IP pubblico /32)"
  type        = list(string)

  validation {
    condition     = !contains(var.ssh_allowed_source_prefixes, "*") && !contains(var.ssh_allowed_source_prefixes, "0.0.0.0/0")
    error_message = "Non aprire SSH a tutta Internet: indica il tuo IP o la tua rete."
  }
}

variable "admin_ssh_public_key" {
  type = string
}
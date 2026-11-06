variable "subscription_id" {
  type = string
}

variable "existing_rg_name" {
  type    = string
  default = "rg-network-prod"
}

variable "existing_vnet_name" {
  type    = string
  default = "vnet-prod"
}

variable "existing_subnet_name" {
  type    = string
  default = "snet-workload"
}

variable "existing_kv_name" {
  type    = string
  default = "kv-shared-prod"
}

variable "existing_law_name" {
  type    = string
  default = "law-shared-prod"
}
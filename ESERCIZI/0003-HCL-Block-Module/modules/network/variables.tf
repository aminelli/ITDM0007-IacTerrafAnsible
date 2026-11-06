variable "name"                { type = string }
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "address_space"       { type = list(string) }
variable "subnets" {
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
  }))
}
variable "tags" {
  type    = map(string)
  default = {}
}

variable "ssh_allowed_source_prefixes" {
  type    = list(string)
  default = []
}
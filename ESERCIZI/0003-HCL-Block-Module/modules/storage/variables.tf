
# variables.tf
variable "name"                { type = string }
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "containers" {
  type    = list(string)
  default = []
}
variable "allowed_subnet_ids" {
  type    = list(string)
  default = []
}
variable "tags" {
  type    = map(string)
  default = {}
}


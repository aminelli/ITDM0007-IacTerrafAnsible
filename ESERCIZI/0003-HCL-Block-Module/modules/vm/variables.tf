# variables.tf
variable "name"                       { type = string }
variable "resource_group_name"        { type = string }
variable "location"                   { type = string }
variable "size"                       { type = string }
variable "subnet_id"                  { type = string }
variable "admin_ssh_public_key"       { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "admin_username" {
  type    = string
  default = "azureadmin"
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "enable_public_ip" {
  type    = bool
  default = true
}


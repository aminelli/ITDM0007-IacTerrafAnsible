terraform {
  required_version = "= 1.17.1"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.120.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token

  ssh {
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    agent    = false
  }
}

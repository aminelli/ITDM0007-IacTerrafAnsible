locals {
  ubuntu_image_url         = "https://cloud-images.ubuntu.com/releases/resolute/release/ubuntu-26.04-server-cloudimg-amd64.img"
  ubuntu_image_sha256      = "5645d0318ad21f643ebb1ac4567514620e9893380b07b0201fda163baa5b7eb5"
  application_server_names = join(" ", var.application_vm.certificate_names)
  certificate_subject      = var.application_vm.certificate_names[0]
  certificate_san_extension = join(",", [
    for name in var.application_vm.certificate_names :
    can(cidrhost("${name}/32", 0)) ? "IP:${name}" : "DNS:${name}"
  ])
}

resource "proxmox_download_file" "application_ubuntu_image" {
  content_type       = "import"
  datastore_id       = var.application_vm.image_datastore_id
  file_name          = "ubuntu-26.04-application-cloudimg-amd64.qcow2"
  node_name          = var.application_vm.node_name
  url                = local.ubuntu_image_url
  checksum           = local.ubuntu_image_sha256
  checksum_algorithm = "sha256"
}

resource "proxmox_download_file" "database_ubuntu_image" {
  content_type       = "import"
  datastore_id       = var.database_vm.image_datastore_id
  file_name          = "ubuntu-26.04-database-cloudimg-amd64.qcow2"
  node_name          = var.database_vm.node_name
  url                = local.ubuntu_image_url
  checksum           = local.ubuntu_image_sha256
  checksum_algorithm = "sha256"
}

resource "proxmox_virtual_environment_file" "application_cloud_config" {
  content_type = "snippets"
  datastore_id = var.application_vm.snippets_datastore_id
  node_name    = var.application_vm.node_name

  source_raw {
    file_name = "${var.application_vm.hostname}.cloud-config.yaml"
    data = templatefile("${path.module}/cloud-init/application.yaml.tftpl", {
      certificate_san_extension = local.certificate_san_extension
      certificate_subject       = local.certificate_subject
      application_server_names  = local.application_server_names
      ssh_allowed_cidr          = var.ssh_allowed_cidr
    })
  }
}

resource "proxmox_virtual_environment_file" "database_cloud_config" {
  content_type = "snippets"
  datastore_id = var.database_vm.snippets_datastore_id
  node_name    = var.database_vm.node_name

  source_raw {
    file_name = "${var.database_vm.hostname}.cloud-config.yaml"
    data = templatefile("${path.module}/cloud-init/database.yaml.tftpl", {
      application_source_cidr = var.database_vm.application_source_cidr
      ssh_allowed_cidr        = var.ssh_allowed_cidr
    })
  }
}

resource "proxmox_virtual_environment_vm" "application" {
  name        = var.application_vm.hostname
  description = "Ubuntu 26.04 LTS application VM managed by Terraform"
  node_name   = var.application_vm.node_name
  vm_id       = var.application_vm.vm_id
  tags        = ["terraform", "ubuntu", "application"]

  agent {
    enabled = false
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = var.application_vm.disk_datastore_id
    import_from  = proxmox_download_file.application_ubuntu_image.id
    interface    = "scsi0"
    size         = 20
  }

  initialization {
    datastore_id      = var.application_vm.cloud_init_datastore
    user_data_file_id = proxmox_virtual_environment_file.application_cloud_config.id

    ip_config {
      ipv4 {
        address = var.application_vm.ipv4_address
        gateway = var.application_vm.ipv4_gateway == "" ? null : var.application_vm.ipv4_gateway
      }
    }

    dynamic "dns" {
      for_each = length(var.application_vm.dns_servers) == 0 ? [] : [true]

      content {
        servers = var.application_vm.dns_servers
      }
    }

    user_account {
      username = var.application_guest_username
      password = var.application_guest_password
    }
  }

  network_device {
    bridge = var.application_vm.bridge
  }

  operating_system {
    type = "l26"
  }
}

resource "proxmox_virtual_environment_vm" "database" {
  name        = var.database_vm.hostname
  description = "Ubuntu 26.04 LTS MariaDB VM managed by Terraform"
  node_name   = var.database_vm.node_name
  vm_id       = var.database_vm.vm_id
  tags        = ["terraform", "ubuntu", "database"]

  lifecycle {
    precondition {
      condition     = var.application_vm.vm_id != var.database_vm.vm_id
      error_message = "The application and database VM IDs must be different."
    }

    precondition {
      condition     = var.application_vm.hostname != var.database_vm.hostname
      error_message = "The application and database VM hostnames must be different."
    }
  }

  agent {
    enabled = false
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = var.database_vm.disk_datastore_id
    import_from  = proxmox_download_file.database_ubuntu_image.id
    interface    = "scsi0"
    size         = 20
  }

  initialization {
    datastore_id      = var.database_vm.cloud_init_datastore
    user_data_file_id = proxmox_virtual_environment_file.database_cloud_config.id

    ip_config {
      ipv4 {
        address = var.database_vm.ipv4_address
        gateway = var.database_vm.ipv4_gateway == "" ? null : var.database_vm.ipv4_gateway
      }
    }

    dynamic "dns" {
      for_each = length(var.database_vm.dns_servers) == 0 ? [] : [true]

      content {
        servers = var.database_vm.dns_servers
      }
    }

    user_account {
      username = var.database_guest_username
      password = var.database_guest_password
    }
  }

  network_device {
    bridge = var.database_vm.bridge
  }

  operating_system {
    type = "l26"
  }
}

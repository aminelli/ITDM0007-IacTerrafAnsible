packer {
  required_version = ">= 1.10.0, < 2.0.0"

  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "= 1.1.8"
    }
  }
}

source "qemu" "ubuntu_2604" {
  iso_url      = var.ubuntu_cloud_image_url
  iso_checksum = "sha256:${var.ubuntu_cloud_image_sha256}"
  disk_image   = true

  output_directory = "output/ubuntu-2604-base"
  vm_name          = "ubuntu-2604-base"
  format           = "qcow2"
  disk_size        = "20G"
  accelerator      = "tcg"
  headless         = true

  cd_label = "cidata"
  cd_content = {
    "user-data" = templatefile("${path.root}/cloud-init/user-data.pkrtpl.hcl", {
      build_username      = var.build_username
      build_password_hash = var.build_password_hash
    })
    "meta-data" = "instance-id: packer-ubuntu-2604\nlocal-hostname: packer-ubuntu-2604\n"
  }

  ssh_username     = var.build_username
  ssh_password     = var.build_password
  ssh_timeout      = "45m"
  shutdown_command = "sudo sh -c 'usermod --password \"!\" ${var.build_username} && (gpasswd -d ${var.build_username} sudo || true) && usermod --shell /usr/sbin/nologin ${var.build_username} && rm -rf /home/${var.build_username}/.ssh && shutdown -P now'"
}

build {
  name    = "ubuntu-2604-qcow2"
  sources = ["source.qemu.ubuntu_2604"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent",
      "sudo cloud-init clean --logs --seed",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id"
    ]
  }
}

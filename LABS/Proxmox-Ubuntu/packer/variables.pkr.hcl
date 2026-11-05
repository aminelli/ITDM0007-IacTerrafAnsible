variable "ubuntu_cloud_image_url" {
  description = "Official Ubuntu 26.04 amd64 cloud image; Packer boots this disk image instead of installing from an ISO."
  type        = string
  default     = "https://cloud-images.ubuntu.com/releases/resolute/release/ubuntu-26.04-server-cloudimg-amd64.img"
}

variable "ubuntu_cloud_image_sha256" {
  description = "SHA-256 checksum of the exact Ubuntu cloud image."
  type        = string
  default     = "5645d0318ad21f643ebb1ac4567514620e9893380b07b0201fda163baa5b7eb5"

  validation {
    condition     = can(regex("^[0-9a-f]{64}$", var.ubuntu_cloud_image_sha256))
    error_message = "The Ubuntu cloud image SHA-256 value must be a 64-character lowercase digest."
  }
}

variable "build_username" {
  description = "Temporary user created only while Packer builds the image."
  type        = string
  default     = "packer"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]*[$]?$", var.build_username))
    error_message = "The build username must be a valid Linux account name."
  }
}

variable "build_password" {
  description = "Temporary plaintext password used by Packer SSH during the build."
  type        = string
  sensitive   = true
}

variable "build_password_hash" {
  description = "SHA-512 crypt password hash matching build_password, supplied to cloud-init."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^\\$6\\$", var.build_password_hash))
    error_message = "The build password hash must be a SHA-512 crypt hash starting with $6$."
  }
}

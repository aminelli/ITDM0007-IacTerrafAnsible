#cloud-config
users:
  - default
  - name: ${build_username}
    gecos: Temporary Packer build account
    groups:
      - sudo
    shell: /bin/bash
    sudo:
      - ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    passwd: "${build_password_hash}"
ssh_pwauth: true
chpasswd:
  expire: false

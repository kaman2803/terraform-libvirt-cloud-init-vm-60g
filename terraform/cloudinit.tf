resource "libvirt_cloudinit_disk" "ubuntu_init" {
  name      = "ubuntu-cloud-vm-01-init"
  user_data = file("${path.module}/../cloud-init/user-data")
  meta_data = file("${path.module}/../cloud-init/meta-data")
}

resource "libvirt_volume" "ubuntu_init_volume" {
  name = "ubuntu-cloud-vm-01-init.iso"
  pool = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.ubuntu_init.path
    }
  }

  target = {
    format = {
      type = "iso"
    }
  }
}
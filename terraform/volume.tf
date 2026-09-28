resource "libvirt_volume" "ubuntu_os" {
  name = "ubuntu-cloud-vm-01.qcow2"
  pool = "default"

  capacity      = 10
  capacity_unit = "GiB"

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = "/var/lib/libvirt/images/base/noble-server-cloudimg-amd64.img"

    format = {
      type = "qcow2"
    }
  }
}

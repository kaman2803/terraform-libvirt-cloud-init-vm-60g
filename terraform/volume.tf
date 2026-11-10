resource "libvirt_volume" "vm_disk_60g" {
  for_each = local.vms

  name     = "${each.value.hostname}.qcow2"
  pool     = var.storage_pool
  capacity = each.value.disk_gb * 1024 * 1024 * 1024

  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = abspath("${path.module}/../images/ubuntu-noble-60g.qcow2")
    }
  }
}
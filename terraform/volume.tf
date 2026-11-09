resource "libvirt_volume" "vm_disk_20g" {
  for_each = local.vms

  name     = "${each.value.hostname}-20g.qcow2"
  pool     = var.storage_pool
  capacity = each.value.disk_gb * 1024 * 1024 * 1024

  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = abspath("${path.module}/../images/ubuntu-noble-20g.qcow2")
    }
  }
}

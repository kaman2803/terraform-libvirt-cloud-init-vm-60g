resource "libvirt_cloudinit_disk" "vm_init" {
  for_each = local.cloudinit

  name      = "${each.key}-init"
  user_data = each.value.user_data
  meta_data = each.value.meta_data
}

resource "libvirt_volume" "vm_init_iso" {
  for_each = local.cloudinit

  name = "${each.key}-init.iso"
  pool = var.cloudinit_pool

  create = {
    content = {
      url = libvirt_cloudinit_disk.vm_init[each.key].path
    }
  }

  target = {
    format = {
      type = "iso"
    }
  }
}

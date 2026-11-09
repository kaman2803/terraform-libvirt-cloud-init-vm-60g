resource "libvirt_domain" "vm" {
  for_each = local.vms

  name        = each.value.hostname
  type        = "kvm"
  memory      = each.value.memory
  memory_unit = "MiB"
  vcpu        = each.value.vcpu
  running     = true

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }

  sec_label = [
    {
      type    = "dynamic"
      model   = "apparmor"
      relabel = "yes"
    },
    {
      type    = "dynamic"
      model   = "dac"
      relabel = "yes"
    }
  ]

  devices = {
    disks = [
      {
        # Disque système Ubuntu autonome de 20 GiB
        driver = {
          name  = "qemu"
          type  = "qcow2"
          cache = "none"
        }

        source = {
          file = {
            file = libvirt_volume.vm_disk_20g[each.key].path
          }
        }

        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        # ISO Cloud-Init propre à chaque VM
        device = "cdrom"

        source = {
          file = {
            file = libvirt_volume.vm_init_iso[each.key].path
          }
        }

        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]

    consoles = [
      {
        type = "pty"

        target = {
          type = "serial"
          port = 0
        }
      }
    ]

    interfaces = [
      {
        type = "network"

        source = {
          network = {
            network = var.network_name
          }
        }

        model = {
          type = "virtio"
        }
      }
    ]
  }
}

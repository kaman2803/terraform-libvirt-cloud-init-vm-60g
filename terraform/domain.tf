resource "libvirt_domain" "ubuntu_cloud_vm" {
  name        = "ubuntu-cloud-vm-01"
  type        = "kvm"
  memory      = 2048
  memory_unit = "MiB"
  vcpu        = 2

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
        # Disque système Ubuntu
        driver = {
          name  = "qemu"
          type  = "qcow2"
          cache = "none"
        }

        source = {
          file = {
            file = "/var/lib/libvirt/images/ubuntu-cloud-vm-01.qcow2"
          }
        }

        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        # ISO Cloud-Init
        device = "cdrom"

        source = {
          file = {
            file = "/var/lib/libvirt/images/ubuntu-cloud-vm-01-init.iso"
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
            network = "default"
          }
        }

        model = {
          type = "virtio"
        }
      }
    ]
  }
}
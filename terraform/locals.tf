locals {
  vm_count = length(var.vms)

  vm_names = keys(var.vms)

  common_tags = {
    project     = var.project_name
    environment = "kgoumou"
    managed_by  = "terraform"
  }

  vms = var.vms

  cloudinit = {
    for name, vm in local.vms :
    name => {
      meta_data = templatefile("${path.module}/../templates/meta-data.yaml.tftpl", {
        instance_id = name
        hostname    = vm.hostname
      })

      user_data = templatefile("${path.module}/../templates/user-data.yaml.tftpl", {
        ssh_username   = var.ssh_username
        ssh_public_key = var.ssh_public_key
      })
    }
  }
}

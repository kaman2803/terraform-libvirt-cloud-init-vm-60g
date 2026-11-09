variable "project_name" {
  description = "Nom du projet Terraform"
  type        = string
}

variable "libvirt_uri" {
  description = "URI de connexion à l'hyperviseur libvirt"
  type        = string
}

variable "storage_pool" {
  description = "Pool de stockage des disques des VM"
  type        = string
}

variable "cloudinit_pool" {
  description = "Pool de stockage des ISO Cloud-Init"
  type        = string
}

variable "network_name" {
  description = "Réseau libvirt utilisé par les VM"
  type        = string
}

variable "base_image_path" {
  description = "Chemin de l'image Ubuntu Cloud source"
  type        = string
}

variable "ssh_username" {
  description = "Utilisateur Linux commun aux VM"
  type        = string
}

variable "ssh_public_key" {
  description = "Clé publique SSH commune aux VM"
  type        = string
}

variable "vms" {
  description = "Configuration des machines virtuelles à déployer"

  type = map(object({
    hostname = string
    vcpu     = number
    memory   = number
    disk_gb  = number
  }))

  validation {
    condition = alltrue([
      for vm in values(var.vms) :
      vm.vcpu > 0 &&
      vm.memory >= 512 &&
      vm.disk_gb >= 5
    ])

    error_message = "Chaque VM doit avoir au moins 1 vCPU, 512 Mo de RAM et 5 Go de disque."
  }
}

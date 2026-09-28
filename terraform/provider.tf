provider "libvirt" {
  uri = "qemu+ssh://kaman-goumou@192.168.122.1/system?sshauth=privkey&keyfile=/home/kaman/.ssh/terraform_libvirt_ed25519"
}

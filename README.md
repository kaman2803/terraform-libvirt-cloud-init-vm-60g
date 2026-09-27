# Automatisation de VM KVM/libvirt avec Terraform et Cloud-Init

## 1. Présentation du projet

Ce projet a pour objectif d'automatiser le déploiement et la configuration initiale de machines virtuelles sur une infrastructure KVM/libvirt à l'aide de Terraform et Cloud-Init.

### Architecture

- **Machine d'administration** : `srv01-admin`
- **Système d'exploitation** : Ubuntu Server 24.04.5 LTS
- **Serveur KVM/libvirt cible** : `192.168.122.1`
- **Infrastructure as Code** : Terraform
- **Initialisation des VM** : Cloud-Init
- **Virtualisation** : KVM/libvirt

## 2. Objectifs du projet

- Automatiser le déploiement des machines virtuelles avec Terraform.
- Utiliser des Ubuntu Cloud Images comme modèles de VM.
- Automatiser la configuration initiale des VM avec Cloud-Init.
- Configurer automatiquement l'accès SSH.
- Rendre le déploiement reproductible.
- Valider chaque étape du déploiement.
- Documenter progressivement les commandes exécutées, les résultats et les éventuels problèmes rencontrés.

## 3. Architecture du projet

```text
terraform-libvirt-cloud-init-vm-automation/
├── README.md
├── .gitignore
├── terraform/
├── cloud-init/
├── images/
└── scripts/
```

## 4. Outils nécessaires à l'automatisation

L'environnement d'administration `srv01-admin` doit disposer des outils nécessaires pour préparer les images, générer les données Cloud-Init et piloter l'environnement KVM/libvirt.

### 4.1 Vérification de l'environnement existant

Avant toute installation, l'environnement d'administration a été vérifié afin d'identifier les outils déjà présents et ceux qui étaient manquants.

La commande utilisée pour réaliser cet audit est :

```bash
echo "===== TERRAFORM ====="
terraform version

echo
echo "===== ANSIBLE ====="
ansible --version | head -n 2

echo
echo "===== CLOUD-INIT ====="
cloud-init --version

echo
echo "===== CLOUD-IMAGE-UTILS ====="
dpkg -l cloud-image-utils 2>/dev/null | grep '^ii' || echo "cloud-image-utils : non installé"

echo
echo "===== LIBVIRT CLIENT ====="
command -v virsh || echo "virsh : non installé"

echo
echo "===== VIRT-INSTALL ====="
command -v virt-install || echo "virt-install : non installé"

echo
echo "===== SSH ====="
ssh -V 2>&1

echo
echo "===== GIT ====="
git --version
```

Résultat de l'audit :

| Outil               | Version / état |
| ------------------- | -------------- |
| Terraform           | 1.16.3         |
| Ansible             | 2.16.3         |
| Cloud-Init          | 26.1           |
| `cloud-image-utils` | Non installé   |
| `virsh`             | Non installé   |
| `virt-install`      | Non installé   |
| OpenSSH             | 9.6p1          |
| Git                 | 2.43.0         |

Terraform indiquait également qu'une version 1.16.4 était disponible. Aucune mise à jour n'a été effectuée, car Terraform 1.16.3 était déjà fonctionnel pour le projet.

### 4.2 Vérification de la disponibilité des paquets

Avant installation, la disponibilité des paquets dans les dépôts Ubuntu 24.04 ARM64 a été vérifiée :

```bash
apt-cache policy libvirt-clients virtinst cloud-image-utils
```

Les versions candidates identifiées étaient :

```text
libvirt-clients    10.0.0-2ubuntu8.17
virtinst            1:4.1.0-3ubuntu0.1
cloud-image-utils   0.33-1
```

Les dépendances principales ont ensuite été vérifiées :

```bash
apt-cache depends libvirt-clients virtinst cloud-image-utils
```

Cette vérification a notamment confirmé :

- `libvirt-clients` fournit le client libvirt nécessaire à l'utilisation de `virsh` ;
- `virtinst` fournit `virt-install` et recommande `libvirt-clients` ;
- `cloud-image-utils` fournit les outils nécessaires à la préparation des données Cloud-Init ;
- `cloud-image-utils` dépend notamment de `qemu-utils`.

### 4.3 Installation des outils complémentaires

Les paquets nécessaires ont ensuite été installés :

```bash
sudo apt update
sudo apt install -y libvirt-clients virtinst cloud-image-utils
```

Cette installation permet notamment de disposer de :

- `virsh` pour administrer libvirt ;
- `virt-install` pour les opérations de création de machines virtuelles ;
- `cloud-localds` pour générer les supports de données Cloud-Init ;
- `qemu-img` pour manipuler les images de machines virtuelles.

### 4.4 Validation après installation

La présence et les versions des outils ont été vérifiées après installation :

```bash
echo "===== VALIDATION LIBVIRT ====="
virsh --version
command -v virsh

echo
echo "===== VALIDATION VIRT-INSTALL ====="
virt-install --version
command -v virt-install

echo
echo "===== VALIDATION CLOUD-LOCALDS ====="
cloud-localds --version 2>&1 || true
command -v cloud-localds

echo
echo "===== VALIDATION QEMU-UTILS ====="
qemu-img --version | head -n 1
```

Résultats obtenus :

```text
===== VALIDATION LIBVIRT =====
10.0.0
/usr/bin/virsh

===== VALIDATION VIRT-INSTALL =====
4.1.0
/usr/bin/virt-install

===== VALIDATION CLOUD-LOCALDS =====
/usr/bin/cloud-localds

===== VALIDATION QEMU-UTILS =====
qemu-img version 8.2.2 (Debian 1:8.2.2+ds-0ubuntu1.18)
```

`cloud-localds` ne fournit pas d'option `--version`. L'utilisation de cette option affiche son aide. La commande `command -v cloud-localds` confirme néanmoins que l'outil est correctement installé.

### 4.5 Validation de la section

L'environnement d'administration dispose maintenant des outils nécessaires à la préparation de l'automatisation :

- Terraform ;
- Ansible ;
- Cloud-Init ;
- `virsh` ;
- `virt-install` ;
- `cloud-localds` ;
- `qemu-img` ;
- OpenSSH ;
- Git.

La section 4 est validée. L'environnement d'administration dispose désormais des outils nécessaires pour poursuivre la préparation du projet.

---

**KG-Lab**
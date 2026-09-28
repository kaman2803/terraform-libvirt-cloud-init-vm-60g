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

Voici la section 5 intégrée au README, dans la continuité de la section 4.

---

## 5. Préparation et initialisation de Terraform

Cette section prépare l'environnement Terraform dédié au provider libvirt.

### 5.1 Vérification de la configuration Terraform

Le répertoire Terraform du projet a été vérifié avant toute configuration :

```bash
find terraform -maxdepth 2 -type f -print | sort
ls -la terraform
```

Le répertoire était initialement vide.

La commande suivante a confirmé qu'aucune configuration Terraform n'était encore présente :

```bash
terraform providers
```

Résultat initial :

```text
Error: No configuration files

The directory
/home/kaman/terraform/terraform-libvirt-cloud-init-vm-automation
contains no Terraform configuration files.
```

Cette situation était normale puisque le projet ne disposait encore d'aucun fichier `.tf`.

### 5.2 Déclaration du provider libvirt

Le projet utilise le provider Terraform officiel publié sous l'identifiant :

```text
dmacvicar/libvirt
```

Le fichier `terraform/versions.tf` a été créé avec la configuration suivante :

```hcl
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.9"
    }
  }

  required_version = ">= 1.16.0"
}
```

Cette configuration définit :

- le provider `dmacvicar/libvirt` ;
- la version `0.9.9` du provider ;
- une version minimale de Terraform fixée à `1.16.0`.

### 5.3 Initialisation de Terraform

L'initialisation a été réalisée depuis le répertoire contenant la configuration Terraform :

```bash
cd terraform
terraform init
```

Résultat :

```text
Initializing the backend...

Initializing provider plugins...
- Reusing previous version of dmacvicar/libvirt from the dependency lock file
- Using previously-installed dmacvicar/libvirt v0.9.9

Terraform has been successfully initialized!
```

Terraform a créé le répertoire de travail `.terraform/` ainsi que le fichier `.terraform.lock.hcl`.

### 5.4 Validation

Le provider requis par la configuration a été vérifié :

```bash
terraform providers
```

Résultat :

```text
Providers required by configuration:
.
└── provider[registry.terraform.io/dmacvicar/libvirt] 0.9.9
```

La présence des fichiers Terraform a ensuite été vérifiée :

```bash
ls -la
```

Résultat :

```text
.terraform/
.terraform.lock.hcl
versions.tf
```

La version de Terraform et du provider a également été vérifiée :

```bash
terraform version
```

Résultat :

```text
Terraform v1.16.3
on linux_arm64
+ provider registry.terraform.io/dmacvicar/libvirt v0.9.9
```

Terraform signale qu'une version 1.16.4 est disponible. Aucune mise à jour n'a été effectuée, car la version 1.16.3 est fonctionnelle et respecte la contrainte minimale définie dans le projet.

### 5.5 Validation de la section

Le projet Terraform est maintenant initialisé et le provider libvirt est correctement installé et reconnu.

Aucune machine virtuelle ni aucune ressource libvirt n'a encore été créée.

La prochaine étape consistera à préparer la connexion Terraform vers l'environnement KVM/libvirt cible.

Voici la section 6 intégrée au README, dans la continuité des sections précédentes.

---

## 6. Environnement cible

L'automatisation Terraform est destinée à piloter un serveur KVM/libvirt distant depuis la machine d'administration `srv01-admin`.

### 6.1 Identification de l'hôte cible

L'hôte KVM/libvirt cible est :

```text
192.168.122.1
```

L'audit de l'environnement cible a été réalisé depuis `srv01-admin` avec la commande suivante :

```bash
ssh kaman-goumou@192.168.122.1 '
echo "===== HÔTE ====="
hostname
echo
echo "===== OS ====="
cat /etc/os-release | grep -E "^(PRETTY_NAME|VERSION_ID)="
echo
echo "===== KERNEL / ARCHITECTURE ====="
uname -r
uname -m
echo
echo "===== LIBVIRT ====="
virsh --version
echo
echo "===== STOCKAGE LIBVIRT ====="
virsh pool-list --all
echo
echo "===== RÉSEAUX LIBVIRT ====="
virsh net-list --all
'
```

### 6.2 Caractéristiques du serveur cible

Les informations recueillies sont les suivantes :

| Élément                | Valeur             |
| ---------------------- | ------------------ |
| Nom d'hôte             | `Kgoumou`          |
| Système d'exploitation | Ubuntu 24.04.5 LTS |
| Version                | 24.04              |
| Architecture           | `x86_64`           |
| Kernel                 | `7.0.0-34-generic` |
| Version de libvirt     | `10.0.0`           |

### 6.3 Pools de stockage libvirt

L'inventaire des pools existants a été obtenu avec :

```bash
virsh pool-list --all
```

Résultat :

```text
 Name           State      Autostart
--------------------------------------
 centos9        active     yes
 default        active     yes
 eve-ng         active     yes
 ISO            inactive   yes
 win-server22   active     yes
```

L'environnement cible dispose donc actuellement de cinq pools libvirt :

- `centos9`
- `default`
- `eve-ng`
- `ISO`
- `win-server22`

Aucune modification de ces pools n'a été effectuée dans cette section.

### 6.4 Réseaux libvirt

L'inventaire des réseaux existants a été obtenu avec :

```bash
virsh net-list --all
```

Résultat :

```text
 Name      State    Autostart   Persistent
--------------------------------------------
 default   active   yes         yes
 isp2      active   yes         yes
```

Deux réseaux libvirt sont actuellement configurés :

- `default`
- `isp2`

Les deux réseaux sont actifs, persistants et configurés en démarrage automatique.

Aucune modification des réseaux libvirt n'a été effectuée dans cette section.

### 6.5 Validation de l'environnement cible

L'audit confirme que l'environnement cible dispose :

- d'un serveur KVM/libvirt fonctionnel ;
- de libvirt `10.0.0` ;
- de plusieurs pools de stockage existants ;
- de deux réseaux libvirt existants ;
- d'une architecture `x86_64` adaptée aux machines virtuelles qui seront déployées.

L'environnement cible est maintenant identifié et documenté.

La sélection du pool de stockage et du réseau à utiliser pour les futures machines virtuelles Terraform sera traitée dans une étape dédiée, sans modifier les ressources existantes avant validation.

Voici la section 7 intégrée au README, dans la continuité des sections précédentes.

---

## 7. Architecture de connexion Terraform vers libvirt

L'automatisation repose sur une architecture dans laquelle Terraform est exécuté depuis `srv01-admin` et pilote à distance le serveur KVM/libvirt `Kgoumou`.

### 7.1 Architecture

```text
+-----------------------------+
|        srv01-admin          |
|                             |
| Ubuntu Server 24.04.5 LTS   |
| Terraform 1.16.3            |
| Provider libvirt 0.9.9      |
+-------------+---------------+
              |
              | SSH
              | 192.168.122.1
              v
+-----------------------------+
|          Kgoumou            |
|                             |
| Ubuntu 24.04.5 LTS          |
| x86_64                      |
| libvirt 10.0.0              |
|                             |
| qemu:///system              |
+-----------------------------+
```

Terraform sera exécuté localement sur `srv01-admin` et utilisera une connexion SSH pour accéder au service libvirt système du serveur cible.

### 7.2 Vérification de l'URI libvirt locale

L'URI libvirt par défaut pour l'utilisateur `kaman-goumou` sur le serveur cible a été vérifiée avec :

```bash
ssh kaman-goumou@192.168.122.1 'virsh uri'
```

Résultat :

```text
qemu:///session
```

Cette URI correspond au contexte de session de l'utilisateur.

Pour l'automatisation des machines virtuelles du lab, le contexte système `qemu:///system` est utilisé.

### 7.3 Vérification des droits libvirt

Les groupes du compte utilisé pour l'administration ont été vérifiés avec :

```bash
ssh kaman-goumou@192.168.122.1 'id'
```

Le compte `kaman-goumou` appartient notamment au groupe :

```text
libvirt
```

Le socket libvirt système a également été vérifié :

```bash
ssh kaman-goumou@192.168.122.1 'ls -l /run/libvirt/libvirt-sock'
```

Résultat :

```text
srw-rw---- 1 root libvirt 0 Sep 27 13:59 /run/libvirt/libvirt-sock
```

Le socket est donc associé au groupe `libvirt`, auquel appartient le compte utilisé pour l'administration.

### 7.4 Validation de l'accès au libvirt système

L'accès direct au contexte système a été vérifié avec :

```bash
ssh kaman-goumou@192.168.122.1 'virsh -c qemu:///system list --all'
```

La commande a permis de récupérer la liste des machines virtuelles présentes sur l'hyperviseur.

### 7.5 Validation de la connexion libvirt distante

La connexion depuis `srv01-admin` vers le libvirt système distant a ensuite été testée avec :

```bash
virsh -c qemu+ssh://kaman-goumou@192.168.122.1/system list --all
```

Résultat :

```text
Id   Name                 State
-------------------------------------
-    CentOS-Stream9-SRV   shut off
-    eve-ng               shut off
-    freenas              shut off
-    oracle-db-server     shut off
-    ubuntu-server-vm     shut off
-    WinServer2022-Lab    shut off
-    winxp-pc01           shut off
-    x-srvsoc             shut off
```

Cette validation confirme que `srv01-admin` peut accéder à distance au contexte libvirt système de `Kgoumou` via SSH.

### 7.6 Architecture de connexion retenue

Le principe de connexion retenu pour le projet est donc :

```text
qemu+ssh://kaman-goumou@192.168.122.1/system
```

Cette connexion permet à l'environnement d'administration de piloter le service libvirt système du serveur KVM cible sans exécuter Terraform directement sur l'hyperviseur.

Aucune machine virtuelle ni aucune ressource libvirt n'a été créée ou modifiée durant cette section.

### 7.7 Validation de la section

La chaîne de communication nécessaire à l'automatisation est validée :

```text
srv01-admin
     |
     | SSH
     v
192.168.122.1
     |
     | qemu:///system
     v
libvirt
```

La connexion distante libvirt fonctionne et l'environnement est prêt pour la configuration de la connexion du provider Terraform.

---

## 8. Configuration du provider Terraform

Cette section configure le provider Terraform `dmacvicar/libvirt` afin que Terraform puisse communiquer avec le serveur KVM/libvirt distant.

### 8.1 Configuration du provider

Le fichier `terraform/provider.tf` a été créé :

```hcl
provider "libvirt" {
  uri = "qemu+ssh://kaman-goumou@192.168.122.1/system"
}
```

Cette configuration indique à Terraform d'utiliser le contexte libvirt système du serveur cible `192.168.122.1` via SSH.

L'architecture de connexion est donc :

```text
srv01-admin
     |
     | SSH
     | qemu+ssh
     v
192.168.122.1
     |
     | qemu:///system
     v
libvirt
```

### 8.2 Formatage de la configuration

La configuration Terraform a été formatée avec :

```bash
terraform fmt
```

Aucune erreur n'a été retournée.

### 8.3 Validation de la configuration

La validité syntaxique et structurelle de la configuration a été vérifiée avec :

```bash
terraform validate
```

Résultat :

```text
Success! The configuration is valid.
```

### 8.4 Vérification du provider

Le provider utilisé par la configuration a été vérifié avec :

```bash
terraform providers
```

Résultat :

```text
Providers required by configuration:
.
└── provider[registry.terraform.io/dmacvicar/libvirt] 0.9.9
```

### 8.5 Test de communication avec l'infrastructure cible

La capacité de Terraform à interroger l'infrastructure distante a été vérifiée avec :

```bash
terraform plan
```

Résultat :

```text
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```

Ce résultat est attendu à ce stade du projet : aucune ressource Terraform n'a encore été déclarée.

Le résultat confirme néanmoins que Terraform peut charger le provider libvirt et effectuer la comparaison avec l'infrastructure cible sans erreur.

### 8.6 Validation de la section

La configuration du provider Terraform est validée.

La chaîne suivante fonctionne :

```text
Terraform
    |
    | dmacvicar/libvirt 0.9.9
    |
    | qemu+ssh
    v
srv01-admin
    |
    | SSH
    v
192.168.122.1
    |
    | qemu:///system
    v
libvirt
```

Aucune machine virtuelle, aucun volume et aucun réseau n'a été créé ou modifié durant cette section.

La prochaine étape consistera à préparer l'image système destinée aux futures machines virtuelles Cloud-Init.

---

## 9. Préparation de l'image Ubuntu Cloud

### 9.1 Téléchargement

Téléchargement de l'image officielle Ubuntu 24.04 LTS Cloud Image AMD64 :

```bash
wget -O images/noble-server-cloudimg-amd64.img \
https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

### 9.2 Vérification de l'image

Vérification de l'intégrité et du format :

```bash
sha256sum images/noble-server-cloudimg-amd64.img
file images/noble-server-cloudimg-amd64.img
qemu-img info images/noble-server-cloudimg-amd64.img
```

SHA-256 obtenu :

```text
6a81c37564db9b1ee84e141922625e1d7c5b389b99bb3c572e0243607d5bb4d2
```

Résultats :

```text
Format : qcow2
Taille virtuelle : 3.5 GiB
Taille du fichier : 597 MiB
Corrupt : false
```

### 9.3 Transfert vers Kgoumou

Transfert de l'image vers le répertoire dédié aux templates :

```bash
scp images/noble-server-cloudimg-amd64.img \
kaman-goumou@192.168.122.1:/home/kaman-goumou/lab/kvm/templates/
```

### 9.4 Validation après transfert

Sur `Kgoumou` :

```bash
cd /home/kaman-goumou/lab/kvm/templates/

ls -lh noble-server-cloudimg-amd64.img
sha256sum noble-server-cloudimg-amd64.img
file noble-server-cloudimg-amd64.img
qemu-img info noble-server-cloudimg-amd64.img
```

SHA-256 après transfert :

```text
6a81c37564db9b1ee84e141922625e1d7c5b389b99bb3c572e0243607d5bb4d2
```

Le hash est identique à celui obtenu avant le transfert.

### 9.5 Validation

L'image Ubuntu Cloud est correctement transférée dans :

```text
/home/kaman-goumou/lab/kvm/templates/
```

Elle est au format `qcow2`, intègre et prête à être utilisée comme image de base pour les déploiements Terraform/libvirt avec Cloud-Init.

**Statut : VALIDÉ**

---

## 10. Préparation de Cloud-Init

### 10.1 Création de `user-data`

```bash
cat > cloud-init/user-data <<'EOF'
#cloud-config

hostname: ubuntu-cloud-vm

users:
  - name: kaman
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - SSH_PUBLIC_KEY

ssh_pwauth: false
disable_root: true

package_update: false
package_upgrade: false
EOF
```

La clé SSH publique a ensuite été injectée automatiquement :

```bash
SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
sed -i "s|SSH_PUBLIC_KEY|$SSH_KEY|" cloud-init/user-data
```

### 10.2 Création de `meta-data`

```bash
cat > cloud-init/meta-data <<'EOF'
instance-id: ubuntu-cloud-vm-01
local-hostname: ubuntu-cloud-vm
EOF
```

### 10.3 Génération du média NoCloud

```bash
cloud-localds \
  cloud-init/seed.iso \
  cloud-init/user-data \
  cloud-init/meta-data
```

Validation :

```bash
ls -lh cloud-init/seed.iso
file cloud-init/seed.iso
```

Résultat :

```text
366K
ISO 9660 CD-ROM filesystem data 'cidata'
```

### 10.4 Validation

Le média NoCloud `seed.iso` a été généré avec succès à partir des fichiers `user-data` et `meta-data`.

**Statut : VALIDÉ**

---


## 11. Définition du volume Terraform

### 11.1 Clé SSH dédiée au projet

Une clé SSH dédiée à Terraform/libvirt a été créée afin de ne pas modifier les clés utilisées pour les autres connexions SSH.

```bash
ssh-keygen -t ed25519 \
  -f ~/.ssh/terraform_libvirt_ed25519 \
  -C "terraform-libvirt@srv01-admin"
```

La clé publique a été installée sur `Kgoumou` :

```bash
ssh-copy-id \
  -i ~/.ssh/terraform_libvirt_ed25519.pub \
  kaman-goumou@192.168.122.1
```

Validation :

```bash
ssh \
  -i ~/.ssh/terraform_libvirt_ed25519 \
  -o IdentitiesOnly=yes \
  kaman-goumou@192.168.122.1 \
  'id && virsh -c qemu:///system uri'
```

Résultat :

```text
qemu:///system
```

### 11.2 Configuration du provider

Le provider Terraform utilise maintenant la clé SSH dédiée :

```hcl
provider "libvirt" {
  uri = "qemu+ssh://kaman-goumou@192.168.122.1/system?sshauth=privkey&keyfile=/home/kaman/.ssh/terraform_libvirt_ed25519"
}
```

### 11.3 Création du volume

Fichier `terraform/volume.tf` :

```hcl
resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-cloud-vm-01.qcow2"
  pool = "default"

  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = "/home/kaman-goumou/lab/kvm/templates/noble-server-cloudimg-amd64.img"
    }
  }
}
```

Validation :

```bash
terraform fmt
terraform validate
terraform plan
```

Résultat du plan :

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

Terraform prévoit uniquement la création du volume `ubuntu-cloud-vm-01.qcow2` à partir de l'image Ubuntu Cloud existante.

**Statut : VALIDÉ**

---

Voici la section 12 complète, avec les deux captures intégrées aux étapes correspondantes.

---

## 12. Création et validation du volume Terraform

### 12.1 Première tentative de création

La première exécution de Terraform a été réalisée avec le volume utilisant `create.content.url` pour référencer directement l'image Ubuntu Cloud située sur `Kgoumou`.

Commande :

```bash
terraform apply
```

Terraform a échoué avec :

```text
Error: Failed to Open URL

Could not open URL for upload:
failed to stat file:
stat /home/kaman-goumou/lab/kvm/templates/noble-server-cloudimg-amd64.img:
no such file or directory
```

Le problème venait du fait que le chemin indiqué dans `create.content.url` était recherché depuis `srv01-admin`, alors que l'image se trouve sur l'hôte libvirt `Kgoumou`.

### 12.2 Vérification de l'état après l'échec

Vérification du state Terraform :

```bash
terraform state list
```

Aucune ressource n'était présente.

Vérification sur `Kgoumou` :

```bash
ssh \
  -i ~/.ssh/terraform_libvirt_ed25519 \
  -o IdentitiesOnly=yes \
  kaman-goumou@192.168.122.1 \
  'virsh -c qemu:///system vol-list default | grep ubuntu-cloud-vm-01 || true'
```

Aucun volume `ubuntu-cloud-vm-01` n'existait.

L'échec n'avait donc créé aucune ressource.

### 12.3 Vérification du schéma du provider

Afin de ne pas modifier la configuration sur la base d'hypothèses, le schéma réel du provider `dmacvicar/libvirt` 0.9.9 installé dans le projet a été interrogé :

```bash
terraform providers schema -json > /tmp/libvirt-schema.json
```

Les attributs disponibles pour `libvirt_volume` ont notamment été vérifiés :

```text
allocation
allocation_unit
backing_store
capacity
capacity_unit
create
id
key
name
path
physical
physical_unit
pool
target
type
```

La structure de `create`, `target` et `backing_store` a ensuite été vérifiée directement dans le schéma du provider.

### 12.4 Utilisation de l'image Ubuntu comme backing store

La configuration a été adaptée afin que le volume libvirt utilise directement l'image Ubuntu présente sur `Kgoumou` comme `backing_store`.

Fichier `terraform/volume.tf` :

```hcl
resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-cloud-vm-01.qcow2"
  pool = "default"

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = "/home/kaman-goumou/lab/kvm/templates/noble-server-cloudimg-amd64.img"

    format = {
      type = "qcow2"
    }
  }
}
```

Validation :

```bash
terraform fmt
terraform validate
terraform plan
```

Résultat :

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

### 12.5 Première tentative avec le backing store

L'exécution de :

```bash
terraform apply
```

a retourné :

```text
Error: Missing Capacity

Volume capacity is required when not uploading from a URL
```

Le provider exigeait donc une capacité explicite lorsque `create.content` n'était pas utilisé.

### 12.6 Vérification de la capacité dans le schéma du provider

La structure des attributs `capacity` et `capacity_unit` a été vérifiée directement dans le schéma :

```text
capacity:
  type: number
  description: Volume capacity in bytes
  optional: true
  computed: true

capacity_unit:
  type: string
  optional: true
```

Une capacité de **10 GiB** a été retenue pour le volume.

### 12.7 Configuration finale du volume

Le fichier `terraform/volume.tf` a été complété :

```hcl
resource "libvirt_volume" "ubuntu_base" {
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
    path = "/home/kaman-goumou/lab/kvm/templates/noble-server-cloudimg-amd64.img"

    format = {
      type = "qcow2"
    }
  }
}
```

Validation :

```bash
terraform fmt
terraform validate
terraform plan
```

Résultat :

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

### 12.8 Création du volume

Création réelle du volume :

```bash
terraform apply
```

Après confirmation avec `yes`, Terraform a retourné :

```text
libvirt_volume.ubuntu_base: Creation complete after 0s
[id=/var/lib/libvirt/images/ubuntu-cloud-vm-01.qcow2]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

![Création du volume avec Terraform](docs/images/12-08-terraform-apply-volume-created.png)

Le volume a donc été créé dans le pool `default`.

### 12.9 Validation avec libvirt

Vérification du volume sur `Kgoumou` :

```bash
ssh \
  -i ~/.ssh/terraform_libvirt_ed25519 \
  -o IdentitiesOnly=yes \
  kaman-goumou@192.168.122.1 \
  'virsh -c qemu:///system vol-info ubuntu-cloud-vm-01.qcow2 --pool default'
```

Résultat :

```text
Name:           ubuntu-cloud-vm-01.qcow2
Type:           file
Capacity:       10.00 GiB
Allocation:     196.00 KiB
```

Le volume est donc bien créé avec une capacité virtuelle de **10 GiB**.

Vérification de la présence du fichier sur l'hôte KVM :

```bash
ls -lh /var/lib/libvirt/images/
```

Le fichier `ubuntu-cloud-vm-01.qcow2` est présent sur `Kgoumou`.

![Volume créé sur Kgoumou](docs/images/12-09-volume-on-kgoumou.png)

### 12.10 Vérification du backing store

Le XML libvirt du volume a été inspecté :

```bash
ssh \
  -i ~/.ssh/terraform_libvirt_ed25519 \
  -o IdentitiesOnly=yes \
  kaman-goumou@192.168.122.1 \
  'virsh -c qemu:///system vol-dumpxml ubuntu-cloud-vm-01.qcow2 --pool default | grep -A8 -B2 backingStore'
```

Résultat :

```xml
<backingStore>
  <path>/home/kaman-goumou/lab/kvm/templates/noble-server-cloudimg-amd64.img</path>
  <format type='qcow2'/>
  ...
</backingStore>
```

La vérification confirme que le volume Terraform utilise bien l'image Ubuntu Cloud comme image de base.

### 12.11 Vérification du state Terraform

```bash
terraform state list
```

Résultat :

```text
libvirt_volume.ubuntu_base
```

Terraform possède donc bien la ressource dans son state.

### 12.12 Validation finale

Le volume Terraform est correctement créé et intégré à libvirt.

```text
Nom       : ubuntu-cloud-vm-01.qcow2
Pool      : default
Format    : qcow2
Capacité  : 10 GiB
Backing   : noble-server-cloudimg-amd64.img
State     : libvirt_volume.ubuntu_base
```

Le volume utilise l'image Ubuntu Cloud présente sur :

```text
/home/kaman-goumou/lab/kvm/templates/noble-server-cloudimg-amd64.img
```

**Statut : VALIDÉ**

---

# 13. Préparation de la machine virtuelle Ubuntu avec Terraform et Cloud-Init

## 13.1 — Objectif

Cette section a pour objectif de préparer le déploiement automatisé de la VM Ubuntu `ubuntu-cloud-vm-01` avec Terraform et Cloud-Init.

La VM prévue possède les caractéristiques suivantes :

| Élément                | Valeur                     |
| ---------------------- | -------------------------- |
| Nom                    | `ubuntu-cloud-vm-01`       |
| Hyperviseur            | KVM/libvirt                |
| Architecture           | `x86_64`                   |
| vCPU                   | 2                          |
| RAM                    | 2048 MiB                   |
| Machine                | `q35`                      |
| Disque                 | `ubuntu-cloud-vm-01.qcow2` |
| Bus disque             | VirtIO                     |
| Réseau                 | `default`                  |
| Carte réseau           | VirtIO                     |
| Configuration initiale | Cloud-Init                 |

À ce stade, **aucune création réelle de la VM n'a encore été effectuée**.

---

## 13.2 — Préparation de la ressource Cloud-Init

Le projet contient déjà les fichiers :

```text
cloud-init/
├── meta-data
├── seed.iso
└── user-data
```

Une ressource Terraform `libvirt_cloudinit_disk` a été ajoutée dans `terraform/cloudinit.tf`.

### Commande utilisée

```bash
cat > cloudinit.tf <<'EOF'
resource "libvirt_cloudinit_disk" "ubuntu_init" {
  name      = "ubuntu-cloud-vm-01-init"
  user_data = file("${path.module}/../cloud-init/user-data")
  meta_data = file("${path.module}/../cloud-init/meta-data")
}
EOF
```

Le fichier `cloudinit.tf` permet à Terraform de gérer directement la génération du disque Cloud-Init à partir des fichiers `user-data` et `meta-data`.

---

## 13.3 — Définition initiale de la VM

La ressource `libvirt_domain` a été créée dans `terraform/domain.tf`.

Configuration retenue :

```hcl
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

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.ubuntu_base.pool
            volume = libvirt_volume.ubuntu_base.name
          }
        }

        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"

        source = {
          file = {
            file = libvirt_cloudinit_disk.ubuntu_init.path
          }
        }

        target = {
          dev = "sda"
          bus = "sata"
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
```

Cette configuration utilise le volume `libvirt_volume.ubuntu_base` créé et validé lors de la Section 12.

---

## 13.4 — Adaptation au schéma du provider libvirt 0.9.9

La syntaxe du provider `dmacvicar/libvirt` 0.9.x utilise une structure imbriquée pour les périphériques.

Plusieurs erreurs de validation ont été rencontrées lors de la construction de `domain.tf`.

### 13.4.1 — Correction de `source.network`

Première définition :

```hcl
source = {
  network = "default"
}
```

Terraform a retourné :

```text
attribute "network": object required, but have string
```

La structure a donc été corrigée en :

```hcl
source = {
  network = {
    network = "default"
  }
}
```

---

### 13.4.2 — Correction du modèle de l'interface réseau

La première définition utilisait :

```hcl
model = "virtio"
```

Terraform a retourné :

```text
attribute "model": object required, but have string
```

La définition a été corrigée en :

```hcl
model = {
  type = "virtio"
}
```

---

### 13.4.3 — Correction de la source du CD-ROM Cloud-Init

La première définition utilisait :

```hcl
source = {
  file = libvirt_cloudinit_disk.ubuntu_init.path
}
```

Terraform a retourné :

```text
attribute "source": attribute "file": object required, but have string
```

La structure a été corrigée en :

```hcl
source = {
  file = {
    file = libvirt_cloudinit_disk.ubuntu_init.path
  }
}
```

Ces corrections ont permis d'obtenir une configuration conforme au schéma du provider installé.

---

## 13.5 — Formatage et validation Terraform

Après les corrections :

### Commande

```bash
terraform fmt
```

### Résultat

```text
```

Aucune erreur n'a été retournée.

### Validation

```bash
terraform validate
```

### Résultat

```text
Success! The configuration is valid.
```

La configuration Terraform est donc syntaxiquement valide.

---

## 13.6 — Plan Terraform

Une première exécution de `terraform plan`, avant l'intégration définitive du CD-ROM, avait déjà indiqué :

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Après l'intégration complète de Cloud-Init et les corrections du schéma, une nouvelle validation a été effectuée avec :

```bash
terraform plan
```

### Résultat final

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Terraform prévoit donc la création de deux ressources :

```text
libvirt_cloudinit_disk.ubuntu_init
libvirt_domain.ubuntu_cloud_vm
```

Aucune ressource existante ne doit être modifiée ou supprimée.

---

## 13.7 — État de validation de la section

La préparation Terraform de la VM est validée.

```text
Terraform fmt       : ✅
Terraform validate  : ✅
Terraform plan      : ✅

Ressources à créer  : 2
À modifier          : 0
À détruire          : 0
```

La chaîne de déploiement préparée est la suivante :

```text
                    Terraform
                        │
             ┌──────────┴──────────┐
             │                     │
             ▼                     ▼
 libvirt_cloudinit_disk      libvirt_domain
       ubuntu_init          ubuntu_cloud_vm
             │                     │
             │                     ├── 2 vCPU
             │                     ├── 2 GiB RAM
             │                     ├── x86_64 / Q35
             │                     ├── vda / VirtIO
             │                     └── NIC / default / VirtIO
             │
             ▼
       Cloud-Init ISO
```

### État actuel

> **Section 13 — Préparation de la VM : VALIDÉE ✅**

**Important :** le `terraform apply` n'a pas encore été exécuté. La création réelle de la VM constituera la prochaine étape de cette section.

---

Voici la section 14 intégrée au README, dans la continuité des sections précédentes, avec la capture insérée au bon endroit.

---

## 14. Déploiement réel de la VM et résolution des problèmes

### 14.1 Objectif

Cette section réalise le déploiement réel de la VM Ubuntu avec Terraform, libvirt et Cloud-Init.

L'objectif est de valider toute la chaîne d'automatisation :

```text
srv01-admin
    │
    │ Terraform
    │ Provider libvirt 0.9.9
    │ SSH
    ▼
Kgoumou
    │
    ├── libvirt
    ├── VM Ubuntu
    ├── disque système QCOW2
    ├── Cloud-Init
    └── réseau VirtIO
```

Configuration cible :

```text
Nom VM       : ubuntu-cloud-vm-01
vCPU         : 2
Mémoire      : 2048 MiB
Architecture : x86_64
Machine      : q35
Disque       : QCOW2
Bus          : VirtIO
Réseau       : libvirt default
```

---

### 14.2 Premier déploiement Terraform

Le premier déploiement a été effectué avec :

```bash
terraform apply
```

Résultat :

```text
libvirt_cloudinit_disk.ubuntu_init: Creation complete after 0s [id=b2c3d140e9346731]
libvirt_domain.ubuntu_cloud_vm: Creation complete after 1s [name=ubuntu-cloud-vm-01]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

L'état Terraform contenait alors :

```text
libvirt_cloudinit_disk.ubuntu_init
libvirt_domain.ubuntu_cloud_vm
libvirt_volume.ubuntu_base
```

---

### 14.3 Premier problème : ISO Cloud-Init temporaire

Lors du premier démarrage, libvirt ne pouvait pas accéder à l'ISO générée par `libvirt_cloudinit_disk`.

Erreur :

```text
Cannot access storage file
'/tmp/terraform-provider-libvirt-cloudinit/cloudinit-b2c3d140e9346731.iso':
No such file or directory
```

Le problème venait du fait que `libvirt_cloudinit_disk` produisait initialement l'ISO dans un répertoire temporaire du provider Terraform.

Cette méthode n'était donc pas adaptée au stockage persistant utilisé par la VM.

---

### 14.4 Création d'un volume Cloud-Init persistant

Afin de conserver l'ISO dans le pool libvirt `default`, un volume dédié a été créé :

```hcl
resource "libvirt_cloudinit_disk" "ubuntu_init" {
  name      = "ubuntu-cloud-vm-01-init"
  user_data = file("${path.module}/../cloud-init/user-data")
  meta_data = file("${path.module}/../cloud-init/meta-data")
}

resource "libvirt_volume" "ubuntu_init_volume" {
  name = "ubuntu-cloud-vm-01-init.iso"
  pool = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.ubuntu_init.path
    }
  }

  target = {
    format = {
      type = "iso"
    }
  }
}
```

Le disque Cloud-Init de la VM a ensuite été associé au volume :

```hcl
{
  device = "cdrom"

  source = {
    volume = {
      pool   = libvirt_volume.ubuntu_init_volume.pool
      volume = libvirt_volume.ubuntu_init_volume.name
    }
  }

  target = {
    dev = "sda"
    bus = "sata"
  }
}
```

Une première tentative avec une capacité explicitement définie avait provoqué une erreur car le contenu de l'ISO était supérieur à la capacité spécifiée.

La capacité a donc été supprimée.

Le volume obtenu a été validé :

```text
Name:       ubuntu-cloud-vm-01-init.iso
Type:       file
Capacity:   42.00 KiB
Allocation: 44.00 KiB
```

La liste des disques confirmait :

```text
vda  ubuntu-cloud-vm-01.qcow2
sda  ubuntu-cloud-vm-01-init.iso
```

---

### 14.5 Deuxième problème : `Permission denied` sur le disque système

Après correction du stockage Cloud-Init, le démarrage de la VM a échoué sur le disque système :

```text
error: Failed to start domain 'ubuntu-cloud-vm-01'
error: internal error: process exited while connecting to monitor:
qemu-system-x86_64:
-blockdev ... /var/lib/libvirt/images/ubuntu-cloud-vm-01.qcow2 ...
Could not open '/var/lib/libvirt/images/ubuntu-cloud-vm-01.qcow2':
Permission denied
```

Capture de l'erreur réelle obtenue lors du démarrage :

![Erreur de permission lors du démarrage de la VM](docs/images/14-05-error-source-volume-permission-denied.png)

L'erreur concernait précisément :

```text
/var/lib/libvirt/images/ubuntu-cloud-vm-01.qcow2
```

Le processus utilisé par libvirt/QEMU était :

```text
uid=64055(libvirt-qemu)
gid=993(kvm)
groups=993(kvm),64055(libvirt-qemu)
```

---

### 14.6 Vérification des permissions Unix

Les permissions du volume ont d'abord été vérifiées.

Un test direct avec l'utilisateur `libvirt-qemu` a été effectué :

```bash
sudo -u libvirt-qemu \
  test -r /var/lib/libvirt/images/ubuntu-cloud-vm-01.qcow2 \
  && echo "DISQUE: lecture OK"
```

Résultat :

```text
DISQUE: lecture OK
```

Le backing store a également été testé :

```bash
sudo -u libvirt-qemu \
  test -r /home/kaman-goumou/lab/kvm/templates/noble-server-cloudimg-amd64.img \
  && echo "BACKING: lecture OK"
```

Résultat :

```text
BACKING: lecture OK
```

`qemu-img info`, exécuté avec l'utilisateur `libvirt-qemu`, permettait également d'accéder aux images.

Ces tests ont montré que l'utilisateur utilisé par QEMU pouvait lire les fichiers.

Le problème ne pouvait donc pas être expliqué uniquement par les permissions Unix classiques.

---

### 14.7 Tentative de correction des permissions du volume

Une configuration explicite des permissions a été ajoutée au volume Terraform :

```hcl
target = {
  format = {
    type = "qcow2"
  }

  permissions = {
    owner = "64055"
    group = "993"
    mode  = "0660"
  }
}
```

Terraform a cependant refusé une modification directe du volume existant :

```text
Error: Update Not Supported

Storage volumes cannot be updated.
All changes require replacement.
```

Le volume a donc été retiré de l'état Terraform :

```bash
terraform state rm libvirt_volume.ubuntu_base
```

Puis supprimé physiquement du pool `default` :

```bash
virsh -c qemu:///system \
  vol-delete ubuntu-cloud-vm-01.qcow2 \
  --pool default
```

Après recréation, les permissions étaient :

```text
-rw-rw---- 1 libvirt-qemu kvm ... ubuntu-cloud-vm-01.qcow2
```

Le XML libvirt confirmait :

```xml
<mode>0660</mode>
<owner>64055</owner>
<group>993</group>
```

Malgré cela, le démarrage pouvait encore produire le même `Permission denied`.

---

### 14.8 Comparaison avec une VM fonctionnelle

Une VM `freenas` déjà fonctionnelle sur Kgoumou a été utilisée comme référence.

Son disque système était déclaré directement comme un fichier :

```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='none'/>
  <source file='/var/lib/libvirt/images/freenas.qcow2'/>
  <target dev='sda' bus='sata'/>
</disk>
```

Une VM de test temporaire a également été créée avec une source fichier :

```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='none'/>
  <source file='/var/lib/libvirt/images/ubuntu-file-test.qcow2'/>
  <target dev='vda' bus='virtio'/>
</disk>
```

Cette VM a démarré correctement :

```text
Domain 'ubuntu-file-test' started
```

Puis :

```text
running
```

Cette comparaison a permis d'isoler une différence importante entre les configurations précédentes :

```text
VM fonctionnelle
    └── source file

Configuration Terraform précédente
    └── source volume
```

---

### 14.9 Vérification AppArmor et DAC

Les domaines fonctionnels présentaient également des labels de sécurité dynamiques :

```xml
<seclabel type='dynamic'
          model='apparmor'
          relabel='yes'>
```

et :

```xml
<seclabel type='dynamic'
          model='dac'
          relabel='yes'>
```

La configuration Terraform a donc été complétée :

```hcl
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
```

Terraform a appliqué la modification :

```text
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

Le XML contenait alors :

```xml
<seclabel type='dynamic' model='apparmor' relabel='yes'/>
<seclabel type='dynamic' model='dac' relabel='yes'/>
```

Les journaux du noyau et d'AppArmor ont ensuite été vérifiés à la recherche de refus explicites `DENIED`.

Aucun refus AppArmor correspondant au problème n'a été identifié.

La piste AppArmor n'expliquait donc pas à elle seule le problème.

---

### 14.10 Repartir sur une base saine

Afin d'éliminer les résidus des différentes tentatives, l'environnement de test a été nettoyé.

Les domaines temporaires ont été supprimés :

```bash
virsh undefine ubuntu-file-test
virsh undefine ubuntu-cloud-vm-01
```

Les volumes ont été supprimés :

```bash
sudo virsh -c qemu:///system \
  vol-delete ubuntu-cloud-vm-01.qcow2 \
  --pool default

sudo virsh -c qemu:///system \
  vol-delete ubuntu-cloud-vm-01-init.iso \
  --pool default
```

Le volume temporaire `ubuntu-file-test.qcow2` a également été supprimé.

L'état Terraform a été nettoyé :

```bash
terraform state rm \
  libvirt_cloudinit_disk.ubuntu_init \
  libvirt_domain.ubuntu_cloud_vm \
  libvirt_volume.ubuntu_base \
  libvirt_volume.ubuntu_init_volume
```

Validation :

```bash
terraform state list
```

L'état Terraform était vide.

---

### 14.11 Installation de l'image Ubuntu sur l'hôte libvirt

L'image Ubuntu Cloud officielle a été placée directement sur Kgoumou :

```text
/var/lib/libvirt/images/base/noble-server-cloudimg-amd64.img
```

L'image a été validée comme QCOW2 :

```text
Format       : qcow2
Virtual size : 3.5 GiB
Disk size    : environ 597 MiB
Corrupt      : false
```

La lecture par `libvirt-qemu` a été vérifiée :

```bash
sudo -u libvirt-qemu \
  test -r /var/lib/libvirt/images/base/noble-server-cloudimg-amd64.img \
  && echo "READ_OK"
```

Résultat :

```text
READ_OK
```

---

### 14.12 Création du volume système avec backing store

Le volume système Terraform a été défini ainsi :

```hcl
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
```

Architecture :

```text
noble-server-cloudimg-amd64.img
             │
             │ backing store
             ▼
ubuntu-cloud-vm-01.qcow2
             │
             ▼
        VM Ubuntu
```

---

### 14.13 Déploiement propre

Après nettoyage, le plan Terraform indiquait :

```text
Plan: 4 to add, 0 to change, 0 to destroy.
```

Les quatre ressources étaient :

```text
libvirt_cloudinit_disk.ubuntu_init
libvirt_volume.ubuntu_os
libvirt_volume.ubuntu_init_volume
libvirt_domain.ubuntu_cloud_vm
```

Déploiement :

```bash
terraform apply
```

Résultat :

```text
libvirt_cloudinit_disk.ubuntu_init: Creation complete after 0s [id=b2c3d140e9346731]
libvirt_volume.ubuntu_os: Creation complete after 0s [id=/var/lib/libvirt/images/ubuntu-cloud-vm-01.qcow2]
libvirt_volume.ubuntu_init_volume: Creation complete after 0s [id=/var/lib/libvirt/images/ubuntu-cloud-vm-01-init.iso]
libvirt_domain.ubuntu_cloud_vm: Creation complete after 1s [name=ubuntu-cloud-vm-01]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

L'état Terraform contient :

```text
libvirt_cloudinit_disk.ubuntu_init
libvirt_domain.ubuntu_cloud_vm
libvirt_volume.ubuntu_init_volume
libvirt_volume.ubuntu_os
```

---

### 14.14 Ajout de la console série

Afin de faciliter le diagnostic du démarrage, une console série a été ajoutée :

```hcl
consoles = [
  {
    type = "pty"

    target = {
      type = "serial"
      port = 0
    }
  }
]
```

Application :

```text
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

Le XML libvirt contenait :

```xml
<serial>
...
</serial>

<console type='pty'>
  <target type='serial' port='0'/>
</console>
```

Le journal QEMU confirmait la création du périphérique série :

```text
-chardev pty,id=charserial0
-device ... "driver":"isa-serial" ...
```

ainsi que :

```text
char device redirected to /dev/pts/1
```

Aucune erreur de disque ou de Cloud-Init n'a été observée dans le journal QEMU à ce stade.

---

### 14.15 Problème identifié dans la définition Terraform du disque

Après le redéploiement propre, l'inspection du XML libvirt a montré que le disque système était généré avec :

```xml
<driver name='qemu' type='raw'/>
```

alors que :

```text
/var/lib/libvirt/images/ubuntu-cloud-vm-01.qcow2
```

était une image QCOW2.

L'analyse de notre `domain.tf` a permis d'identifier l'erreur de configuration.

Le bloc `driver` avait été placé sur le CD-ROM Cloud-Init au lieu du disque système.

Configuration incorrecte :

```hcl
{
  device = "cdrom"

  source = {
    file = {
      file = "/var/lib/libvirt/images/ubuntu-cloud-vm-01-init.iso"
    }
  }

  driver = {
    name  = "qemu"
    type  = "qcow2"
    cache = "none"
  }
}
```

Le `driver` était donc associé au mauvais disque.

---

### 14.16 Correction du driver du disque système

Le bloc `driver` a été déplacé sur le premier disque, correspondant à `vda` :

```hcl
{
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
}
```

Le CD-ROM Cloud-Init est resté sans bloc `driver` explicite :

```hcl
{
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
```

Le plan Terraform a confirmé exactement la correction :

```text
~ disks = [
    ~ {
        + driver = {
            + cache = "none"
            + name  = "qemu"
            + type  = "qcow2"
          }
      },
    ~ {
        - driver = {
            - name = "qemu" -> null
            - type = "qcow2" -> null
          } -> null
      },
  ]

Plan: 0 to add, 1 to change, 0 to destroy.
```

La modification a été appliquée :

```bash
terraform apply
```

Résultat :

```text
libvirt_domain.ubuntu_cloud_vm: Modifications complete after 1s [name=ubuntu-cloud-vm-01]

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

---

### 14.17 Validation du XML libvirt

Le XML réellement généré par libvirt a été contrôlé depuis `srv01-admin` :

```bash
ssh -i ~/.ssh/terraform_libvirt_ed25519 \
  -o IdentitiesOnly=yes \
  kaman-goumou@192.168.122.1 \
  "virsh -c qemu:///system dumpxml ubuntu-cloud-vm-01" \
  | grep -A8 -B2 "<disk type='file' device='disk'>"
```

Résultat :

```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='none'/>
  <source file='/var/lib/libvirt/images/ubuntu-cloud-vm-01.qcow2'/>
  <target dev='vda' bus='virtio'/>
  <address type='pci' domain='0x0000' bus='0x03' slot='0x00' function='0x0'/>
</disk>
```

La configuration finale du disque système est donc :

```text
Driver      : qemu
Format      : qcow2
Cache       : none
Source      : ubuntu-cloud-vm-01.qcow2
Device      : vda
Bus         : virtio
```

Le CD-ROM Cloud-Init est séparé :

```xml
<disk type='file' device='cdrom'>
  <driver name='qemu' type='raw'/>
  <source file='/var/lib/libvirt/images/ubuntu-cloud-vm-01-init.iso'/>
```

Le `raw` du CD-ROM est normal et ne concerne pas le disque système.

---

### 14.18 Validation finale du démarrage

La VM a finalement été démarrée depuis `srv01-admin` :

```bash
ssh -i ~/.ssh/terraform_libvirt_ed25519 \
  -o IdentitiesOnly=yes \
  kaman-goumou@192.168.122.1 \
  "virsh -c qemu:///system start ubuntu-cloud-vm-01 && \
   virsh -c qemu:///system domstate ubuntu-cloud-vm-01"
```

Résultat :

```text
Domain 'ubuntu-cloud-vm-01' started

running
```

---

### 14.19 Bilan de la section

La chaîne complète est maintenant validée :

```text
Terraform
    │
    ▼
libvirt provider 0.9.9
    │
    ▼
Kgoumou / libvirt
    │
    ├── ubuntu-cloud-vm-01
    │       ├── 2 vCPU
    │       ├── 2048 MiB RAM
    │       ├── q35 / x86_64
    │       ├── vda → QCOW2 / VirtIO
    │       ├── sda → Cloud-Init ISO
    │       └── vnet → default / VirtIO
    │
    └── backing store
            └── noble-server-cloudimg-amd64.img
```

Validations finales :

```text
Terraform Apply        : OK
Volume système         : OK
Backing store          : OK
Cloud-Init volume      : OK
Disque QCOW2           : OK
Driver QEMU            : OK
VirtIO                 : OK
Console série          : OK
Démarrage VM           : OK
État VM                : running
```

**Section 14 validée.**

---

## 15. Validation de Cloud-Init, SSH et du réseau

### 15.1 Objectif

Après le déploiement et le démarrage de la VM `ubuntu-cloud-vm-01`, cette section vérifie que Cloud-Init a réellement initialisé le système et que la VM dispose d'une connectivité réseau fonctionnelle.

Les éléments vérifiés sont :

- état de la VM ;
- interface réseau et adresse IP ;
- attribution DHCP ;
- accès SSH avec la clé configurée dans Cloud-Init ;
- création de l'utilisateur `kaman` ;
- appartenance au groupe `sudo` ;
- hostname ;
- état de Cloud-Init ;
- datasource Cloud-Init ;
- passerelle par défaut ;
- serveur DNS ;
- connectivité vers la passerelle ;
- connectivité Internet.

---

### 15.2 Validation de l'état et de l'adresse IP de la VM

Depuis `srv01-admin`, l'état de la VM et son interface réseau ont été vérifiés directement sur Kgoumou :

```bash
ssh kaman-goumou@192.168.122.1 \
  "virsh -c qemu:///system domstate ubuntu-cloud-vm-01 && \
   virsh -c qemu:///system domiflist ubuntu-cloud-vm-01 && \
   virsh -c qemu:///system domifaddr ubuntu-cloud-vm-01 --source lease"
```

Résultat :

```text
running

 Interface   Type      Source    Model    MAC
-------------------------------------------------------------
 vnet2       network   default   virtio   52:54:00:4f:f7:ee

 Name       MAC address          Protocol     Address
-------------------------------------------------------------------------------
 vnet2      52:54:00:4f:f7:ee    ipv4         192.168.122.193/24
```

La VM est donc :

```text
État       : running
Interface  : vnet2
Réseau     : default
Modèle     : virtio
MAC        : 52:54:00:4f:f7:ee
IPv4       : 192.168.122.193/24
```

L'adresse IP `192.168.122.193` a été attribuée par le DHCP du réseau libvirt `default`.

![Validation de l'adresse IP et de l'interface réseau de la VM](docs/images/15-02-vm-network-ip.png)

---

### 15.3 Configuration de l'authentification SSH vers Kgoumou

Afin de simplifier les connexions depuis `srv01-admin` vers l'hôte libvirt, la clé dédiée Terraform a été ajoutée à un `ssh-agent`.

La tentative initiale :

```bash
ssh-add ~/.ssh/terraform_libvirt_ed25519
```

a retourné :

```text
Could not open a connection to your authentication agent.
```

Un agent SSH a donc été démarré :

```bash
eval "$(ssh-agent -s)"
```

Résultat :

```text
Agent pid 42140
```

La clé dédiée a ensuite été chargée :

```bash
ssh-add ~/.ssh/terraform_libvirt_ed25519
```

Résultat :

```text
Identity added: /home/kaman/.ssh/terraform_libvirt_ed25519
(terraform-libvirt@srv01-admin)
```

La connexion vers Kgoumou fonctionne désormais sans avoir à préciser `-i` :

```bash
ssh kaman-goumou@192.168.122.1
```

Résultat :

```text
Welcome to Ubuntu 24.04.5 LTS
...
kaman-goumou@Kgoumou:~$
```

Cette configuration simplifie les commandes d'administration et de diagnostic depuis `srv01-admin`.

La configuration Terraform du provider conserve néanmoins explicitement sa clé dédiée.

---

### 15.4 Validation de Cloud-Init et de l'utilisateur

L'adresse IP de la VM étant connue, une connexion SSH directe a été effectuée :

```bash
ssh kaman@192.168.122.193 \
  'echo "=== IDENTITE ==="; id; echo; \
   echo "=== HOSTNAME ==="; hostname; echo; \
   echo "=== CLOUD-INIT ==="; cloud-init status --long'
```

Lors de la première connexion, SSH a demandé la confirmation de l'empreinte de la nouvelle VM.

Après validation avec `yes`, l'hôte a été ajouté aux `known_hosts`.

La connexion a ensuite abouti.

![Validation de l'utilisateur, du hostname et de Cloud-Init](docs/images/15-04-cloud-init-validation.png)

---

### 15.5 Validation de l'utilisateur créé par Cloud-Init

La commande `id` a retourné :

```text
uid=1000(kaman) gid=1000(kaman) groups=1000(kaman),27(sudo)
```

Cette sortie confirme que Cloud-Init a effectivement créé :

```text
Utilisateur : kaman
UID         : 1000
GID         : 1000
Groupe      : sudo (GID 27)
```

L'utilisateur dispose donc des privilèges sudo prévus dans `user-data`.

---

### 15.6 Validation du hostname

La commande :

```bash
hostname
```

a retourné :

```text
ubuntu-cloud-vm
```

Le hostname correspond à la valeur définie dans le fichier `meta-data` :

```yaml
instance-id: ubuntu-cloud-vm-01
local-hostname: ubuntu-cloud-vm
```

La configuration Cloud-Init du hostname est donc effective.

---

### 15.7 Validation de l'état de Cloud-Init

La commande :

```bash
cloud-init status --long
```

a retourné :

```text
status: done
extended_status: done
boot_status_code: enabled-by-generator
last_update: Thu, 01 Jan 1970 00:00:15 +0000
detail: DataSourceNoCloud [seed=/dev/sr0]
errors: []
recoverable_errors: {}
```

Les éléments importants sont :

```text
status: done
extended_status: done
```

Cloud-Init a donc terminé son traitement.

Aucune erreur n'a été signalée :

```text
errors: []
recoverable_errors: {}
```

Le datasource utilisé est :

```text
DataSourceNoCloud [seed=/dev/sr0]
```

Cela confirme que la VM a effectivement utilisé le support Cloud-Init attaché comme lecteur CD-ROM.

---

### 15.8 Validation de la configuration réseau dans la VM

Depuis la VM `ubuntu-cloud-vm`, la configuration réseau a été vérifiée avec :

```bash
echo "=== NETWORK ==="
ip -br addr

echo
echo "=== DEFAULT ROUTE ==="
ip route

echo
echo "=== DNS ==="
resolvectl status | grep -E 'DNS Servers|Current DNS Server' | head

echo
echo "=== CONNECTIVITY ==="
ping -c 3 192.168.122.1
ping -c 3 8.8.8.8
```

---

### 15.9 Validation de l'interface réseau

Résultat :

```text
=== NETWORK ===
lo               UNKNOWN        127.0.0.1/8 ::1/128
enp1s0           UP             192.168.122.193/24 metric 100 fe80::5054:ff:fe4f:f7ee/64
```

L'interface réseau de la VM est :

```text
Interface : enp1s0
État      : UP
IPv4      : 192.168.122.193/24
```

L'adresse IPv6 link-local présente est :

```text
fe80::5054:ff:fe4f:f7ee/64
```

---

### 15.10 Validation de la route par défaut

Résultat :

```text
default via 192.168.122.1 dev enp1s0 proto dhcp src 192.168.122.193 metric 100
192.168.122.0/24 dev enp1s0 proto kernel scope link src 192.168.122.193 metric 100
192.168.122.1 dev enp1s0 proto dhcp scope link src 192.168.122.193 metric 100
```

La route par défaut est :

```text
Destination : default
Gateway     : 192.168.122.1
Interface   : enp1s0
Source      : 192.168.122.193
```

---

### 15.11 Validation du DNS

La configuration DNS retournée par `resolvectl` est :

```text
Current DNS Server: 192.168.122.1
DNS Servers:       192.168.122.1
```

La VM utilise donc :

```text
DNS : 192.168.122.1
```

comme serveur DNS.

---

### 15.12 Validation de la connectivité vers la passerelle

La passerelle a été testée avec :

```bash
ping -c 3 192.168.122.1
```

Résultat :

```text
PING 192.168.122.1 (192.168.122.1) 56(84) bytes of data.
64 bytes from 192.168.122.1: icmp_seq=1 ttl=64 time=0.393 ms
64 bytes from 192.168.122.1: icmp_seq=2 ttl=64 time=0.326 ms
64 bytes from 192.168.122.1: icmp_seq=3 ttl=64 time=0.161 ms

--- 192.168.122.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss
rtt min/avg/max/mdev = 0.161/0.293/0.393/0.097 ms
```

Résultat :

```text
Passerelle      : 192.168.122.1
Paquets envoyés : 3
Paquets reçus   : 3
Perte           : 0 %
Latence moyenne : 0.293 ms
```

---

### 15.13 Validation de la connectivité Internet

La connectivité IP vers Internet a été testée avec :

```bash
ping -c 3 8.8.8.8
```

Résultat :

```text
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=115 time=50.7 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=115 time=55.4 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=115 time=156 ms

--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss
rtt min/avg/max/mdev = 50.703/87.510/156.436/48.775 ms
```

Résultat :

```text
Destination     : 8.8.8.8
Paquets envoyés : 3
Paquets reçus   : 3
Perte           : 0 %
Latence moyenne : 87.510 ms
```

La VM dispose donc d'une connectivité IP fonctionnelle vers Internet.

---

### 15.14 Bilan de la validation

Les éléments suivants ont été effectivement validés :

```text
VM running                         : OK
DHCP libvirt                       : OK
IPv4                               : 192.168.122.193/24
Interface VM                       : enp1s0
Interface VirtIO côté libvirt      : vnet2
MAC                                : 52:54:00:4f:f7:ee
Passerelle                         : 192.168.122.1
DNS                                : 192.168.122.1
Utilisateur kaman                  : OK
UID/GID                            : 1000/1000
Groupe sudo                        : OK
Hostname                           : ubuntu-cloud-vm
SSH par clé                        : OK
Cloud-Init status                  : done
Cloud-Init datasource              : DataSourceNoCloud
Cloud-Init errors                  : aucune
Ping passerelle                    : OK
Ping 8.8.8.8                       : OK
```

La chaîne d'initialisation est donc validée :

```text
Terraform
    │
    ▼
libvirt
    │
    ▼
VM Ubuntu
    │
    ├── DHCP
    │     └── 192.168.122.193
    │
    ├── Cloud-Init
    │     ├── DataSourceNoCloud
    │     ├── hostname
    │     ├── utilisateur kaman
    │     ├── groupe sudo
    │     └── clé SSH
    │
    └── Réseau
          ├── Gateway 192.168.122.1
          ├── DNS 192.168.122.1
          ├── Gateway ping → OK
          └── Internet ping → OK
```

**Section 15 validée.**

---

**KG-Lab**









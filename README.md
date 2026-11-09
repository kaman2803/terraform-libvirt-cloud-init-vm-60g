# Terraform Libvirt Cloud-Init — Déploiement automatisé de machines virtuelles Ubuntu

## 1. Présentation du projet

**Terraform Libvirt Cloud-Init** est un projet d'automatisation du déploiement de machines virtuelles Linux sur un hyperviseur KVM/libvirt local.

Il utilise Terraform pour décrire et gérer l'infrastructure sous forme de code (*Infrastructure as Code — IaC*) et Cloud-Init pour automatiser la configuration initiale des systèmes Ubuntu.

Le projet permet de déployer trois machines virtuelles Ubuntu Server 24.04 LTS à partir d'une image Cloud autonome au format QCOW2.

Chaque machine dispose de ses propres ressources :

- 1 vCPU ;
- 2 Gio de mémoire RAM ;
- 1 disque système QCOW2 de 20 Gio ;
- une interface réseau connectée au réseau libvirt `default` ;
- un utilisateur Linux configuré par Cloud-Init ;
- une authentification SSH par clé publique.

L'ensemble est géré de manière déclarative par Terraform grâce au provider `dmacvicar/libvirt`.

## 2. Objectifs du projet

Les objectifs principaux sont :

- Automatiser la création de machines virtuelles KVM.
- Gérer les ressources libvirt avec Terraform.
- Utiliser une image Ubuntu Cloud autonome comme source des disques.
- Préparer des disques QCOW2 de 20 Gio.
- Automatiser la configuration initiale avec Cloud-Init.
- Configurer un utilisateur Linux et son accès SSH.
- Démarrer automatiquement les machines lors de leur gestion par Terraform.
- Centraliser les paramètres dans un fichier de variables d'environnement.
- Maintenir la cohérence entre la configuration Terraform et l'infrastructure réelle.

## 3. Architecture technique

### 3.1. Environnement d'exécution

| Composant | Configuration |
|---|---|
| Hyperviseur | KVM / QEMU |
| Gestion de la virtualisation | libvirt |
| URI libvirt | `qemu:///system` |
| Système hôte | Ubuntu 24.04.5 LTS |
| Terraform | 1.17.1 |
| Provider Terraform | `dmacvicar/libvirt` 0.9.9 |
| Réseau virtuel | `default` |
| Type de réseau | NAT |
| Pool des disques VM | `default` |
| Pool des ISO Cloud-Init | `iso` |
| Image source | Ubuntu Noble Server Cloud Image |
| Format des disques | QCOW2 |

### 3.2. Machines virtuelles déployées

| Paramètre | srv-node1 | srv-node2 | srv-node3 |
|---|---|---|---|
| Nom Terraform | `node1` | `node2` | `node3` |
| Hostname Linux | srv-node1 | srv-node2 | srv-node3 |
| vCPU | 1 | 1 | 1 |
| RAM | 2048 Mio | 2048 Mio | 2048 Mio |
| Disque système | 20 Gio | 20 Gio | 20 Gio |
| Format | QCOW2 | QCOW2 | QCOW2 |
| Réseau | default | default | default |

### 3.3. Architecture réseau

Les trois machines virtuelles sont connectées au réseau virtuel libvirt `default`.

Caractéristiques du réseau :

- Type : NAT.
- Bridge : `virbr0`.
- Passerelle : `192.168.122.1`.
- Masque : `/24`.
- Plage DHCP : `192.168.122.100` à `192.168.122.254`.

Les adresses IP sont attribuées dynamiquement par le serveur DHCP de libvirt.

Pour consulter les baux DHCP :

```bash
virsh net-dhcp-leases default
```

Les adresses IP peuvent changer selon les attributions DHCP.

## 4. Structure du projet

L'arborescence actuelle est organisée de la manière suivante :

```text
terraform-libvirt-cloud-init/
│
├── environments/
│   └── kgoumou/
│       └── terraform.tfvars
│
├── images/
│   └── ubuntu-noble-20g.qcow2
│
├── templates/
│   ├── meta-data.yaml.tftpl
│   └── user-data.yaml.tftpl
│
├── terraform/
│   ├── cloudinit.tf
│   ├── domain.tf
│   ├── locals.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── versions.tf
│   ├── volume_20g.tf
│   ├── terraform.tfstate
│   └── terraform.tfstate.backup
│
└── README.md
```

### 4.1. Rôle des répertoires

| Répertoire | Rôle |
|---|---|
| `environments/` | Paramètres propres à chaque environnement |
| `images/` | Images QCOW2 utilisées pour créer les volumes |
| `templates/` | Modèles de configuration Cloud-Init |
| `terraform/` | Configuration Terraform et état local |

### 4.2. Rôle des fichiers Terraform

**`versions.tf`**

Déclare les contraintes de version de Terraform et les providers nécessaires au projet.

**`provider.tf`**

Configure la connexion au service libvirt :

```hcl
provider "libvirt" {
  uri = var.libvirt_uri
}
```

L'utilisation de `qemu:///system` permet de travailler directement avec le service libvirt local.

**`variables.tf`**

Déclare les variables utilisées par le projet :

- nom du projet ;
- URI libvirt ;
- pools de stockage ;
- réseau libvirt ;
- chemin de l'image source ;
- utilisateur SSH ;
- clé publique SSH ;
- configuration des machines virtuelles.

Une validation contrôle notamment le nombre de vCPU, la mémoire minimale et la capacité minimale des disques.

**`locals.tf`**

Centralise les expressions et les valeurs calculées :

- nombre de VM ;
- noms des VM ;
- tags communs ;
- génération des données Cloud-Init à partir des templates.

**`volume_20g.tf`**

Déclare les volumes QCOW2 de 20 Gio à partir de l'image Ubuntu autonome préparée dans `images/`.

**`cloudinit.tf`**

Déclare les ressources nécessaires à la génération des données Cloud-Init et à leur stockage sous forme d'ISO.

**`domain.tf`**

Déclare les domaines libvirt correspondant aux trois machines virtuelles.

Il définit notamment :

- le nom de la VM ;
- le nombre de vCPU ;
- la mémoire ;
- le type de machine Q35 ;
- le disque système VirtIO ;
- le lecteur CD-ROM Cloud-Init ;
- la console série ;
- l'interface réseau VirtIO ;
- le comportement de fonctionnement de la VM avec `running = true`.

## 5. Préparation de l'image Ubuntu autonome

### 5.1. Image Ubuntu source

Le projet utilise l'image Ubuntu Cloud suivante :

```text
/home/kaman-goumou/lab/kvm/iso/base/noble-server-cloudimg-amd64.img
```

Cette image constitue la base de préparation des disques système.

### 5.2. Création d'une copie QCOW2 autonome

Le répertoire `images/` a été créé pour stocker l'image préparée.

La conversion a été réalisée avec :

```bash
qemu-img convert -p -f qcow2 -O qcow2 \
  /home/kaman-goumou/lab/kvm/iso/base/noble-server-cloudimg-amd64.img \
  images/ubuntu-noble-20g.qcow2
```

Cette opération produit une copie autonome au format QCOW2.

### 5.3. Extension à 20 Gio

La commande suivante a été exécutée :

```bash
qemu-img resize images/ubuntu-noble-20g.qcow2 20G
```

Résultat :

```text
Image resized.
```

### 5.4. Vérification de l'image

```bash
qemu-img info images/ubuntu-noble-20g.qcow2
```

Caractéristiques vérifiées :

- Format : QCOW2.
- Taille virtuelle : 20 Gio.
- Taille physique : environ 1,76 Gio.
- Image non corrompue.
- Absence de backing file.

La distinction entre taille virtuelle et taille physique est importante : les 20 Gio représentent la capacité logique du disque, tandis que l'espace physique occupé dépend des blocs effectivement utilisés.

## 6. Configuration de l'environnement Terraform

Le fichier suivant contient les paramètres propres à l'environnement Kgoumou :

```text
environments/kgoumou/terraform.tfvars
```

Extrait de configuration :

```hcl
project_name    = "terraform-libvirt-cloud-init"
libvirt_uri     = "qemu:///system"
storage_pool    = "default"
cloudinit_pool  = "iso"
network_name    = "default"

base_image_path = "/home/kaman-goumou/lab/kvm/iso/base/noble-server-cloudimg-amd64.img"

ssh_username   = "kaman"
ssh_public_key = "CLE_PUBLIQUE_SSH"

vms = {
  node1 = {
    hostname = "srv-node1"
    vcpu     = 1
    memory   = 2048
    disk_gb  = 20
  }

  node2 = {
    hostname = "srv-node2"
    vcpu     = 1
    memory   = 2048
    disk_gb  = 20
  }

  node3 = {
    hostname = "srv-node3"
    vcpu     = 1
    memory   = 2048
    disk_gb  = 20
  }
}
```

La clé publique SSH doit être remplacée par celle de l'environnement cible.

Le fichier `terraform.tfvars` contient des paramètres propres à la machine hôte. Il ne doit pas être partagé sans vérification préalable.

## 7. Configuration Cloud-Init

Cloud-Init assure la personnalisation initiale des machines virtuelles lors de leur premier démarrage.

Le projet utilise deux templates :

- `templates/meta-data.yaml.tftpl`
- `templates/user-data.yaml.tftpl`

### 7.1. Meta-data

Le fichier `meta-data.yaml.tftpl` permet de transmettre notamment :

- l'identifiant de l'instance ;
- le hostname de la machine.

Les valeurs sont générées à partir de la configuration de chaque VM.

### 7.2. User-data

Le fichier `user-data.yaml.tftpl` définit notamment :

- la création de l'utilisateur Linux ;
- les privilèges sudo ;
- le shell utilisé ;
- la clé publique SSH autorisée ;
- la désactivation de l'authentification SSH par mot de passe ;
- la désactivation de la connexion directe de root.

L'utilisateur configuré est `kaman`.

### 7.3. Génération des ISO Cloud-Init

Terraform utilise les données calculées dans `locals.tf` pour générer les ressources Cloud-Init.

Chaque machine dispose de ses propres données et de son propre volume ISO.

Les fichiers ISO sont stockés dans le pool libvirt `iso`.

## 8. Déploiement de l'infrastructure

### 8.1. Initialisation Terraform

Depuis le répertoire du projet :

```bash
terraform -chdir=terraform init
```

Cette commande initialise le répertoire Terraform et télécharge les providers nécessaires.

### 8.2. Formatage des fichiers

```bash
terraform -chdir=terraform fmt
```

Cette commande applique le formatage standard des fichiers HCL.

### 8.3. Validation de la configuration

```bash
terraform -chdir=terraform validate
```

Elle vérifie la cohérence syntaxique et structurelle de la configuration Terraform.

### 8.4. Prévisualisation du déploiement

```bash
terraform -chdir=terraform plan \
  -var-file=../environments/kgoumou/terraform.tfvars
```

Cette commande compare la configuration déclarée à l'infrastructure existante et présente les actions proposées.

### 8.5. Application de la configuration

```bash
terraform -chdir=terraform apply \
  -var-file=../environments/kgoumou/terraform.tfvars
```

Terraform crée ou met à jour les ressources nécessaires après confirmation.

Le déploiement réalisé dans ce projet a créé :

- 3 volumes QCOW2 de 20 Gio ;
- 3 ressources Cloud-Init ;
- 3 volumes ISO Cloud-Init ;
- 3 domaines libvirt.

Le démarrage des domaines est demandé par `running = true`.

## 9. Vérification des machines virtuelles

### 9.1. Liste des machines virtuelles

```bash
virsh list --all
```

Cette commande permet de consulter les domaines libvirt et leur état.

### 9.2. Vérification des informations d'une VM

Exemple :

```bash
virsh dominfo srv-node1
```

Cette commande permet de consulter les caractéristiques du domaine.

### 9.3. Vérification des adresses IP

```bash
virsh net-dhcp-leases default
```

Cette commande affiche les baux DHCP attribués sur le réseau `default`.

Pour consulter l'adresse détectée d'une VM :

```bash
virsh domifaddr srv-node1
```

### 9.4. Vérification du stockage

```bash
virsh vol-list default
```

Cette commande permet de vérifier la présence des disques virtuels dans le pool de stockage.

Pour examiner les caractéristiques d'un disque :

```bash
qemu-img info /var/lib/libvirt/images/srv-node1-20g.qcow2
```

## 10. Accès SSH aux machines virtuelles

L'accès SSH est configuré par Cloud-Init à partir de la clé publique déclarée dans les variables Terraform.

Depuis la machine cliente :

```bash
ssh kaman@ADRESSE_IP
```

Exemple correspondant à la validation réalisée pour `srv-node1` :

```bash
ssh kaman@192.168.122.209
```

L'adresse IP est attribuée dynamiquement : il faut vérifier le bail DHCP avant de réutiliser cet exemple.

## 11. Validation du système invité

Après connexion SSH, les commandes suivantes permettent de contrôler le système.

### 11.1. Vérification du hostname et du système

```bash
hostnamectl
```

La validation de `srv-node1` a confirmé :

- hostname : `srv-node1` ;
- système : Ubuntu 24.04.5 LTS ;
- virtualisation : KVM ;
- architecture : x86-64.

### 11.2. Vérification des disques

```bash
lsblk
```

Cette commande affiche les périphériques de stockage et leurs partitions.

La vérification réalisée sur `srv-node1` a montré :

- disque système `vda` : 20 Gio ;
- partition racine `vda1` : environ 19 Gio ;
- partition EFI `vda15` ;
- partition `/boot` `vda16`.

### 11.3. Vérification de l'espace disponible

```bash
df -h /
```

Résultat observé sur `srv-node1` :

```text
Filesystem      Size  Used  Avail  Use%
/dev/vda1        19G  1.7G    17G    9%
```

Cette vérification confirme que la partition racine utilise l'espace disponible du disque de 20 Gio.

## 12. Gestion du cycle de vie avec Terraform

Terraform permet de maintenir les machines virtuelles dans l'état déclaré dans les fichiers de configuration.

### 12.1. Vérification des ressources suivies

```bash
terraform -chdir=terraform state list
```

Cette commande affiche les ressources actuellement suivies dans l'état Terraform.

### 12.2. Vérification des changements

```bash
terraform -chdir=terraform plan \
  -var-file=../environments/kgoumou/terraform.tfvars
```

Lorsque l'infrastructure correspond à la configuration, Terraform affiche :

```text
No changes. Your infrastructure matches the configuration.
```

### 12.3. Gestion de l'état de fonctionnement

Dans `domain.tf`, la propriété :

```hcl
running = true
```

indique que Terraform doit maintenir le domaine en fonctionnement.

Si une VM est arrêtée manuellement, une prochaine opération Terraform peut détecter cette différence et demander son redémarrage.

Cette propriété ne doit pas être confondue avec l'option d'autostart de libvirt au démarrage de l'hôte.

## 13. Nettoyage des anciennes ressources

Au cours de l'évolution du projet, les premiers volumes QCOW2 ont été remplacés par des volumes autonomes de 20 Gio.

Les anciennes ressources `libvirt_volume.vm_disk` ont été retirées de la configuration et supprimées avec Terraform.

Les nouveaux volumes sont déclarés dans :

```text
terraform/volume_20g.tf
```

Les anciennes ressources ont été supprimées avec succès :

```text
Apply complete! Resources: 0 added, 0 changed, 3 destroyed.
```

La vérification du pool `default` a confirmé la présence des trois nouveaux disques et la disparition des anciens.

Le nettoyage a également supprimé les anciennes configurations mono-VM et les anciens fichiers Cloud-Init devenus inutiles.

## 14. Bonnes pratiques

- Toujours exécuter `terraform plan` avant `terraform apply`.
- Ne jamais supprimer manuellement un disque encore géré par Terraform.
- Vérifier les dépendances avant de supprimer un fichier `.tf`.
- Conserver une sauvegarde de l'état Terraform avant une opération importante.
- Ne pas supprimer le fichier `terraform.tfstate` pendant que l'infrastructure est gérée par Terraform.
- Ne pas partager les fichiers contenant des paramètres sensibles.
- Vérifier les adresses DHCP avant les connexions SSH.
- Contrôler les disques et les domaines libvirt après chaque opération importante.
- Conserver une séparation claire entre les fichiers Terraform, les variables d'environnement et les templates Cloud-Init.

## 15. État actuel du projet

Le projet a abouti au déploiement de trois machines virtuelles Ubuntu Server sur KVM/libvirt.

| Élément | État |
|---|---|
| Configuration Terraform | Opérationnelle |
| Provider libvirt | Configuré |
| Image Ubuntu autonome 20 Gio | Préparée |
| Volumes QCOW2 | 3 créés |
| Configuration Cloud-Init | Déployée |
| ISO Cloud-Init | 3 créés |
| Domaines libvirt | 3 créés |
| Démarrage Terraform | Configuré |
| Accès SSH de srv-node1 | Validé |
| Vérification du système de srv-node1 | Validée |
| Nettoyage des anciens volumes | Terminé |
| Cohérence Terraform | Validée |

**Remarque sur les validations :** `srv-node1` a fait l'objet des contrôles détaillés SSH, hostname, système et stockage. Les vérifications équivalentes de `srv-node2` et `srv-node3` restent à documenter individuellement.

## 16. Conclusion

Ce projet met en pratique l'automatisation d'une infrastructure de virtualisation locale avec Terraform, KVM, QEMU, libvirt et Cloud-Init.

Il illustre la gestion déclarative des ressources, la préparation des images système, la création des disques virtuels, la personnalisation des machines et le contrôle de leur cycle de vie.

Il constitue une base pour des évolutions futures telles que :

- l'automatisation de la configuration système avec Ansible ;
- le déploiement de services Linux ;
- la mise en place de clusters ;
- la supervision des machines virtuelles ;
- l'intégration dans une chaîne d'automatisation Infrastructure as Code.

---

**Projet :** Terraform Libvirt Cloud-Init  
**Plateforme :** KVM / QEMU / libvirt  
**Automatisation :** Terraform  
**Initialisation des VM :** Cloud-Init  
**Système invité :** Ubuntu Server 24.04 LTS

# Déploiement d'une VM Ubuntu avec Terraform, KVM/libvirt et Cloud-Init

## 1. Préparation du projet

### 1.1. Création du répertoire de travail

Le nouveau laboratoire est réalisé dans un répertoire indépendant afin de préserver le projet Terraform initial, déjà testé et publié sur GitHub.

```bash
mkdir -p ~/lab/terraform-libvirt-cloud-init-vm-60g
cd ~/lab/terraform-libvirt-cloud-init-vm-60g
```

### 1.2. Clonage du dépôt GitHub

Le projet de référence est cloné depuis le dépôt privé :

```bash
git clone git@github.com:kaman2803/terraform-libvirt-cloud-init-multi-vm-v1.git .
```

Le clonage a été effectué avec succès.

La branche utilisée est `main` et le dépôt distant est configuré en SSH.

## 2. Organisation du projet

### 2.1. Adaptation du fichier de documentation

L'ancien fichier `README.md` a été supprimé afin de reprendre le guide d'utilisation comme document principal.

```bash
rm README.md
mv GUIDE_UTILISATION_TERRAFORM_LIBVIRT_CLOUD_INIT.md README.md
```

### 2.2. Création des répertoires du nouveau laboratoire

Le répertoire destiné à accueillir les images disque a été créé :

```bash
mkdir -p images
```

Le répertoire des paramètres propres à l'environnement a également été créé :

```bash
mkdir -p environments/kgoumou
```

### 2.3. Structure obtenue

La commande suivante permet de vérifier l'organisation du projet :

```bash
tree
```

Résultat obtenu :

```text
.
├── environments
│   └── kgoumou
│       └── terraform.tfvars
├── images
│   └── ubuntu-noble-60g.qcow2
├── README.md
├── templates
│   ├── meta-data.yaml.tftpl
│   └── user-data.yaml.tftpl
└── terraform
    ├── cloudinit.tf
    ├── domain.tf
    ├── locals.tf
    ├── provider.tf
    ├── variables.tf
    ├── versions.tf
    └── volume.tf
```

## 3. Préparation du disque Ubuntu de 60 Gio

### 3.1. Vérification de l'image Ubuntu Cloud originale

L'image Ubuntu Cloud utilisée comme source est située dans le répertoire :

```text
/home/kaman-goumou/lab/kvm/iso/base/noble-server-cloudimg-amd64.img
```

Vérification :

```bash
ls -lh /home/kaman-goumou/lab/kvm/iso/base/noble-server-cloudimg-amd64.img
```

Résultat obtenu :

```text
-rw-r--r-- 1 libvirt-qemu kvm 597M Sep 28 05:28 noble-server-cloudimg-amd64.img
```

### 3.2. Création d'un disque autonome au format QCOW2

Une nouvelle image disque a été créée directement dans le répertoire `images/` du projet.

La conversion produit un fichier autonome, indépendant du fichier source.

```bash
qemu-img convert -p -f qcow2 -O qcow2 \
  /home/kaman-goumou/lab/kvm/iso/base/noble-server-cloudimg-amd64.img \
  images/ubuntu-noble-60g.qcow2
```

La conversion s'est terminée à 100 %.

### 3.3. Redimensionnement du disque à 60 Gio

```bash
qemu-img resize images/ubuntu-noble-60g.qcow2 60G
```

Résultat obtenu :

```text
Image resized.
```

### 3.4. Vérification des caractéristiques du disque

```bash
qemu-img info images/ubuntu-noble-60g.qcow2
```

Résultat obtenu :

```text
file format: qcow2
virtual size: 60 GiB (64424509440 bytes)
disk size: 1.76 GiB
cluster_size: 65536
corrupt: false
```

Le disque possède donc une capacité virtuelle de 60 Gio. Son espace physique occupé est d'environ 1,76 Gio à ce stade.

### 3.5. Vérification de l'intégrité

```bash
qemu-img check images/ubuntu-noble-60g.qcow2
```

Résultat obtenu :

```text
No errors were found on the image.
28791/983040 = 2.93% allocated, 0.00% fragmented, 0.00% compressed clusters
Image end offset: 1887633408
```

<text>Le contrôle ne signale aucune erreur sur l'image QCOW2.</text>

## 4. Adaptation de la configuration Terraform à une VM de 60 Gio

L'objectif de cette étape est d'adapter le projet initial, conçu pour déployer trois machines virtuelles, afin de provisionner une seule VM Ubuntu avec les caractéristiques suivantes :

| Ressource | Configuration |
|---|---:|
| Nom de la VM | `srv-ubuntu-60g` |
| Nombre de vCPU | 4 |
| Mémoire RAM | 6144 Mio (6 Gio) |
| Capacité disque | 60 Gio |
| Image | Ubuntu Server 24.04 Cloud |
| Format disque | QCOW2 |
| Pool de stockage | `default` |
| Pool Cloud-Init | `iso` |
| Réseau libvirt | `default` |

### 4.1. Création du fichier de variables d'environnement

Le fichier `terraform.tfvars` permet de définir les paramètres spécifiques à l'environnement d'exécution.

Il est placé dans :

```text
environments/kgoumou/terraform.tfvars
```

Ouverture du fichier :

```bash
nano environments/kgoumou/terraform.tfvars
```

Configuration mise en place :

```hcl
project_name   = "terraform-libvirt-cloud-init-vm-60g"
libvirt_uri    = "qemu:///system"
storage_pool   = "default"
cloudinit_pool = "iso"
network_name   = "default"

ssh_username = "kaman"

ssh_public_key = "VOTRE_CLE_PUBLIQUE_SSH"

vms = {
  ubuntu60 = {
    hostname = "srv-ubuntu-60g"
    vcpu     = 4
    memory   = 6144
    disk_gb  = 60
  }
}
```

La valeur `VOTRE_CLE_PUBLIQUE_SSH` représente la clé publique SSH réelle configurée localement. Elle ne doit pas être remplacée par une clé fictive.

**Explication des paramètres :**

- `project_name` : identifiant du projet Terraform.
- `libvirt_uri` : connexion à l'hyperviseur libvirt système.
- `storage_pool` : pool dans lequel le disque de la VM sera stocké.
- `cloudinit_pool` : pool destiné aux volumes Cloud-Init.
- `network_name` : réseau virtuel libvirt utilisé par la VM.
- `ssh_username` : compte utilisateur créé pour la connexion SSH.
- `ssh_public_key` : clé publique autorisée pour l'authentification SSH.
- `vms` : map décrivant les machines virtuelles à créer.

Dans notre cas, la map `vms` ne contient qu'une seule entrée : `ubuntu60`.

### 4.2. Suppression de la variable `base_image_path`

Dans l'ancienne architecture, la variable `base_image_path` désignait le chemin de l'image Ubuntu Cloud originale.

Cependant, dans le nouveau laboratoire, le disque autonome a déjà été préparé dans le répertoire `images/` :

```text
images/ubuntu-noble-60g.qcow2
```

La ressource de stockage Terraform devra utiliser directement ce nouveau disque comme source.

Nous avons donc vérifié les références à cette variable :

```bash
grep -R "base_image_path" terraform/
```

Résultat initial :

```text
terraform/variables.tf:variable "base_image_path" {
```

La variable était uniquement déclarée dans `variables.tf` et n'était utilisée dans aucune autre ressource Terraform.

Nous avons ensuite repéré précisément sa déclaration :

```bash
grep -n -A 5 -B 2 'variable "base_image_path"' terraform/variables.tf
```

Résultat obtenu :

```text
24-}
25-
26:variable "base_image_path" {
27-  description = "Chemin de l'image Ubuntu Cloud source"
28-  type        = string
29-}
30-
31-variable "ssh_username" {
```

Modification du fichier :

```bash
nano terraform/variables.tf
```

Le bloc suivant a été supprimé :

```hcl
variable "base_image_path" {
  description = "Chemin de l'image Ubuntu Cloud source"
  type        = string
}
```

Une dernière recherche a permis de confirmer sa suppression :

```bash
grep -R "base_image_path" terraform/
```

**Résultat obtenu : aucune sortie.**

La variable a également été retirée du fichier `environments/kgoumou/terraform.tfvars`.

Cette suppression est cohérente avec la nouvelle architecture : Terraform utilisera directement le disque autonome préparé dans le projet.

### 4.3. Vérification du fichier `terraform.tfvars`

Le contenu du fichier a été vérifié avec :

```bash
cat environments/kgoumou/terraform.tfvars
```

La configuration obtenue contient :

```hcl
project_name   = "terraform-libvirt-cloud-init-vm-60g"
libvirt_uri    = "qemu:///system"
storage_pool   = "default"
cloudinit_pool = "iso"
network_name   = "default"

ssh_username = "kaman"

ssh_public_key = "ssh-ed25519 [clé publique configurée localement]"

vms = {
  ubuntu60 = {
    hostname = "srv-ubuntu-60g"
    vcpu     = 4
    memory   = 6144
    disk_gb  = 60
  }
}
```

La clé publique est masquée dans cette documentation.

### 4.4. Vérification de l'ancienne configuration de stockage

Nous avons comparé le fichier `volume.tf` du projet de référence avec celui du nouveau projet.

Le fichier du nouveau projet contenait encore l'ancienne ressource :

```hcl
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
```

Cette configuration fait encore référence à l'ancienne image `ubuntu-noble-20g.qcow2`.

Elle devra être adaptée pour utiliser :

```text
images/ubuntu-noble-60g.qcow2
```

Il faudra également vérifier les références à la ressource `libvirt_volume.vm_disk_20g` dans les autres fichiers Terraform, notamment `domain.tf`, avant de modifier son nom.

**État de la section 4 :** la configuration de l'environnement est préparée, `base_image_path` a été supprimée et l'ancienne ressource de stockage a été identifiée. L'adaptation de `volume.tf` et la vérification de ses dépendances restent à effectuer.

### 4.5. Mise en cohérence des références entre les ressources Terraform

Après la modification de `volume.tf`, nous avons recherché les références à l'ancien et au nouveau nom de la ressource :

```bash
grep -R "vm_disk_20g\|vm_disk_60g" terraform/
```

Résultat initial :

```text
terraform/domain.tf:            file = libvirt_volume.vm_disk_20g[each.key].path
terraform/volume.tf:resource "libvirt_volume" "vm_disk_60g" {
```

Nous avons identifié une référence obsolète dans `domain.tf`.

La référence :

```hcl
file = libvirt_volume.vm_disk_20g[each.key].path
```

a été remplacée par :

```hcl
file = libvirt_volume.vm_disk_60g[each.key].path
```

Une nouvelle vérification a confirmé la cohérence :

```bash
grep -R "vm_disk_20g\|vm_disk_60g" terraform/
```

Résultat obtenu :

```text
terraform/domain.tf:            file = libvirt_volume.vm_disk_60g[each.key].path
terraform/volume.tf:resource "libvirt_volume" "vm_disk_60g" {
```

Les deux fichiers utilisent désormais le même nom de ressource Terraform : `vm_disk_60g`.

### 4.6. Analyse de la définition de la machine virtuelle — `domain.tf`

Le fichier `terraform/domain.tf` définit les machines virtuelles libvirt.

La ressource utilise `for_each = local.vms`, ce qui permet de créer une machine virtuelle pour chaque entrée de la map `vms`.

Les principales propriétés sont :

| Propriété | Fonction |
|---|---|
| `name` | Nom de la VM |
| `type` | Type d'hyperviseur : KVM |
| `memory` | Quantité de RAM |
| `memory_unit` | Unité de mémoire : MiB |
| `vcpu` | Nombre de processeurs virtuels |
| `running` | Démarrage de la VM après sa création |

La configuration matérielle est récupérée dynamiquement depuis `terraform.tfvars`.

Pour notre laboratoire, les valeurs sont de 4 vCPU et 6144 Mio de RAM.

#### Configuration du disque système

Le disque système est associé à la ressource `libvirt_volume.vm_disk_60g` :

```hcl
source = {
  file = {
    file = libvirt_volume.vm_disk_60g[each.key].path
  }
}
```

Il est présenté à la machine virtuelle sous le périphérique `vda`, avec le bus VirtIO.

Le commentaire décrivant ce disque doit indiquer une capacité de 60 Gio.

#### Configuration Cloud-Init

Un second disque est présenté à la VM comme lecteur CD-ROM. Il contient les données Cloud-Init propres à la machine virtuelle.

La ressource utilisée est `libvirt_volume.vm_init_iso`.

#### Configuration réseau

L'interface réseau utilise le réseau virtuel libvirt défini par `var.network_name`, avec le modèle VirtIO.

#### Console

Une console série de type PTY est configurée pour faciliter l'accès à la machine virtuelle.

**État :** les paramètres CPU, RAM, disque, réseau et console sont définis dynamiquement ou explicitement dans `domain.tf`. La configuration Cloud-Init et les autres dépendances restent à vérifier.

### 4.7. Analyse des variables locales — `locals.tf`

Le fichier `terraform/locals.tf` définit les valeurs locales utilisées dans le projet.

Ces valeurs permettent de centraliser certaines expressions et de préparer les données nécessaires aux ressources Terraform.

#### a. Calcul du nombre de machines virtuelles

```hcl
vm_count = length(var.vms)
```

Cette expression calcule le nombre de machines virtuelles déclarées dans la variable `vms`.

Dans notre configuration, une seule machine est déclarée. Le résultat est donc `1`.

#### b. Récupération des identifiants des VM

```hcl
vm_names = keys(var.vms)
```

Cette expression récupère les clés de la map `vms`. Dans notre cas, elle retourne `ubuntu60`.

#### c. Définition des tags communs

```hcl
common_tags = {
  project     = var.project_name
  environment = "kgoumou"
  managed_by  = "terraform"
}
```

Ces informations identifient le projet, son environnement et l'outil utilisé pour gérer l'infrastructure.

#### d. Centralisation des machines virtuelles

```hcl
vms = var.vms
```

Cette affectation rend la configuration des machines virtuelles accessible à travers `local.vms`.

#### e. Préparation des données Cloud-Init

Le bloc `cloudinit` utilise une boucle `for` pour préparer les données de chaque machine virtuelle.

La fonction `templatefile()` charge deux modèles :

- `meta-data.yaml.tftpl` : prépare l'identifiant de l'instance et son nom d'hôte.
- `user-data.yaml.tftpl` : prépare les informations de l'utilisateur et sa clé publique SSH.

Les données préparées sont ensuite utilisées par les ressources Cloud-Init du projet.

**État de la vérification :** `locals.tf` est compatible avec la configuration d'une seule VM. Aucune modification n'est nécessaire.

### 4.8. Analyse du template Cloud-Init `meta-data.yaml.tftpl`

Le fichier `templates/meta-data.yaml.tftpl` contient les métadonnées permettant d'identifier la machine virtuelle.

Contenu vérifié :

```yaml
instance-id: ${instance_id}
local-hostname: ${hostname}
```

**Directive `instance-id`**

```yaml
instance-id: ${instance_id}
```

Cette directive définit l'identifiant de l'instance Cloud-Init. La variable `${instance_id}` est remplacée par Terraform grâce à la fonction `templatefile()`.

Dans notre configuration, sa valeur est `ubuntu60`.

**Directive `local-hostname`**

```yaml
local-hostname: ${hostname}
```

Cette directive définit le nom d'hôte local de la machine virtuelle. La variable `${hostname}` est également remplacée par Terraform.

Dans notre configuration, sa valeur est `srv-ubuntu-60g`.

**Contenu obtenu après interpolation :**

```yaml
instance-id: ubuntu60
local-hostname: srv-ubuntu-60g
```

**État de la vérification :** le template est compatible avec notre VM et ne nécessite aucune modification.

### 4.9. Analyse du template Cloud-Init `user-data.yaml.tftpl`

Le fichier `templates/user-data.yaml.tftpl` définit la configuration initiale de l'utilisateur et les paramètres de sécurité SSH de la machine virtuelle.

Contenu vérifié :

```yaml
#cloud-config

users:
  - name: ${ssh_username}
    groups:
      - sudo
    shell: /bin/bash
    sudo:
      - ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_public_key}

ssh_pwauth: false
disable_root: true
```

**a. Identification du format**

La directive `#cloud-config` indique à Cloud-Init que le fichier utilise le format Cloud-Config.

**b. Création de l'utilisateur**

La section `users` définit le compte utilisateur à créer. La variable `${ssh_username}` est remplacée par la valeur définie dans `terraform.tfvars`, soit `kaman`.

**c. Attribution des privilèges**

L'utilisateur est ajouté au groupe `sudo` et reçoit une autorisation sudo sans saisie de mot de passe :

```yaml
sudo:
  - ALL=(ALL) NOPASSWD:ALL
```

Cette configuration est adaptée à un laboratoire, mais doit être évaluée avec attention dans un environnement de production.

**d. Définition du shell**

```yaml
shell: /bin/bash
```

Le shell par défaut de l'utilisateur est Bash.

**e. Installation de la clé publique SSH**

La directive `ssh_authorized_keys` ajoute la clé publique fournie dans `terraform.tfvars` au fichier `authorized_keys` de l'utilisateur.

**f. Sécurisation de l'accès SSH**

```yaml
ssh_pwauth: false
disable_root: true
```

La première directive désactive l'authentification SSH par mot de passe. La seconde désactive l'accès direct au compte root.

**Fonctionnement global :** Terraform transmet les données interpolées à Cloud-Init. Au premier démarrage, Cloud-Init configure l'utilisateur, ses privilèges et son accès SSH.

**État de la vérification :** le template est cohérent avec les variables définies dans `terraform.tfvars`. Aucune modification n'est nécessaire à ce stade.

### 4.10. Analyse de la configuration Cloud-Init — `cloudinit.tf`

Le fichier `terraform/cloudinit.tf` définit deux ressources permettant de générer et de stocker les données Cloud-Init nécessaires à l'initialisation de la machine virtuelle.

#### a. Génération du support Cloud-Init

La première ressource est :

```hcl
resource "libvirt_cloudinit_disk" "vm_init" {
  for_each = local.cloudinit

  name      = "${each.key}-init"
  user_data = each.value.user_data
  meta_data = each.value.meta_data
}
```

Elle utilise les données préparées dans `locals.tf` pour générer le support Cloud-Init de chaque machine virtuelle.

- `for_each` : parcourt les configurations Cloud-Init.
- `name` : définit le nom du support généré.
- `user_data` : transmet les paramètres de configuration de l'utilisateur et de SSH.
- `meta_data` : transmet les informations d'identification de l'instance.

#### b. Création du volume Cloud-Init

La deuxième ressource est :

```hcl
resource "libvirt_volume" "vm_init_iso" {
  for_each = local.cloudinit

  name = "${each.key}-init.iso"
  pool = var.cloudinit_pool
}
```

Elle crée un volume dans le pool libvirt défini par `cloudinit_pool`.

Dans notre environnement, le pool utilisé est `iso`.

#### c. Association des données générées au volume

```hcl
create = {
  content = {
    url = libvirt_cloudinit_disk.vm_init[each.key].path
  }
}
```

Cette configuration récupère le chemin du support Cloud-Init généré par la première ressource afin de créer le volume correspondant dans libvirt.

#### d. Définition du format

```hcl
target = {
  format = {
    type = "iso"
  }
}
```

Le volume est déclaré au format ISO. Il sera présenté à la machine virtuelle comme un lecteur CD-ROM.

#### Fonctionnement global

Les templates sont d'abord interpolés par Terraform dans `locals.tf`. Les données obtenues sont utilisées par `libvirt_cloudinit_disk.vm_init`, puis associées à un volume libvirt dans le pool `iso`.

Ce volume est ensuite attaché à la VM dans `domain.tf`.

**État de la vérification :** la configuration Cloud-Init est compatible avec notre architecture à une seule VM. Aucune modification n'est nécessaire à ce stade.

### 4.11. Configuration du fournisseur libvirt — `provider.tf`

Le fichier `terraform/provider.tf` configure le fournisseur utilisé par Terraform pour communiquer avec l'hyperviseur libvirt.

Contenu vérifié :

```hcl
provider "libvirt" {
  uri = var.libvirt_uri
}
```

**Explication des directives :**

- `provider "libvirt"` : déclare le fournisseur libvirt.
- `uri` : définit l'adresse de connexion au service libvirt.
- `var.libvirt_uri` : récupère la valeur définie dans `terraform.tfvars`.

Dans notre environnement, la valeur configurée est :

```hcl
libvirt_uri = "qemu:///system"
```

Cette URI permet à Terraform de communiquer avec l'instance système de libvirt et de gérer les ressources KVM.

**État de la vérification :** le fournisseur utilise une variable d'environnement correctement définie dans `terraform.tfvars`. Aucune modification n'est nécessaire à ce stade.

### 4.12. Déclaration des versions — `versions.tf`

Le fichier `terraform/versions.tf` définit les contraintes de versions nécessaires au fonctionnement du projet.

Configuration vérifiée :

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

**a. Déclaration du provider**

La propriété `source` identifie le fournisseur Terraform :

```hcl
source = "dmacvicar/libvirt"
```

La propriété `version` impose la version 0.9.9 du provider libvirt.

**b. Contrainte de version Terraform**

```hcl
required_version = ">= 1.16.0"
```

Cette directive exige une version de Terraform supérieure ou égale à 1.16.0.

Elle permet de vérifier que l'environnement dispose d'une version compatible avec les exigences déclarées du projet.

**État de la vérification :** les contraintes de versions sont identifiées. Leur compatibilité avec l'installation locale sera contrôlée lors des vérifications Terraform.

### 4.13. Vérification de la version Terraform installée

Avant l'initialisation du projet, nous avons vérifié la version de Terraform installée sur l'hôte `Kgoumou`.

Commande exécutée :

```bash
terraform version
```

Résultat obtenu :

```text
Terraform v1.17.1
on linux_amd64
```

**Analyse :**

Le projet exige Terraform en version `1.16.0` ou supérieure :

```hcl
required_version = ">= 1.16.0"
```

La version installée est `1.17.1`. Elle satisfait donc la contrainte minimale déclarée.

**Conclusion :** l'environnement Terraform installé est compatible avec les exigences de version du projet.

### 4.14. Vérification du fichier `.gitignore`

Avant l'initialisation de Terraform, nous avons contrôlé le fichier `.gitignore` à la racine du projet.

Commande exécutée :

```bash
cat .gitignore
```

Contenu obtenu :

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.*
crash.log
crash.*.log
*.tfvars
!*.tfvars.example

# Cloud-Init / secrets
*.pem
*.key
*.pub
*.secret

# VM images
*.qcow2
*.raw
*.img

# Generated files
*.iso
*.log
```

**Analyse des règles :**

- `.terraform/` : exclut les fichiers internes générés par Terraform.
- `*.tfstate` et `*.tfstate.*` : excluent les fichiers d'état et leurs sauvegardes.
- `*.tfvars` : exclut les configurations locales d'environnement.
- `!*.tfvars.example` : autorise la publication de fichiers d'exemple.
- `*.pem`, `*.key`, `*.pub`, `*.secret` : excluent les fichiers de clés et secrets.
- `*.qcow2`, `*.raw`, `*.img` : excluent les images de machines virtuelles.
- `*.iso` : exclut les images ISO générées.
- `*.log` : exclut les journaux.

**Conclusion :** le fichier `.gitignore` protège les fichiers d'état Terraform, les configurations locales et les images disque volumineuses. Aucune modification n'est nécessaire à ce stade.

### 4.15. Vérification de l'exclusion des fichiers locaux dans Git

Nous avons vérifié les fichiers suivis, modifiés et ignorés par Git.

Commande exécutée :

```bash
git status --short --ignored
```

Résultat obtenu :

```text
 D GUIDE_UTILISATION_TERRAFORM_LIBVIRT_CLOUD_INIT.md
 M README.md
 M terraform/domain.tf
 M terraform/variables.tf
 M terraform/volume.tf
!! environments/
!! images/
```

**Analyse :**

- `D` : l'ancien fichier de guide a été supprimé du répertoire.
- `M` : le README et les fichiers Terraform ont été modifiés.
- `!!` : les répertoires `environments/` et `images/` sont ignorés par Git.

Cette vérification confirme que les règles du `.gitignore` sont appliquées.

Les fichiers `terraform.tfvars` et `ubuntu-noble-60g.qcow2` ne seront donc pas ajoutés au dépôt Git.

**Bonne pratique :** un fichier `terraform.tfvars.example` devra être prévu pour présenter les paramètres nécessaires à l'utilisateur, sans exposer de données sensibles.

# 5. Initialisation, validation et planification Terraform

Après la préparation du disque Ubuntu, l'adaptation des fichiers Terraform et la configuration des paramètres de l'environnement, nous pouvons préparer Terraform à gérer notre nouvelle machine virtuelle.

Cette étape comprend trois opérations principales :

1. Initialiser le projet Terraform.
2. Vérifier la validité de la configuration.
3. Simuler les opérations à effectuer sur l'infrastructure avec `terraform plan`.

## 5.1. Première tentative d'initialisation depuis la racine du projet

Nous avons commencé par exécuter la commande suivante depuis la racine du projet :

```bash
terraform init
```

Résultat obtenu :

```text
Terraform initialized in an empty directory!

The directory has no Terraform configuration files. You may begin working
with Terraform immediately by creating Terraform configuration files.
```

### Analyse

Terraform n'a trouvé aucun fichier de configuration `.tf` dans le répertoire courant.

En effet, les fichiers Terraform sont organisés dans le sous-répertoire :

```text
terraform/
├── cloudinit.tf
├── domain.tf
├── locals.tf
├── provider.tf
├── variables.tf
├── versions.tf
└── volume.tf
```

Terraform doit donc être exécuté depuis ce répertoire pour travailler sur notre configuration.

## 5.2. Initialisation depuis le répertoire Terraform

Nous avons changé de répertoire :

```bash
cd terraform/
```

Vérification des fichiers présents :

```bash
ls
```

Résultat obtenu :

```text
cloudinit.tf  domain.tf  locals.tf  provider.tf  variables.tf  versions.tf  volume.tf
```

Nous avons ensuite lancé l'initialisation :

```bash
terraform init
```

Résultat obtenu :

```text
Initializing the backend...

Initializing provider plugins...
- Reusing version 0.9.9 of dmacvicar/libvirt from the dependency lock file
- Installing dmacvicar/libvirt v0.9.9...
- Installed dmacvicar/libvirt v0.9.9 (self-signed, key ID 0833E38C51E74D26)
Partner and community providers are signed by their developers.
If you'd like to know more about provider signing, you can read about it here:
https://developer.hashicorp.com/terraform/cli/plugins/signing

Terraform has been successfully initialized!
```

### Analyse de l'initialisation

La commande `terraform init` réalise plusieurs opérations :

- Initialise le répertoire de travail Terraform.
- Lit les déclarations des providers dans `versions.tf`.
- Télécharge les providers nécessaires.
- Installe le provider libvirt.
- Prépare les dépendances nécessaires à l'exécution des commandes Terraform.

Dans notre projet, le provider utilisé est :

```hcl
source  = "dmacvicar/libvirt"
version = "0.9.9"
```

Terraform a réutilisé la version 0.9.9 indiquée dans le fichier de verrouillage des dépendances, puis l'a installée avec succès.

**Résultat :** l'initialisation Terraform est réussie.

## 5.3. Validation de la configuration Terraform

Après l'initialisation, nous avons vérifié la cohérence de la configuration avec la commande :

```bash
terraform validate
```

Résultat obtenu :

```text
Success! The configuration is valid.
```

### Analyse

La commande `terraform validate` permet de vérifier la configuration Terraform.

Elle contrôle notamment :

- La syntaxe des fichiers `.tf`.
- La structure des blocs Terraform.
- La cohérence des références entre les ressources.
- La compatibilité de la configuration avec les schémas des providers installés.

Dans notre cas, la validation confirme que les fichiers Terraform sont correctement structurés.

**Important :** `terraform validate` ne vérifie pas que la machine virtuelle sera effectivement créée. Il ne remplace donc pas le plan Terraform ni les contrôles de l'environnement libvirt.

**Résultat :** la configuration Terraform est valide.

## 5.4. Première tentative de planification Terraform

Nous avons ensuite lancé :

```bash
terraform plan
```

Terraform a commencé à demander les valeurs des variables obligatoires :

```text
var.cloudinit_pool
  Pool de stockage des ISO Cloud-Init

  Enter a value:
```

L'exécution a été interrompue avec `Ctrl + C`.

Terraform a alors affiché plusieurs erreurs indiquant que les variables obligatoires n'étaient pas renseignées.

Exemple :

```text
Error: No value for required variable

The root module input variable "project_name" is not set,
and has no default value.
```

Le même problème concernait les variables suivantes :

- `project_name`
- `libvirt_uri`
- `storage_pool`
- `cloudinit_pool`
- `network_name`
- `ssh_username`
- `ssh_public_key`
- `vms`

### Pourquoi cette erreur ?

Notre fichier de variables d'environnement est situé dans :

```text
../environments/kgoumou/terraform.tfvars
```

Terraform ne charge pas automatiquement ce fichier, car il ne se trouve pas dans le répertoire courant du module.

Il faut donc lui indiquer explicitement le chemin du fichier avec l'option `-var-file`.

## 5.5. Exécution du plan avec le fichier de variables

Nous avons relancé la planification en précisant le fichier de variables :

```bash
terraform plan -var-file="../environments/kgoumou/terraform.tfvars"
```

Cette fois, Terraform a correctement récupéré les paramètres de notre environnement.

### 5.5.1. Interprétation des ressources Cloud-Init

Terraform prévoit la création de la ressource :

```text
libvirt_cloudinit_disk.vm_init["ubuntu60"]
```

Elle contient les métadonnées suivantes :

```yaml
instance-id: ubuntu60
local-hostname: srv-ubuntu-60g
```

Les données utilisateur contiennent notamment :

- La création de l'utilisateur `kaman`.
- Son ajout au groupe `sudo`.
- La configuration de Bash.
- L'ajout de la clé publique SSH.
- La désactivation de l'authentification SSH par mot de passe.
- La désactivation de l'accès direct à root.

Ces données proviennent des templates Cloud-Init préparés précédemment.

### 5.5.2. Interprétation de la ressource de stockage

Terraform prévoit la création du disque système :

```text
libvirt_volume.vm_disk_60g["ubuntu60"]
```

Les principales caractéristiques sont :

```text
capacity = 64424509440
pool     = "default"
```

La capacité correspond à 60 Gio :

\[
60 \times 1024^3 = 64\,424\,509\,440 \text{ octets}
\]

Le fichier source utilisé est :

```text
/home/kaman-goumou/lab/terraform-libvirt-cloud-init-vm-60g/images/ubuntu-noble-60g.qcow2
```

Le nom définitif du volume est :

```text
srv-ubuntu-60g.qcow2
```

### 5.5.3. Interprétation du volume Cloud-Init

La ressource suivante est également prévue :

```text
libvirt_volume.vm_init_iso["ubuntu60"]
```

Elle utilise :

```text
name = "ubuntu60-init.iso"
pool = "iso"
```

Son rôle est de fournir à la machine virtuelle les données Cloud-Init générées par Terraform.

### 5.5.4. Interprétation de la machine virtuelle

Terraform prévoit la création de :

```text
libvirt_domain.vm["ubuntu60"]
```

Les paramètres matériels affichés dans le plan sont :

```text
name        = "srv-ubuntu-60g"
memory      = 6144
memory_unit = "MiB"
vcpu        = 4
running     = true
type        = "kvm"
```

La configuration matérielle prévue est donc :

| Paramètre | Valeur |
|---|---|
| Nom | `srv-ubuntu-60g` |
| Hyperviseur | KVM |
| Architecture | x86_64 |
| Machine | Q35 |
| Processeurs virtuels | 4 |
| Mémoire RAM | 6144 Mio (6 Gio) |
| Disque système | 60 Gio |
| Bus du disque | VirtIO |
| Réseau libvirt | `default` |
| Interface réseau | VirtIO |
| Console | Série PTY |
| Cloud-Init | Lecteur CD-ROM virtuel |

## 5.6. Bilan du plan Terraform

À la fin de la planification, Terraform a affiché :

```text
Plan: 4 to add, 0 to change, 0 to destroy.
```

### Interprétation

- `4 to add` : quatre nouvelles ressources seront créées.
- `0 to change` : aucune ressource existante ne sera modifiée.
- `0 to destroy` : aucune ressource existante ne sera supprimée.

Les quatre ressources prévues sont :

| Ressource Terraform | Rôle |
|---|---|
| `libvirt_cloudinit_disk.vm_init` | Génération des données Cloud-Init |
| `libvirt_volume.vm_init_iso` | Création du volume Cloud-Init |
| `libvirt_volume.vm_disk_60g` | Création du disque système de 60 Gio |
| `libvirt_domain.vm` | Création de la VM KVM |

### 5.7. Conclusion de la section

L'initialisation et la validation du projet Terraform se sont déroulées correctement.

La première tentative de planification a mis en évidence la nécessité de fournir explicitement le fichier de variables d'environnement. Après correction, Terraform a pu générer un plan cohérent avec les caractéristiques demandées.

Le plan final prévoit quatre créations, sans modification ni suppression des machines virtuelles préexistantes.

**À ce stade, aucune ressource n'a encore été créée par le plan.** La création effective de la machine virtuelle intervient dans la section suivante, consacrée à l'exécution de `terraform apply`.

# 6. Déploiement et vérification de la machine virtuelle

Après l'initialisation, la validation et la planification Terraform, nous pouvons procéder à la création effective de notre machine virtuelle Ubuntu.

Cette étape consiste à appliquer le plan Terraform, puis à vérifier que les ressources ont bien été créées dans l'environnement KVM/libvirt.

## 6.1. Exécution de Terraform Apply

Depuis le répertoire `terraform/`, nous avons lancé la commande suivante :

```bash
terraform apply -var-file="../environments/kgoumou/terraform.tfvars"
```

Terraform a affiché le plan prévisionnel :

```text
Plan: 4 to add, 0 to change, 0 to destroy.
```

Il a ensuite demandé une confirmation avant de procéder à la création des ressources :

```text
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

Nous avons confirmé l'opération en saisissant :

```text
yes
```

Cette validation autorise Terraform à appliquer le plan et à créer les ressources dans libvirt.

## 6.2. Création des ressources

Terraform a exécuté les opérations suivantes :

```text
libvirt_cloudinit_disk.vm_init["ubuntu60"]: Creating...
libvirt_volume.vm_disk_60g["ubuntu60"]: Creating...

libvirt_cloudinit_disk.vm_init["ubuntu60"]: Creation complete after 0s [id=de9a3abf4dd52ff3]

libvirt_volume.vm_init_iso["ubuntu60"]: Creating...
libvirt_volume.vm_init_iso["ubuntu60"]: Creation complete after 0s [id=/home/kaman-goumou/lab/kvm/iso/ubuntu60-init.iso]

libvirt_volume.vm_disk_60g["ubuntu60"]: Creation complete after 3s [id=/var/lib/libvirt/images/srv-ubuntu-60g.qcow2]

libvirt_domain.vm["ubuntu60"]: Creating...
libvirt_domain.vm["ubuntu60"]: Creation complete after 1s [name=srv-ubuntu-60g]
```

### Analyse des opérations

**1. Génération des données Cloud-Init**

Terraform a créé la ressource :

```text
libvirt_cloudinit_disk.vm_init["ubuntu60"]
```

Identifiant retourné :

```text
de9a3abf4dd52ff3
```

Cette ressource contient les métadonnées et les paramètres utilisateur préparés à partir des templates Cloud-Init.

**2. Création du volume Cloud-Init**

Le volume a été créé dans le pool `iso`.

Chemin retourné :

```text
/home/kaman-goumou/lab/kvm/iso/ubuntu60-init.iso
```

**3. Création du disque système**

Le disque système QCOW2 a été créé dans le pool `default`.

Chemin retourné :

```text
/var/lib/libvirt/images/srv-ubuntu-60g.qcow2
```

**4. Création de la machine virtuelle**

Terraform a ensuite créé le domaine libvirt :

```text
srv-ubuntu-60g
```

La création s'est terminée avec succès.

## 6.3. Résultat final du déploiement

Terraform a affiché le résultat suivant :

```text
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

### Interprétation

| Indicateur | Résultat |
|---|---:|
| Ressources ajoutées | 4 |
| Ressources modifiées | 0 |
| Ressources détruites | 0 |

Les quatre ressources prévues dans le plan ont donc été créées.

Aucune ressource existante n'a été modifiée ou supprimée.

## 6.4. Vérification de la machine virtuelle dans libvirt

Après le déploiement, nous avons vérifié la présence et l'état des machines virtuelles avec la commande :

```bash
virsh list --all
```

Résultat obtenu :

```text
 Id   Name               State
-----------------------------------
 1    srv-ubuntu-60g     running
 -    oracle-db-server   shut off
 -    pve1               shut off
```

### Analyse

La sortie confirme que :

- `srv-ubuntu-60g` est présente dans libvirt et fonctionne à l'état `running`.
- `oracle-db-server` est toujours arrêtée.
- `pve1` est toujours arrêtée.

La nouvelle VM a donc été créée et démarrée sans perturber les deux machines virtuelles préexistantes affichées dans le résultat.

## 6.5. Récupération de l'adresse IP de la VM

Nous avons ensuite recherché l'adresse IP attribuée à la machine virtuelle :

```bash
virsh domifaddr srv-ubuntu-60g
```

Résultat obtenu :

```text
 Name       MAC address          Protocol     Address
-------------------------------------------------------------------------------
 vnet0      52:54:00:89:35:e8    ipv4         192.168.122.253/24
```

### Analyse des informations réseau

| Paramètre | Valeur |
|---|---|
| Nom de la VM | `srv-ubuntu-60g` |
| Interface libvirt | `vnet0` |
| Adresse MAC | `52:54:00:89:35:e8` |
| Protocole | IPv4 |
| Adresse IP | `192.168.122.253` |
| Préfixe réseau | `/24` |

L'adresse IP attribuée à la VM est donc :

```text
192.168.122.253/24
```

Cette adresse appartient au réseau virtuel libvirt `default`.

Elle pourra être utilisée pour les prochains tests de connectivité et d'accès SSH depuis l'hôte.

## 6.6. Bilan du déploiement

À la fin de cette étape, les opérations suivantes ont été réalisées avec succès :

| Opération | Résultat |
|---|---|
| Application du plan Terraform | Réussie |
| Génération des données Cloud-Init | Réussie |
| Création du volume Cloud-Init | Réussie |
| Création du disque QCOW2 de 60 Gio | Réussie |
| Création du domaine KVM | Réussie |
| Démarrage de la VM | Confirmé |
| Récupération de l'adresse IPv4 | Confirmée |

### Caractéristiques de la machine virtuelle déployée

| Ressource | Configuration |
|---|---|
| Nom | `srv-ubuntu-60g` |
| Système prévu | Ubuntu Server 24.04 Cloud |
| Hyperviseur | KVM/libvirt |
| Architecture | x86_64 |
| Nombre de vCPU | 4 |
| Mémoire RAM | 6 Gio |
| Disque système | 60 Gio |
| Format du disque | QCOW2 |
| Réseau | libvirt `default` |
| Adresse IPv4 | `192.168.122.253` |

## 6.7. Conclusion

Le déploiement de la machine virtuelle Ubuntu avec Terraform, KVM/libvirt et Cloud-Init s'est terminé avec succès.

Terraform a créé les quatre ressources prévues, sans modifier ni supprimer les machines virtuelles préexistantes.

Les premières vérifications dans libvirt confirment que `srv-ubuntu-60g` est démarrée et dispose de l'adresse IPv4 `192.168.122.253`.

La vérification de l'accès SSH, du fonctionnement effectif de Cloud-Init et des caractéristiques matérielles depuis l'intérieur du système Ubuntu reste à effectuer dans la prochaine étape du laboratoire.

# 07 — Vérifications finales et validation de la VM

## 7.1. Objectif

Après le déploiement de la machine virtuelle `srv-ubuntu-60g` avec Terraform et KVM/libvirt, cette étape consiste à vérifier :

- L'accès distant par SSH ;
- L'identité et le système d'exploitation de la VM ;
- L'exécution de Cloud-Init ;
- Le nombre de processeurs virtuels ;
- La connectivité réseau vers Internet.

## 7.2. Vérification de l'accès SSH

Depuis l'hôte `Kgoumou`, connexion à la VM :

```bash
ssh kaman@192.168.122.253
```

Lors de la première connexion, SSH a demandé de confirmer l'authenticité de l'hôte. Après validation avec `yes`, la connexion a abouti.

Message obtenu :

```text
Welcome to Ubuntu 24.04.5 LTS (GNU/Linux 6.8.0-142-generic x86_64)
```

L'invite de commande confirme l'ouverture d'une session sur la VM :

```text
kaman@srv-ubuntu-60g:~$
```

**Résultat :** l'accès SSH avec l'utilisateur `kaman` fonctionne. L'authentification par clé SSH configurée dans Cloud-Init est opérationnelle.

## 7.3. Vérification de l'identité de la VM

Commande exécutée :

```bash
hostnamectl
```

Résultat :

```text
Static hostname: srv-ubuntu-60g
Icon name: computer-vm
Chassis: vm
Virtualization: kvm
Operating System: Ubuntu 24.04.5 LTS
Kernel: Linux 6.8.0-142-generic
Architecture: x86-64
Hardware Vendor: QEMU
Hardware Model: Ubuntu 24.04 PC _Q35 + ICH9, 2009_
```

**Analyse :**

- Le nom d'hôte `srv-ubuntu-60g` correspond à celui défini dans le fichier `terraform.tfvars`.
- Le système installé est Ubuntu Server 24.04.5 LTS.
- La virtualisation KVM est correctement détectée.
- L'architecture de la machine est x86-64.
- Le matériel virtuel est présenté par QEMU.

Cette vérification confirme que la VM utilise bien l'identité et l'environnement attendus.

## 7.4. Vérification de l'exécution de Cloud-Init

Commande exécutée :

```bash
cloud-init status --long
```

Résultat :

```text
status: done
extended_status: done
boot_status_code: enabled-by-generator
last_update: Thu, 01 Jan 1970 00:00:14 +0000
detail: DataSourceNoCloud [seed=/dev/sr0]
errors: []
recoverable_errors: {}
```

**Analyse :**

| Élément | Résultat | Interprétation |
|---|---|---|
| `status` | `done` | Initialisation terminée |
| `extended_status` | `done` | Traitement terminé |
| `DataSourceNoCloud` | `/dev/sr0` | Source Cloud-Init détectée sur le CD-ROM |
| `errors` | `[]` | Aucune erreur |
| `recoverable_errors` | `{}` | Aucune erreur récupérable |

**Résultat :** Cloud-Init a terminé son exécution sans erreur. La source NoCloud a été détectée depuis le périphérique `/dev/sr0`, correspondant au média ISO Cloud-Init attaché à la VM.

## 7.5. Vérification du nombre de processeurs virtuels

Commande exécutée :

```bash
lscpu | grep -E '^CPU\(s\):|^Model name:'
```

Résultat :

```text
CPU(s):                                  4
Model name:                              QEMU Virtual CPU version 2.5+
```

**Analyse :**

La VM dispose de 4 processeurs virtuels, conformément à la configuration Terraform :

```hcl
vcpu = 4
```

Le modèle de processeur est celui présenté par l'environnement de virtualisation QEMU.

**Résultat :** les 4 vCPU configurés sont visibles depuis le système invité.

## 7.6. Vérification de la connectivité réseau

Deux tests ICMP ont été effectués vers `google.com`.

Première tentative :

```bash
ping google.com -c 2
```

Résultat :

```text
2 packets transmitted, 0 received, 100% packet loss
```

La première tentative n'a reçu aucune réponse.

Deuxième tentative :

```bash
ping google.com -c 2
```

Résultat :

```text
64 bytes from lclhrb-in-f100.1e100.net (142.250.129.100): icmp_seq=1 ttl=106 time=71.9 ms
64 bytes from lclhrb-in-f100.1e100.net (142.250.129.100): icmp_seq=2 ttl=106 time=177 ms

2 packets transmitted, 2 received, 0% packet loss
rtt min/avg/max/mdev = 71.907/124.393/176.880/52.486 ms
```

**Analyse :**

- Le nom `google.com` a été résolu en adresse IPv4.
- Les deux paquets ICMP de la seconde tentative ont reçu une réponse.
- Aucune perte de paquets n'a été constatée lors de cette seconde tentative.

**Résultat :** la résolution DNS et la connectivité vers Internet ont fonctionné lors du second test. Le premier échec ponctuel est également conservé dans le compte rendu.

## 7.7. Bilan des vérifications

| Vérification | Résultat |
|---|---|
| Démarrage de la VM | Réussi |
| Adresse IP | `192.168.122.253` |
| Connexion SSH | Réussie |
| Authentification SSH par clé | Fonctionnelle |
| Hostname | Conforme |
| Ubuntu Server 24.04.5 LTS | Confirmé |
| Virtualisation KVM | Confirmée |
| Cloud-Init | Terminé sans erreur |
| Nombre de vCPU | 4 confirmés |
| Résolution DNS | Fonctionnelle lors du second test |
| Connectivité Internet | Fonctionnelle lors du second test |

## 7.8. Conclusion générale du projet

Le déploiement de la machine virtuelle `srv-ubuntu-60g` avec Terraform, le provider libvirt et Cloud-Init a été réalisé avec succès.

Les quatre ressources Terraform ont été créées :

- Le disque système de 60 GiB ;
- Le média Cloud-Init ;
- Le volume ISO Cloud-Init dans le pool `iso` ;
- La machine virtuelle KVM.

Le résultat de l'application Terraform était :

```text
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

Les vérifications effectuées après le déploiement confirment que la VM est démarrée, accessible en SSH, correctement identifiée et initialisée par Cloud-Init. Les quatre processeurs virtuels sont également visibles depuis Ubuntu.

**Le projet de déploiement Terraform/libvirt/Cloud-Init est donc opérationnel.**

*Note sur le périmètre des contrôles : la RAM et la capacité du disque vues depuis le système invité n'ont pas été vérifiées dans cette session. La capacité virtuelle de 60 GiB du disque avait toutefois été vérifiée auparavant avec `qemu-img info` sur l'image préparée.*

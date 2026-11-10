# GUIDE DE REDÉPLOIEMENT
# Terraform + KVM/libvirt + Cloud-Init

**Projet :** `terraform-libvirt-cloud-init-vm-60g`  
**Machine virtuelle :** `srv-ubuntu-60g`  
**Système invité :** Ubuntu Server 24.04 LTS  
**Hyperviseur :** KVM/libvirt  
**Infrastructure as Code :** Terraform  
**Initialisation :** Cloud-Init NoCloud

---

# Table des matières

1. Présentation du projet et architecture
2. Prérequis techniques
3. Récupération du projet depuis GitHub
4. Préparation de l'image Ubuntu Cloud
5. Configuration des variables Terraform
6. Initialisation de Terraform
7. Validation de la configuration
8. Planification du déploiement
9. Déploiement de la machine virtuelle
10. Vérification sur l'hyperviseur KVM
11. Connexion SSH à la VM
12. Vérifications dans le système invité
13. Gestion du cycle de vie de la VM
14. Dépannage
15. Récapitulatif du redéploiement

---

# 01 — Présentation du projet et architecture

## 1.1. Objectif

L'objectif est de déployer une machine virtuelle Ubuntu Server 24.04 à l'aide de Terraform et de l'hyperviseur KVM/libvirt.

La configuration est déclarative : les caractéristiques de la machine sont définies dans les fichiers Terraform. Terraform utilise ensuite le provider libvirt pour créer et gérer les ressources sur l'hyperviseur.

Cloud-Init assure la configuration initiale du système invité, notamment :

- La définition du hostname ;
- La création de l'utilisateur `kaman` ;
- La configuration de la clé publique SSH ;
- L'attribution des privilèges sudo ;
- La désactivation de l'authentification SSH par mot de passe.

## 1.2. Architecture cible

```text
                 HÔTE UBUNTU
                  Kgoumou
                     |
                     |
             Terraform 1.17.1
                     |
              Provider libvirt
                v0.9.9
                     |
                     |
                KVM / QEMU
                     |
               libvirt network
                  default
                     |
              192.168.122.0/24
                     |
                     |
             srv-ubuntu-60g
             Ubuntu Server 24.04
                     |
              4 vCPU / 6 GiB
                   RAM
                     |
                60 GiB
                QCOW2
                     |
               Cloud-Init
               NoCloud ISO
                     |
               Utilisateur
                  kaman
                     |
                SSH / Clé
```

## 1.3. Caractéristiques de la machine virtuelle

| Paramètre | Configuration |
|---|---|
| Nom de la VM | `srv-ubuntu-60g` |
| OS | Ubuntu Server 24.04 LTS |
| Architecture | x86-64 |
| Hyperviseur | KVM/QEMU |
| vCPU | 4 |
| RAM | 6144 MiB (6 GiB) |
| Disque | 60 GiB |
| Format du disque | QCOW2 |
| Réseau libvirt | `default` |
| Pool de stockage | `default` |
| Pool Cloud-Init | `iso` |
| Utilisateur | `kaman` |
| Authentification | Clé SSH |

---

# 02 — Prérequis techniques

Avant de commencer le redéploiement, vérifier que l'hôte dispose des outils nécessaires.

## 2.1. Vérification du système

```bash
hostnamectl
```

Le projet a été réalisé sur un hôte Ubuntu 24.04 LTS.

## 2.2. Vérification de KVM et libvirt

```bash
virsh version
```

Vérifier les réseaux libvirt :

```bash
virsh net-list --all
```

Le réseau `default` doit être disponible et actif.

S'il existe mais est arrêté :

```bash
sudo virsh net-start default
```

Pour activer son démarrage automatique :

```bash
sudo virsh net-autostart default
```

Vérifier les pools de stockage :

```bash
virsh pool-list --all
```

Les pools suivants sont utilisés :

- `default` : stockage du disque de la VM ;
- `iso` : stockage du média Cloud-Init.

S'ils existent mais sont arrêtés :

```bash
sudo virsh pool-start default
sudo virsh pool-start iso
```

Activer leur démarrage automatique :

```bash
sudo virsh pool-autostart default
sudo virsh pool-autostart iso
```

Ne pas recréer un réseau ou un pool déjà existant.

## 2.3. Vérification des logiciels

```bash
terraform version
```

Version utilisée dans le projet :

```text
Terraform v1.17.1
on linux_amd64
```

Vérifier également les outils :

```bash
qemu-img --version
virsh --version
git --version
ssh -V
```

---

# 03 — Récupération du projet depuis GitHub

## 3.1. Accès au répertoire de travail

```bash
mkdir -p ~/lab
cd ~/lab
```

## 3.2. Clonage du dépôt

Le projet est hébergé dans un dépôt GitHub privé.

```bash
git clone git@github.com:kaman2803/terraform-libvirt-cloud-init-multi-vm-v1.git terraform-libvirt-cloud-init-vm-60g
```

Accéder au projet :

```bash
cd ~/lab/terraform-libvirt-cloud-init-vm-60g
```

Vérifier le dépôt :

```bash
git remote -v
git branch
git status
```

Le dépôt distant doit correspondre au dépôt GitHub du projet.

## 3.3. Structure du projet

La structure attendue est :

```text
terraform-libvirt-cloud-init-vm-60g/
│
├── README.md
│
├── .gitignore
│
├── environments/
│   └── kgoumou/
│       └── terraform.tfvars
│
├── images/
│   └── ubuntu-noble-60g.qcow2
│
├── templates/
│   ├── meta-data.yaml.tftpl
│   └── user-data.yaml.tftpl
│
└── terraform/
    ├── cloudinit.tf
    ├── domain.tf
    ├── locals.tf
    ├── provider.tf
    ├── variables.tf
    ├── versions.tf
    └── volume.tf
```

**Important :** le fichier `.gitignore` exclut les fichiers `.tfvars` et les images QCOW2. Ils doivent donc être préparés localement après le clonage.

---

# 04 — Préparation de l'image Ubuntu Cloud

## 4.1. Image Ubuntu de référence

Le projet utilise une image Ubuntu Cloud officielle déjà présente sur l'hôte :

```text
/home/kaman-goumou/lab/kvm/iso/base/noble-server-cloudimg-amd64.img
```

Vérifier sa présence :

```bash
ls -lh /home/kaman-goumou/lab/kvm/iso/base/noble-server-cloudimg-amd64.img
```

## 4.2. Création du répertoire images

Depuis la racine du projet :

```bash
mkdir -p images
```

## 4.3. Conversion en image QCOW2 autonome

```bash
qemu-img convert -p -f qcow2 -O qcow2 \
  /home/kaman-goumou/lab/kvm/iso/base/noble-server-cloudimg-amd64.img \
  images/ubuntu-noble-60g.qcow2
```

Cette opération crée une nouvelle image indépendante de l'image source.

## 4.4. Redimensionnement à 60 GiB

```bash
qemu-img resize images/ubuntu-noble-60g.qcow2 60G
```

Résultat attendu :

```text
Image resized.
```

## 4.5. Vérification de la capacité

```bash
qemu-img info images/ubuntu-noble-60g.qcow2
```

La capacité virtuelle attendue est :

```text
virtual size: 60 GiB (64424509440 bytes)
```

## 4.6. Vérification de l'intégrité

```bash
qemu-img check images/ubuntu-noble-60g.qcow2
```

Résultat attendu :

```text
No errors were found on the image.
```

L'image est maintenant prête à être utilisée par Terraform.

---

# 05 — Configuration des variables Terraform

## 5.1. Création de l'environnement

```bash
mkdir -p environments/kgoumou
```

Créer le fichier :

```bash
nano environments/kgoumou/terraform.tfvars
```

## 5.2. Contenu du fichier terraform.tfvars

```hcl
project_name   = "terraform-libvirt-cloud-init-vm-60g"
libvirt_uri    = "qemu:///system"
storage_pool   = "default"
cloudinit_pool = "iso"
network_name   = "default"

ssh_username = "kaman"

ssh_public_key = "ssh-ed25519 VOTRE_CLE_PUBLIQUE"

vms = {
  ubuntu60 = {
    hostname = "srv-ubuntu-60g"
    vcpu     = 4
    memory   = 6144
    disk_gb  = 60
  }
}
```

Remplacer `VOTRE_CLE_PUBLIQUE` par la véritable clé publique SSH de la machine d'administration.

## 5.3. Vérification de la clé SSH

Sur la machine d'administration :

```bash
ls -l ~/.ssh/id_ed25519.pub
```

Afficher la clé :

```bash
cat ~/.ssh/id_ed25519.pub
```

Copier son contenu complet dans la variable `ssh_public_key`.

Ne jamais placer la clé privée dans le fichier Terraform.

## 5.4. Protection des informations sensibles

Le fichier `terraform.tfvars` contient des informations propres à l'environnement.

Il ne doit pas être publié sur GitHub.

Vérifier que `.gitignore` contient :

```gitignore
*.tfvars
!*.tfvars.example
*.pem
*.key
*.pub
*.secret
*.qcow2
*.raw
*.img
*.iso
```

Vérifier son statut :

```bash
git status --short --ignored
```

Les répertoires `environments/` et `images/` doivent être ignorés par Git si leurs fichiers ne sont pas destinés à être publiés.

---

# 06 — Initialisation de Terraform

## 6.1. Accès au répertoire Terraform

```bash
cd ~/lab/terraform-libvirt-cloud-init-vm-60g/terraform
```

Les fichiers `.tf` se trouvent dans ce répertoire.

## 6.2. Initialisation

```bash
terraform init
```

Cette commande :

- Initialise le répertoire de travail Terraform ;
- Télécharge les providers nécessaires ;
- Prépare le répertoire `.terraform/` ;
- Crée ou actualise le fichier de verrouillage des providers.

Le projet utilise le provider :

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

Résultat attendu :

```text
Terraform has been successfully initialized!
```

**Attention :** exécuter `terraform init` dans le répertoire `terraform/`, et non à la racine du projet.

---

# 07 — Validation de la configuration

## 7.1. Validation syntaxique

```bash
terraform validate
```

Résultat attendu :

```text
Success! The configuration is valid.
```

Cette commande vérifie la cohérence de la configuration Terraform.

## 7.2. Vérification des fichiers de configuration

Les fichiers principaux sont :

| Fichier | Fonction |
|---|---|
| `provider.tf` | Connexion à libvirt |
| `versions.tf` | Version de Terraform et du provider |
| `variables.tf` | Déclaration des variables |
| `locals.tf` | Calcul des valeurs locales et génération des données Cloud-Init |
| `volume.tf` | Création du disque système |
| `cloudinit.tf` | Génération du média Cloud-Init |
| `domain.tf` | Définition de la machine virtuelle |

## 7.3. Vérification de l'image

Depuis le répertoire `terraform/` :

```bash
ls -lh ../images/ubuntu-noble-60g.qcow2
```

Le fichier doit être présent avant la planification et le déploiement.

---

# 08 — Planification du déploiement

## 8.1. Exécution du plan

```bash
terraform plan -var-file="../environments/kgoumou/terraform.tfvars"
```

Cette commande permet de visualiser les ressources que Terraform prévoit de créer.

## 8.2. Ressources attendues

Le projet prévoit quatre ressources :

| Ressource | Fonction |
|---|---|
| `libvirt_cloudinit_disk.vm_init` | Génération des données Cloud-Init |
| `libvirt_volume.vm_init_iso` | Création du volume ISO |
| `libvirt_volume.vm_disk_60g` | Création du disque système QCOW2 |
| `libvirt_domain.vm` | Création de la machine virtuelle |

Pour un premier déploiement sur un état Terraform vierge, le résultat attendu est :

```text
Plan: 4 to add, 0 to change, 0 to destroy.
```

**Important :** lire attentivement le plan avant toute application. Si Terraform annonce la destruction ou la modification d'une ressource existante non prévue, ne pas poursuivre avant d'avoir compris la raison.

---

# 09 — Déploiement de la machine virtuelle

## 9.1. Application de la configuration

```bash
terraform apply -var-file="../environments/kgoumou/terraform.tfvars"
```

Terraform affiche le plan et demande une confirmation.

Saisir :

```text
yes
```

Terraform procède alors à la création des ressources.

## 9.2. Résultat attendu

À la fin d'un déploiement réussi :

```text
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

La machine virtuelle est désormais créée et démarrée par libvirt.

## 9.3. Rôle des ressources créées

1. `libvirt_cloudinit_disk.vm_init` génère les données de configuration initiale.
2. `libvirt_volume.vm_init_iso` stocke le média ISO Cloud-Init dans le pool `iso`.
3. `libvirt_volume.vm_disk_60g` crée le disque système dans le pool `default`.
4. `libvirt_domain.vm` définit et démarre la machine virtuelle KVM.

---

# 10 — Vérification sur l'hyperviseur KVM

## 10.1. Liste des machines virtuelles

```bash
virsh list --all
```

La VM doit apparaître avec l'état :

```text
srv-ubuntu-60g     running
```

## 10.2. Vérification de l'adresse IP

```bash
virsh domifaddr srv-ubuntu-60g
```

Lors du déploiement initial, l'adresse obtenue était :

```text
192.168.122.253/24
```

L'adresse peut être différente lors d'un nouveau déploiement, selon l'attribution DHCP.

## 10.3. Vérification du disque virtuel

```bash
virsh domblklist srv-ubuntu-60g
```

Cette commande permet de vérifier le disque système attaché à la VM.

Vérifier également le volume dans le pool :

```bash
virsh vol-list default
```

Le disque attendu est :

```text
srv-ubuntu-60g.qcow2
```

## 10.4. Vérification de la mémoire et des CPU configurés

```bash
virsh dominfo srv-ubuntu-60g
```

Les valeurs attendues sont :

- Mémoire maximale : 6291456 KiB ;
- Nombre de CPU : 4 ;
- État : running.

---

# 11 — Connexion SSH à la machine virtuelle

## 11.1. Connexion

Depuis la machine d'administration :

```bash
ssh kaman@ADRESSE_IP_VM
```

Exemple avec l'adresse du premier déploiement :

```bash
ssh kaman@192.168.122.253
```

Lors de la première connexion, SSH peut demander de confirmer l'empreinte de la machine.

Après vérification, saisir :

```text
yes
```

## 11.2. Résultat attendu

```text
Welcome to Ubuntu 24.04.5 LTS
```

L'invite de commande doit ressembler à :

```text
kaman@srv-ubuntu-60g:~$
```

Cette connexion confirme que l'utilisateur est créé et que l'accès SSH par clé fonctionne.

---

# 12 — Vérifications dans le système invité

Une fois connecté à la VM, effectuer les contrôles suivants.

## 12.1. Vérification du hostname et du système

```bash
hostnamectl
```

Valeurs attendues :

- Static hostname : `srv-ubuntu-60g` ;
- Operating System : Ubuntu 24.04.5 LTS ;
- Virtualization : KVM ;
- Architecture : x86-64.

## 12.2. Vérification de Cloud-Init

```bash
cloud-init status --long
```

Résultat attendu :

```text
status: done
extended_status: done
errors: []
recoverable_errors: {}
```

La présence de `DataSourceNoCloud` confirme l'utilisation de la source Cloud-Init NoCloud.

## 12.3. Vérification des processeurs

```bash
lscpu | grep -E '^CPU\(s\):|^Model name:'
```

Résultat attendu :

```text
CPU(s): 4
```

## 12.4. Vérification de la mémoire

```bash
free -h
```

La VM doit disposer d'environ 6 GiB de RAM.

## 12.5. Vérification du disque

```bash
lsblk
```

Puis :

```bash
df -h /
```

Le disque virtuel a une capacité cible de 60 GiB. La capacité réellement visible dans le système invité doit être vérifiée après l'initialisation et l'extension éventuelle de la partition.

## 12.6. Vérification de la connectivité

Tester la résolution DNS :

```bash
getent hosts google.com
```

Tester la connectivité IP :

```bash
ping -c 2 8.8.8.8
```

Tester la connectivité par nom :

```bash
ping -c 2 google.com
```

Les réponses dépendent de la connectivité de l'hôte, du réseau libvirt et des règles réseau en vigueur.

---

# 13 — Gestion du cycle de vie de la VM

Terraform permet de gérer le cycle de vie de la machine virtuelle après sa création.

**Toutes les commandes de cette section sont des opérations possibles : elles ne doivent être exécutées que si nécessaire.**

## 13.1. Afficher l'état Terraform

Depuis le répertoire `terraform/` :

```bash
terraform state list
```

Les quatre ressources doivent apparaître après un déploiement réussi.

## 13.2. Consulter les détails d'une ressource

```bash
terraform state show 'libvirt_domain.vm["ubuntu60"]'
```

Cette commande affiche les attributs enregistrés dans l'état Terraform.

## 13.3. Revoir le plan

```bash
terraform plan -var-file="../environments/kgoumou/terraform.tfvars"
```

Si la configuration n'a pas changé et que l'état correspond à l'infrastructure réelle, Terraform doit normalement indiquer :

```text
No changes.
```

## 13.4. Appliquer une modification

Après modification des variables ou de la configuration :

```bash
terraform plan -var-file="../environments/kgoumou/terraform.tfvars"
```

Si le plan est conforme :

```bash
terraform apply -var-file="../environments/kgoumou/terraform.tfvars"
```

## 13.5. Détruire les ressources

Pour supprimer les ressources gérées par ce projet :

```bash
terraform destroy -var-file="../environments/kgoumou/terraform.tfvars"
```

Terraform présente les ressources concernées et demande une confirmation.

Saisir `yes` uniquement après avoir vérifié le plan de destruction.

**Attention :** cette opération supprime la VM et les ressources gérées par Terraform. Ne pas supprimer manuellement le fichier d'état Terraform avant cette opération.

## 13.6. Redéployer après destruction

Après une destruction réussie, vérifier que l'image locale est toujours présente :

```bash
ls -lh ../images/ubuntu-noble-60g.qcow2
```

Puis recommencer :

```bash
terraform plan -var-file="../environments/kgoumou/terraform.tfvars"
```

Et :

```bash
terraform apply -var-file="../environments/kgoumou/terraform.tfvars"
```

Si le fichier d'état Terraform a été perdu, ne pas appliquer directement la configuration sans vérifier l'existence des ressources libvirt. Une ressource existante peut nécessiter une importation ou une procédure de récupération d'état.

---

# 14 — Dépannage

## 14.1. Terraform ne trouve pas les variables

Si Terraform affiche des demandes de variables ou indique qu'elles sont absentes, vérifier que le fichier de variables est bien utilisé :

```bash
terraform plan -var-file="../environments/kgoumou/terraform.tfvars"
```

Toujours lancer cette commande depuis le répertoire `terraform/`.

## 14.2. Terraform indique un répertoire vide

Si le message suivant apparaît :

```text
Terraform initialized in an empty directory!
The directory has no Terraform configuration files.
```

Cela signifie que Terraform a été lancé dans un répertoire ne contenant pas les fichiers `.tf`.

Solution :

```bash
cd ~/lab/terraform-libvirt-cloud-init-vm-60g/terraform
terraform init
```

## 14.3. Le réseau libvirt est arrêté

Vérifier :

```bash
virsh net-list --all
```

Démarrer le réseau si nécessaire :

```bash
sudo virsh net-start default
```

## 14.4. Le pool de stockage est arrêté

Vérifier :

```bash
virsh pool-list --all
```

Démarrer les pools nécessaires :

```bash
sudo virsh pool-start default
sudo virsh pool-start iso
```

## 14.5. La VM n'obtient pas d'adresse IP

Vérifier l'état de la VM :

```bash
virsh list --all
```

Vérifier son interface :

```bash
virsh domiflist srv-ubuntu-60g
```

Puis :

```bash
virsh domifaddr srv-ubuntu-60g
```

Si aucune adresse n'apparaît, cela ne prouve pas à lui seul que la VM est hors ligne : vérifier également le DHCP et l'interface réseau depuis le système invité.

## 14.6. Cloud-Init ne termine pas son initialisation

Dans la VM :

```bash
cloud-init status --long
```

Consulter les journaux :

```bash
sudo journalctl -u cloud-init -u cloud-config -u cloud-final
```

Et :

```bash
sudo less /var/log/cloud-init.log
```

Vérifier que le CD-ROM Cloud-Init est bien attaché à la VM.

---

# 15 — Récapitulatif du redéploiement

## 15.1. Séquence complète des commandes principales

Après avoir préparé les prérequis, cloné le projet, créé le disque QCOW2 et renseigné `terraform.tfvars`, la séquence principale est :

```bash
# Accéder au projet
cd ~/lab/terraform-libvirt-cloud-init-vm-60g

# Accéder à la configuration Terraform
cd terraform

# Initialiser Terraform
terraform init

# Valider la configuration
terraform validate

# Prévisualiser le déploiement
terraform plan -var-file="../environments/kgoumou/terraform.tfvars"

# Déployer la VM
terraform apply -var-file="../environments/kgoumou/terraform.tfvars"

# Vérifier les ressources Terraform
terraform state list

# Vérifier les machines virtuelles
virsh list --all

# Vérifier l'adresse IP
virsh domifaddr srv-ubuntu-60g
```

Après avoir obtenu l'adresse IP :

```bash
ssh kaman@ADRESSE_IP_VM
```

Dans la VM :

```bash
hostnamectl
cloud-init status --long
lscpu
free -h
lsblk
df -h /
```

## 15.2. Résultat final attendu

| Élément | Valeur cible |
|---|---|
| VM | `srv-ubuntu-60g` |
| OS | Ubuntu Server 24.04 LTS |
| Virtualisation | KVM |
| vCPU | 4 |
| RAM | 6 GiB |
| Disque virtuel | 60 GiB |
| Réseau | `default` |
| Cloud-Init | `done` |
| Utilisateur | `kaman` |
| SSH | Accès par clé publique |

## 15.3. Conclusion

Ce projet démontre l'utilisation de Terraform pour automatiser le provisionnement d'une machine virtuelle sur une infrastructure KVM/libvirt.

La séparation entre les fichiers Terraform, les variables d'environnement, les templates Cloud-Init et l'image système permet de conserver une organisation claire et de faciliter le redéploiement.

Le processus repose sur quatre étapes fondamentales :

1. **Préparer** : récupérer le projet et préparer l'image Ubuntu Cloud.
2. **Configurer** : renseigner les variables et les paramètres de la VM.
3. **Provisionner** : initialiser, valider, planifier et appliquer Terraform.
4. **Vérifier** : contrôler la VM, Cloud-Init, le réseau et l'accès SSH.

La configuration est ainsi reproductible sur un hôte disposant des prérequis nécessaires, à condition de préparer les fichiers locaux ignorés par Git et de vérifier les ressources libvirt avant chaque nouvelle application.

**Fin du guide de redéploiement.**
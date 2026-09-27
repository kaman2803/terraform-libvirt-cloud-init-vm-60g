# Automatisation de VM KVM/libvirt avec Terraform et Cloud-Init

## 1. Présentation du projet

Ce projet a pour objectif d'automatiser le déploiement et la configuration initiale de machines virtuelles sur une infrastructure KVM/libvirt à l'aide de Terraform et Cloud-Init.

### Architecture

- Machine d'administration : `srv01-admin`
- Système d'exploitation : Ubuntu Server 24.04.5 LTS
- Serveur KVM/libvirt cible : `192.168.122.1`
- Infrastructure as Code : Terraform
- Initialisation des VM : Cloud-Init
- Virtualisation : KVM/libvirt

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

## 4. Environnement d'administration

Le projet est administré depuis la VM `srv01-admin`.

### Caractéristiques

* Système : Ubuntu Server 24.04.5 LTS
* Architecture : ARM64
* Kernel : `6.8.0-139-generic`
* Terraform : `1.16.3`
* Ansible : `2.16.3`
* Cloud-Init : `26.1-0ubuntu1~24.04.1`
* OpenSSH : `9.6p1`

### Connectivité vers le serveur KVM/libvirt

La connectivité réseau vers le serveur KVM/libvirt `192.168.122.1` a été validée.

```text
4 paquets transmis
4 paquets reçus
0 % de perte
```

## 5. Outils nécessaires

Les composants nécessaires au projet seront installés et validés progressivement :

* Terraform
* Client libvirt (`virsh`)
* Cloud-Init
* Cloud Image Utils (`cloud-localds`)
* OpenSSH

## 6. Déploiement

Le déploiement des machines virtuelles sera réalisé automatiquement avec Terraform.

Cloud-Init sera utilisé pour automatiser la configuration initiale des machines virtuelles.

## 7. Validation

Chaque étape du projet sera validée avant de poursuivre l'étape suivante.

Les validations comprendront notamment :

* connectivité réseau ;
* communication avec le serveur KVM/libvirt ;
* téléchargement et validation de l'image Cloud ;
* création des volumes ;
* création des machines virtuelles ;
* démarrage des VM ;
* configuration Cloud-Init ;
* accès SSH ;
* vérification de la configuration finale.

---

**KG-Lab**
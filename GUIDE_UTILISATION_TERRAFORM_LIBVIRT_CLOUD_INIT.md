# Guide d’utilisation — Terraform, Cloud-Init et KVM/libvirt

## 1. Présentation

Ce projet automatise le déploiement de trois machines virtuelles Ubuntu sur un hôte KVM/libvirt à l’aide de Terraform et de Cloud-Init.

Les machines définies dans le fichier `environments/kgoumou/terraform.tfvars` sont :

| Nom Terraform | Nom d’hôte de la VM | vCPU | RAM | Disque |
|---|---|---:|---:|---:|
| `node1` | `srv-node1` | 1 | 2048 MiB | 20 Go |
| `node2` | `srv-node2` | 1 | 2048 MiB | 20 Go |
| `node3` | `srv-node3` | 1 | 2048 MiB | 20 Go |

Terraform utilise le provider `dmacvicar/libvirt` en version `0.9.9` et la connexion libvirt système `qemu:///system`.

> **Attention :** les commandes de ce guide doivent être exécutées sur l’hôte KVM qui possède les machines virtuelles et les pools libvirt.

## 2. Structure du projet

La structure utile au déploiement est la suivante :

```text
terraform-libvirt-cloud-init/
├── environments/
│   └── kgoumou/
│       └── terraform.tfvars
├── images/
│   └── ubuntu-noble-20g.qcow2
├── templates/
│   ├── meta-data.yaml.tftpl
│   └── user-data.yaml.tftpl
├── terraform/
│   ├── cloudinit.tf
│   ├── domain.tf
│   ├── locals.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── versions.tf
│   ├── volume.tf
│   └── .terraform.lock.hcl
└── README.md
```

Le dossier `images/` est nécessaire. L’image `ubuntu-noble-20g.qcow2` doit être présente à l’emplacement attendu par la configuration Terraform.

## 3. Prérequis et contrôles avant déploiement

### 3.1 Se placer dans le projet

Depuis un terminal :

```bash
cd ~/lab/terraform-libvirt-cloud-init-restaure
```

Si le projet est installé dans un autre emplacement, adapter le chemin.

### 3.2 Vérifier les outils

```bash
terraform version
virsh version
```

Le projet a été testé avec Terraform `1.17.1` et le provider libvirt `0.9.9`.

### 3.3 Vérifier la présence de l’image Ubuntu

```bash
ls -lh images/ubuntu-noble-20g.qcow2
```

Si le fichier est absent, ne pas lancer `terraform apply`. Restaurer ou copier l’image de base dans le dossier `images/`, puis vérifier à nouveau sa présence.

### 3.4 Vérifier la connexion et les pools libvirt

```bash
virsh -c qemu:///system list --all
virsh pool-list --all
```

Le projet utilise les pools `default` pour les disques des VM et `iso` pour les supports Cloud-Init. Vérifier qu’ils existent et sont actifs.

Pour examiner le contenu des pools :

```bash
virsh vol-list default
virsh vol-list iso
```

**Protection des VM existantes :** avant tout déploiement ou toute suppression, identifier les machines déjà présentes. Dans cet environnement, les VM préexistantes à préserver sont `oracle-db-server`, `pve1` et `win10-lab`. Ne jamais les ajouter à la configuration du projet ni supprimer leurs disques manuellement.

## 4. Initialiser Terraform

Depuis la racine du projet :

```bash
terraform -chdir=terraform init
```

Cette commande initialise le répertoire Terraform et installe ou réutilise les providers définis dans le fichier de verrouillage.

Résultat attendu : un message indiquant que Terraform a été initialisé avec succès.

## 5. Vérifier la configuration

### 5.1 Formater les fichiers Terraform

```bash
terraform -chdir=terraform fmt
```

### 5.2 Valider la configuration

```bash
terraform -chdir=terraform validate
```

Résultat attendu :

```text
Success! The configuration is valid.
```

### 5.3 Prévisualiser le déploiement

```bash
terraform -chdir=terraform plan -var-file=../environments/kgoumou/terraform.tfvars
```

Lire attentivement le plan avant de continuer. Pour le déploiement initial validé pendant le laboratoire, le plan annonçait :

```text
Plan: 12 to add, 0 to change, 0 to destroy.
```

Ce nombre correspond au plan observé lors de ce test. Il peut varier si le code, l’état Terraform ou l’infrastructure ont changé.

**Ne pas lancer l’application si le plan prévoit la destruction ou la modification de ressources qui ne font pas partie de ce projet.**

## 6. Déployer les machines virtuelles

Lorsque le plan a été vérifié :

```bash
terraform -chdir=terraform apply -var-file=../environments/kgoumou/terraform.tfvars
```

Terraform affiche le plan et demande une confirmation. Vérifier une dernière fois les actions prévues, puis saisir :

```text
yes
```

Attendre la fin de l’opération. Ne pas interrompre Terraform pendant la création des disques et des domaines libvirt.

## 7. Vérifier le déploiement

### 7.1 Vérifier les machines virtuelles dans libvirt

```bash
virsh list --all
```

Les trois machines attendues sont :

- `srv-node1`
- `srv-node2`
- `srv-node3`

Après un démarrage réussi, leur état doit être `running`.

### 7.2 Vérifier les ressources suivies par Terraform

```bash
terraform -chdir=terraform state list
```

Dans le déploiement validé, l’état contenait 12 ressources :
- 3 ressources `libvirt_cloudinit_disk.vm_init`
- 3 ressources `libvirt_domain.vm`
- 3 ressources `libvirt_volume.vm_disk_20g`
- 3 ressources `libvirt_volume.vm_init_iso`

### 7.3 Vérifier la cohérence entre Terraform et l’infrastructure

```bash
terraform -chdir=terraform plan -var-file=../environments/kgoumou/terraform.tfvars
```

Lorsque la configuration et l’infrastructure correspondent, Terraform affiche :

```text
No changes. Your infrastructure matches the configuration.
```

## 8. Supprimer les machines virtuelles avec Terraform

> **Opération destructive :** `terraform destroy` supprime les ressources gérées par l’état Terraform du projet courant. Toujours vérifier le répertoire courant, le fichier d’état et le plan avant de confirmer.

### 8.1 Vérifier l’état Terraform avant suppression

```bash
terraform -chdir=terraform state list
```

S’assurer que les ressources listées appartiennent uniquement à ce projet et que les domaines concernés sont bien `srv-node1`, `srv-node2` et `srv-node3`.

### 8.2 Lancer la prévisualisation de destruction

```bash
terraform -chdir=terraform plan -destroy -var-file=../environments/kgoumou/terraform.tfvars
```

Lire le plan. Ne pas poursuivre si des ressources étrangères au projet sont concernées.

### 8.3 Exécuter la destruction

```bash
terraform -chdir=terraform destroy -var-file=../environments/kgoumou/terraform.tfvars
```

Terraform demande une confirmation. Après vérification du plan, saisir :

```text
yes
```

Attendre le message de fin. Lors du test réalisé, Terraform a indiqué :

```text
Destroy complete! Resources: 12 destroyed.
```

Le nombre exact dépend de l’état du projet au moment de l’opération.

## 9. Vérifications après destruction

### 9.1 Vérifier les domaines libvirt

```bash
virsh list --all
```

Les trois VM du projet (`srv-node1`, `srv-node2`, `srv-node3`) ne doivent plus apparaître.

### 9.2 Vérifier les disques du pool `default`

```bash
virsh vol-list default
```

Les disques des trois VM du projet ne doivent plus apparaître. Dans le test validé, les volumes des VM préexistantes étaient toujours présents :

```text
oracle-db-server.qcow2
pve1.qcow2
win10-lab.qcow2
```

### 9.3 Vérifier les pools

```bash
virsh pool-list --all
```

Pour afficher les volumes du pool Cloud-Init :

```bash
virsh vol-list iso
```

### 9.4 Vérifier l’état Terraform

```bash
terraform -chdir=terraform state list
```

Après une destruction complète réussie, aucune ressource gérée par ce déploiement ne doit rester dans l’état.

## 10. Sauvegarde du projet avant une modification importante

Avant une refactorisation ou une modification majeure, revenir à la racine du projet et créer une archive datée. Exemple :

```bash
cd ~/lab
tar -czf terraform-libvirt-cloud-init-backup-$(date +%F-%H%M%S).tar.gz \
  --exclude='terraform-libvirt-cloud-init-restaure/images' \
  terraform-libvirt-cloud-init-restaure
```

Cette commande exclut le dossier `images/` de l’archive. Si l’archive doit être autonome et permettre une restauration complète sans recopier l’image, retirer l’option `--exclude` (l’archive sera beaucoup plus volumineuse).

Après création, vérifier l’archive :

```bash
ls -lh terraform-libvirt-cloud-init-backup-*.tar.gz
tar -tzf NOM_DE_L_ARCHIVE.tar.gz | head -30
```

Remplacer `NOM_DE_L_ARCHIVE.tar.gz` par le nom exact du fichier créé.

## 11. Commandes essentielles — mémo

À exécuter depuis la racine du projet :

| Objectif | Commande |
|---|---|
| Initialiser | `terraform -chdir=terraform init` |
| Formater | `terraform -chdir=terraform fmt` |
| Valider | `terraform -chdir=terraform validate` |
| Prévisualiser | `terraform -chdir=terraform plan -var-file=../environments/kgoumou/terraform.tfvars` |
| Déployer | `terraform -chdir=terraform apply -var-file=../environments/kgoumou/terraform.tfvars` |
| Voir l’état Terraform | `terraform -chdir=terraform state list` |
| Voir les VM | `virsh list --all` |
| Voir les pools | `virsh pool-list --all` |
| Voir les volumes `default` | `virsh vol-list default` |
| Voir les volumes `iso` | `virsh vol-list iso` |
| Prévisualiser la destruction | `terraform -chdir=terraform plan -destroy -var-file=../environments/kgoumou/terraform.tfvars` |
| Supprimer les ressources du projet | `terraform -chdir=terraform destroy -var-file=../environments/kgoumou/terraform.tfvars` |

## 12. Bonnes pratiques et précautions

1. Toujours exécuter les commandes depuis le bon dossier de projet.
2. Toujours utiliser le fichier de variables correspondant à l’environnement : `environments/kgoumou/terraform.tfvars`.
3. Vérifier la présence de l’image QCOW2 avant le déploiement.
4. Exécuter `terraform validate` et `terraform plan` avant `apply`.
5. Lire le plan complet avant de confirmer `apply` ou `destroy`.
6. Ne jamais utiliser `terraform destroy` depuis un autre projet ou avec un état Terraform non vérifié.
7. Ne pas supprimer manuellement les disques avec `rm` ni les domaines avec `virsh undefine` lorsque Terraform les gère.
8. Sauvegarder le projet et son état avant les changements importants.
9. Conserver le fichier `.terraform.lock.hcl` afin de verrouiller les versions des providers.
10. Ne pas considérer une VM comme prête simplement parce que son domaine est `running` : vérifier également son accès réseau et SSH si ces tests font partie de l’objectif du laboratoire.

---

**Fin du guide d’utilisation.**

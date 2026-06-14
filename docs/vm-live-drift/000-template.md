# DRIFT-NNN — &lt;titre court de l'écart&gt;

| Champ              | Valeur                                                            |
|--------------------|-------------------------------------------------------------------|
| **ID**             | DRIFT-NNN                                                         |
| **Date détection** | YYYY-MM-DD                                                        |
| **VM live / plan** | IP / RG / nom — ou plan publié `standard/6.0.YYYYMMDD`            |
| **Image en cause** | `<gallery>/<image>:<version>` — exemple `galSMWMarketplace/smw-knowledge-base:6.0.20260517` |
| **Composant**      | apache / php / mysql / mediawiki / smw / waagent / kernel / ssh / ufw / ... |
| **Statut**         | investigating \| open \| in-packer \| resolved \| wontfix         |
| **Smoke test(s)**  | nom du script / cible Make — exemple `make vm-security-check` Test #N |
| **ADR**            | ADR-NNN (lien)                                                    |

---

## 1. Symptôme observé

> Description précise de l'échec **tel que vu côté test / utilisateur / rapport
> Partner Center**.

```text
# Sortie test, log, header HTTP, exception, capture Partner Center…
```

---

## 2. Reproduction

```bash
# Commande(s) minimale(s) pour reproduire sur la VM live
ssh azureuser@$VM_IP "dpkg-query -W -f='\${Package}\t\${Version}\n' <pkg>"
# ou
curl -sk -D- https://$VM_IP/ -o /dev/null
```

---

## 3. Cause racine

> Pourquoi l'image **buildée à partir de Packer** n'a pas (ou n'a plus) cette
> configuration / cette version ?
>
> - Provisioner manquant ?
> - Provisioner partiel (lignes manquantes) ?
> - Configuration appliquée mais écrasée par un autre script (ordre des
>   provisioners — ADR-613) ?
> - Image construite **avant** un commit correcteur (`git log <fichier>`) ?
> - Fix présent dans repo mais **plan Marketplace pas remplacé** (cas classique
>   du gap publication vs build) ?
> - Dérive upstream Ubuntu (USN postérieur à la dernière image gallery) ?

---

## 4. Correction appliquée sur la VM (hotfix)

```bash
# Commandes exactes — copier/coller — exécutées en SSH
ssh azureuser@$VM_IP <<'EOF'
sudo apt-get update
sudo apt-get -y -o Dpkg::Options::='--force-confold' dist-upgrade
sudo systemctl restart apache2
EOF
```

Vérification post-fix :

```bash
make vm-security-check VM_IP=$VM_IP
# Test attendu PASS : ...
```

---

## 5. Propagation Packer

### Fichier(s) à modifier
- [ ] `packer/provisioners/<fichier>.sh`
- [ ] `packer/scripts/<fichier>.sh`
- [ ] `packer/smw-vm.pkr.hcl` (si var Packer)
- [ ] `arm/mainTemplate.bicep` (si imageId)

### Diff suggéré

```diff
# Exemple
- apt-get upgrade -y
+ apt-get -y -q -o Dpkg::Options::='--force-confold' dist-upgrade
+ # Gate USN — ADR-300 Test #16
+ check_pkg_min_version libgnutls30 "3.7.3-4ubuntu1.9"
```

### Bump version (ADR-607)
- Version actuelle gallery : `6.0.YYYYMMDD`
- Version cible : `6.0.YYYYMMDD+1`
- Tag git : `v6.0.YYYYMMDD+1-drift-NNN-<slug>`

---

## 6. Validation post-rebuild

Une fois `make packer-build` + `make gallery-publish` exécutés :

```bash
make vm-dev-delete                  # nettoyer ancienne VM dev
make vm-dev-create                  # tire l'image dernière version
make integration-test-image         # ADR-700 phase 2
make integration-test-e2e           # ADR-700 phase 3
make vm-security-check              # doit être 100 % PASS
```

Cocher quand validé :

- [ ] Image rebuild OK (`make packer-build`)
- [ ] Image publiée gallery
- [ ] VM neuve créée
- [ ] Tests intégration : PASS
- [ ] Plan vulnérable précédent **déprécié** dans Partner Center
- [ ] REGISTRY.md mis à jour (`status: resolved` + version + commit)

---

## 7. ADR impacté

Si la décision change ou clarifie une règle existante, mettre à jour l'ADR :
- ADR-NNN : « ajout du contrôle XYZ dans la liste hardening »

---

## 8. Historique

| Date       | Auteur        | Événement                                  |
|------------|---------------|--------------------------------------------|
| YYYY-MM-DD | @michel-heon | Détection initiale + hotfix VM             |
| YYYY-MM-DD | @michel-heon | Propagation Packer (commit `<sha>`)        |
| YYYY-MM-DD | @michel-heon | Image `v6.0.YYYYMMDD+1` publiée → resolved |

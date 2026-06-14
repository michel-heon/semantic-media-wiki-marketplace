#!/usr/bin/env bash
# =============================================================================
# packer/scripts/vm-manage.sh
# ADR-601 : vm-manage — Gestion du cycle de vie de la VM de test E2E
# ADR-602 : Logique extraite du Makefile (règle des 3 lignes)
#
# Sous-commandes :
#   ensure           Créer la VM de test si absente (depuis la dernière image gallery)
#   stop             Deallocater la VM
#   start            Démarrer la VM
#   delete           Supprimer la VM
#   id               Afficher l'ID et la version de la dernière image gallery
#   dns-assign       Assigner un label DNS à l'IP publique de la VM
#   dns-assign-reboot Assigner le DNS puis redémarrer la VM
#   status                Afficher l'état, l'IP, le DNS et l'URL de la VM de test
#   get-ip                Retourner le FQDN (ou l'IP) de la VM — pour scripts/Makefile
#   reset-admin-password  Réinitialiser le mot de passe WikiAdmin à ChangeMe123!
# =============================================================================
# Usage: bash packer/scripts/vm-manage.sh <ensure|stop|start|delete|id|dns-assign|dns-assign-reboot|firstboot-reset|status|get-ip|reset-admin-password>
# Variables d'environnement optionnelles (surchargeables) :
#   E2E_RG, VM_SIZE, GALLERY_NAME, GALLERY_IMAGE_NAME, GALLERY_RESOURCE_GROUP
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# --- Racine du dépôt (chemin absolu, indépendant du CWD appelant) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# --- Source de la configuration générée (ADR-600) ---
CONFIG_MAKE="${REPO_ROOT}/env/generated/config.make"
if [ -f "$CONFIG_MAKE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_MAKE"
else
    printf "${RED}✗ ${CONFIG_MAKE} absent — lancez : make config${NC}\n"
    exit 1
fi

# --- Valeurs par défaut (surchargeables via l'environnement ou le Makefile) ---
E2E_RG="${E2E_RG:-rg-smw-marketplace-e2e}"
VM_SIZE="${VM_SIZE:-Standard_D4s_v3}"
BUILD_DATE="${BUILD_DATE:-$(date +%Y%m%d)}"
GALLERY_NAME="${GALLERY_NAME:?Variable GALLERY_NAME non définie dans config.make}"
GALLERY_IMAGE_NAME="${GALLERY_IMAGE_NAME:?Variable GALLERY_IMAGE_NAME non définie dans config.make}"
GALLERY_RESOURCE_GROUP="${GALLERY_RESOURCE_GROUP:?Variable GALLERY_RESOURCE_GROUP non définie dans config.make}"

# --- Helpers ---
find_test_vm() {
    az vm list -g "$E2E_RG" \
        --query "[?starts_with(name,'test-smw')].name | sort(@) | [-1]" \
        -o tsv 2>/dev/null || true
}

get_latest_image_id() {
    az sig image-version list \
        --gallery-name "$GALLERY_NAME" \
        --gallery-image-definition "$GALLERY_IMAGE_NAME" \
        --resource-group "$GALLERY_RESOURCE_GROUP" \
        --query "sort_by(@, &publishingProfile.publishedDate)[-1].id" \
        -o tsv 2>/dev/null || true
}

get_latest_image_version() {
    az sig image-version list \
        --gallery-name "$GALLERY_NAME" \
        --gallery-image-definition "$GALLERY_IMAGE_NAME" \
        --resource-group "$GALLERY_RESOURCE_GROUP" \
        --query "sort_by(@, &publishingProfile.publishedDate)[-1].name" \
        -o tsv 2>/dev/null || true
}

# --- Dispatch des sous-commandes ---
cmd="${1:-}"

case "$cmd" in
    ensure)
        VM=$(find_test_vm)
        if [ -z "$VM" ]; then
            printf "${YELLOW}  ➜ Aucune VM de test dans ${E2E_RG}, création...${NC}\n"
            IMAGE_ID=$(get_latest_image_id)
            if [ -z "$IMAGE_ID" ]; then
                printf "${RED}  ✗ Aucune image dans ${GALLERY_NAME}/${GALLERY_IMAGE_NAME}${NC}\n"
                exit 1
            fi
            VM_NAME="test-smw-${BUILD_DATE}"
            printf "${CYAN}  → Création RG si absent : ${E2E_RG}${NC}\n"
            az group create \
                --name "$E2E_RG" \
                --location "${AZURE_LOCATION:-canadacentral}" \
                --output none
            printf "${CYAN}  → Création VM : ${VM_NAME} (${VM_SIZE})${NC}\n"
            CUSTOM_DATA_B64=$(printf '{"wikiAdminPassword":"ChangeMe123!"}' | base64 -w 0)
            az vm create \
                --resource-group "$E2E_RG" \
                --name "$VM_NAME" \
                --image "$IMAGE_ID" \
                --size "$VM_SIZE" \
                --admin-username azureuser \
                --generate-ssh-keys \
                --public-ip-sku Standard \
                --security-type TrustedLaunch \
                --custom-data "$CUSTOM_DATA_B64" \
                --output table
            printf "${GREEN}  ✓ VM créée : ${VM_NAME}${NC}\n"
        else
            VM_NAME="$VM"
            printf "${GREEN}  ✓ VM de test existante : ${VM_NAME}${NC}\n"
        fi
        NSG_NAME="${VM_NAME}NSG"
        printf "${CYAN}  → Vérification ports HTTP/HTTPS dans le NSG : ${NSG_NAME}${NC}\n"
        az network nsg rule create \
            -g "$E2E_RG" --nsg-name "${NSG_NAME}" \
            -n allow-http --priority 1010 \
            --access Allow --direction Inbound \
            --protocol Tcp --destination-port-ranges "${WIKI_HTTP_PORT:-80}" --output none 2>/dev/null || true
        az network nsg rule create \
            -g "$E2E_RG" --nsg-name "${NSG_NAME}" \
            -n allow-https --priority 1020 \
            --access Allow --direction Inbound \
            --protocol Tcp --destination-port-ranges "${WIKI_PORT:-443}" --output none 2>/dev/null || true
        printf "${GREEN}  ✓ Ports ${WIKI_HTTP_PORT:-80}/${WIKI_PORT:-443} ouverts dans le NSG${NC}\n"
        ;;

    stop)
        VM=$(find_test_vm)
        [ -z "$VM" ] && { printf "${RED}  ✗ Aucune VM dans ${E2E_RG}${NC}\n"; exit 1; }
        printf "${CYAN}  → Deallocate : ${VM}${NC}\n"
        az vm deallocate -g "$E2E_RG" -n "$VM" --no-wait
        printf "${GREEN}  ✓ Arrêt lancé : ${VM}${NC}\n"
        ;;

    start)
        VM=$(find_test_vm)
        [ -z "$VM" ] && { printf "${RED}  ✗ Aucune VM dans ${E2E_RG}${NC}\n"; exit 1; }
        printf "${CYAN}  → Démarrage : ${VM}${NC}\n"
        az vm start -g "$E2E_RG" -n "$VM"
        printf "${GREEN}  ✓ VM démarrée : ${VM}${NC}\n"
        ;;

    delete)
        if ! az group show -n "$E2E_RG" --output none 2>/dev/null; then
            printf "${YELLOW}  ➜ Resource group inexistant : ${E2E_RG}${NC}\n"
            exit 0
        fi
        printf "${CYAN}  → Suppression du resource group (VM + ressources associées) : ${E2E_RG}${NC}\n"
        az group delete -n "$E2E_RG" --yes --no-wait
        printf "${GREEN}  ✓ Suppression lancée : ${E2E_RG}${NC}\n"
        ;;

    id)
        IMAGE_ID=$(get_latest_image_id)
        [ -z "$IMAGE_ID" ] && {
            printf "${RED}  ✗ Aucune image dans ${GALLERY_NAME}/${GALLERY_IMAGE_NAME}${NC}\n"
            exit 1
        }
        VERSION=$(get_latest_image_version)
        printf "${GREEN}  ✓ Version : ${VERSION}${NC}\n"
        printf "${CYAN}  ID : ${IMAGE_ID}${NC}\n"
        ;;

    dns-assign)
        VM=$(find_test_vm)
        [ -z "$VM" ] && { printf "${RED}  ✗ Aucune VM dans ${E2E_RG}${NC}\n"; exit 1; }
        printf "${CYAN}  → Attribution label DNS à la VM ${VM}...${NC}\n"
        NIC_ID=$(az vm show -g "$E2E_RG" -n "$VM" \
            --query "networkProfile.networkInterfaces[0].id" -o tsv)
        PIP_ID=$(az network nic show --ids "$NIC_ID" \
            --query "ipConfigurations[0].publicIPAddress.id" -o tsv 2>/dev/null || true)
        if [ -z "$PIP_ID" ]; then
            printf "${RED}  ✗ Aucune IP publique associée à ${VM}${NC}\n"
            exit 1
        fi
        PIP_NAME=$(basename "$PIP_ID")
        PIP_RG=$(echo "$PIP_ID" | awk -F'/' '{print $5}')
        DNS_LABEL="smw-test-$(date +%Y%m%d)"
        az network public-ip update \
            -g "$PIP_RG" \
            -n "$PIP_NAME" \
            --dns-name "$DNS_LABEL" \
            --output none
        FQDN=$(az network public-ip show -g "$PIP_RG" -n "$PIP_NAME" \
            --query "dnsSettings.fqdn" -o tsv)
        # DNS inverse (PTR) : permet à getent hosts <ip> de retourner le FQDN dans la VM
        az network public-ip update \
            -g "$PIP_RG" \
            -n "$PIP_NAME" \
            --reverse-fqdn "${FQDN}" \
            --output none 2>/dev/null || true
        printf "${GREEN}  ✓ FQDN: ${FQDN}${NC}\n"
        printf "${CYAN}  ℹ DNS direct + inverse configurés — getent hosts détectera le FQDN${NC}\n"
        ;;

    dns-assign-reboot)
        bash "$0" dns-assign
        VM=$(find_test_vm)
        [ -z "$VM" ] && { printf "${RED}  ✗ Aucune VM dans ${E2E_RG}${NC}\n"; exit 1; }
        printf "${CYAN}  → Redémarrage de la VM ${VM}...${NC}\n"
        az vm restart -g "$E2E_RG" -n "$VM" --no-wait
        printf "${GREEN}  ✓ Redémarrage lancé — la VM détectera le FQDN via IMDS au démarrage${NC}\n"
        ;;

    firstboot-reset)
        # Efface le sentinel + redémarre smw-firstboot.service via Azure Run Command
        # Utile quand firstboot a déjà tourné (avec IP) et qu'on veut le rejouer avec le FQDN
        VM=$(find_test_vm)
        [ -z "$VM" ] && { printf "${RED}  ✗ Aucune VM dans ${E2E_RG}${NC}\n"; exit 1; }
        printf "${CYAN}  → Effacement du sentinel et relance de smw-firstboot sur ${VM}...${NC}\n"
        # Déclenche smw-firstboot avec --no-block pour éviter le timeout de 90s de RunShellScript
        az vm run-command invoke \
            -g "$E2E_RG" -n "$VM" \
            --command-id RunShellScript \
            --scripts '#!/bin/bash
set -euo pipefail
rm -f /var/lib/smw/.firstboot-done
systemctl stop smw-firstboot.service 2>/dev/null || true
systemctl reset-failed smw-firstboot.service 2>/dev/null || true
systemctl start --no-block smw-firstboot.service
echo "[firstboot-reset] service smw-firstboot déclenché (--no-block)"' \
            --query 'value[0].message' -o tsv
        printf "${GREEN}  ✓ smw-firstboot déclenché — en cours d'exécution (attendre ~90s)${NC}\n"
        printf "${YELLOW}  → Vérifier : journalctl -u smw-firstboot.service -f${NC}\n"
        ;;

    status)
        VM=$(find_test_vm)
        if [ -z "$VM" ]; then
            printf "${YELLOW}  ⚠ Aucune VM de test dans ${E2E_RG}${NC}\n"
            exit 0
        fi
        STATE=$(az vm show -g "$E2E_RG" -n "$VM" -d --query powerState -o tsv 2>/dev/null || echo "inconnu")
        NIC_ID=$(az vm show -g "$E2E_RG" -n "$VM" \
            --query "networkProfile.networkInterfaces[0].id" -o tsv)
        PIP_ID=$(az network nic show --ids "$NIC_ID" \
            --query "ipConfigurations[0].publicIPAddress.id" -o tsv 2>/dev/null || true)
        if [ -n "$PIP_ID" ]; then
            PIP_JSON=$(az network public-ip show --ids "$PIP_ID" \
                --query "{ip:ipAddress,fqdn:dnsSettings.fqdn}" -o json 2>/dev/null || echo '{}')
            IP=$(printf '%s' "$PIP_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ip') or '')")
            FQDN=$(printf '%s' "$PIP_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('fqdn') or '')")
        else
            IP=""; FQDN=""
        fi
        printf "${CYAN}  VM     : ${VM}${NC}\n"
        printf "${CYAN}  État   : ${STATE}${NC}\n"
        if [ -n "$IP" ]; then
            printf "${GREEN}  IP     : ${IP}${NC}\n"
        else
            printf "${YELLOW}  IP     : (aucune IP publique)${NC}\n"
        fi
        if [ -n "$FQDN" ]; then
            printf "${GREEN}  DNS    : ${FQDN}${NC}\n"
            printf "${GREEN}  URL    : http://${FQDN}/index.php${NC}\n"
        elif [ -n "$IP" ]; then
            printf "${YELLOW}  DNS    : (aucun label DNS assigné)${NC}\n"
            printf "${GREEN}  URL    : http://${IP}/index.php${NC}\n"
        else
            printf "${YELLOW}  DNS    : (aucun label DNS assigné)${NC}\n"
            printf "${YELLOW}  URL    : (IP publique introuvable)${NC}\n"
        fi
        ;;

    get-ip)
        # Sortie machine (pas de couleurs) — FQDN si DNS assigné, sinon IP brute
        VM=$(find_test_vm)
        if [ -z "$VM" ]; then exit 1; fi
        NIC_ID=$(az vm show -g "$E2E_RG" -n "$VM" \
            --query "networkProfile.networkInterfaces[0].id" -o tsv)
        PIP_ID=$(az network nic show --ids "$NIC_ID" \
            --query "ipConfigurations[0].publicIPAddress.id" -o tsv 2>/dev/null || true)
        if [ -z "$PIP_ID" ]; then exit 1; fi
        PIP_JSON=$(az network public-ip show --ids "$PIP_ID" \
            --query "{ip:ipAddress,fqdn:dnsSettings.fqdn}" -o json 2>/dev/null || echo '{}')
        FQDN=$(printf '%s' "$PIP_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('fqdn') or '')")
        IP=$(printf '%s' "$PIP_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ip') or '')")
        if [ -n "$FQDN" ]; then
            printf '%s\n' "$FQDN"
        elif [ -n "$IP" ]; then
            printf '%s\n' "$IP"
        else
            exit 1
        fi
        ;;

    reset-admin-password)
        VM=$(find_test_vm)
        [ -z "$VM" ] && { printf "${RED}  ✗ Aucune VM dans ${E2E_RG}${NC}\n"; exit 1; }
        printf "${CYAN}  → Réinitialisation du mot de passe WikiAdmin sur ${VM}...${NC}\n"
        az vm run-command invoke \
            -g "$E2E_RG" -n "$VM" \
            --command-id RunShellScript \
            --scripts 'sudo -u www-data php /opt/mediawiki/maintenance/changePassword.php --user WikiAdmin --password "ChangeMe123!"' \
            --query 'value[0].message' -o tsv
        printf "${GREEN}  ✓ Mot de passe WikiAdmin réinitialisé → ChangeMe123!${NC}\n"
        ;;

    *)
        printf "${RED}Usage: $0 <ensure|stop|start|delete|id|dns-assign|dns-assign-reboot|firstboot-reset|status|get-ip|reset-admin-password>${NC}\n"
        exit 1
        ;;
esac

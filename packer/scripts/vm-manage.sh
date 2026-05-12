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
#   status           Afficher l'état, l'IP, le DNS et l'URL de la VM de test
# =============================================================================
# Usage: bash packer/scripts/vm-manage.sh <ensure|stop|start|delete|id|dns-assign|dns-assign-reboot|status>
# Variables d'environnement optionnelles (surchargeables) :
#   E2E_RG, VM_SIZE, GALLERY_NAME, GALLERY_IMAGE_NAME, GALLERY_RESOURCE_GROUP
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# --- Source de la configuration générée (ADR-600) ---
CONFIG_MAKE="env/generated/config.make"
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
            printf "${CYAN}  → Création VM : ${VM_NAME} (${VM_SIZE})${NC}\n"
            az vm create \
                --resource-group "$E2E_RG" \
                --name "$VM_NAME" \
                --image "$IMAGE_ID" \
                --size "$VM_SIZE" \
                --admin-username azureuser \
                --generate-ssh-keys \
                --public-ip-sku Standard \
                --output table
            printf "${GREEN}  ✓ VM créée : ${VM_NAME}${NC}\n"
        else
            printf "${GREEN}  ✓ VM de test existante : ${VM}${NC}\n"
        fi
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
        VM=$(find_test_vm)
        [ -z "$VM" ] && { printf "${RED}  ✗ Aucune VM dans ${E2E_RG}${NC}\n"; exit 1; }
        printf "${CYAN}  → Suppression : ${VM}${NC}\n"
        az vm delete -g "$E2E_RG" -n "$VM" --yes --no-wait
        printf "${GREEN}  ✓ Suppression lancée : ${VM}${NC}\n"
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
        printf "${GREEN}  ✓ FQDN: ${FQDN}${NC}\n"
        printf "${CYAN}  ℹ La VM détectera le FQDN via IMDS au prochain démarrage${NC}\n"
        ;;

    dns-assign-reboot)
        bash "$0" dns-assign
        VM=$(find_test_vm)
        [ -z "$VM" ] && { printf "${RED}  ✗ Aucune VM dans ${E2E_RG}${NC}\n"; exit 1; }
        printf "${CYAN}  → Redémarrage de la VM ${VM}...${NC}\n"
        az vm restart -g "$E2E_RG" -n "$VM" --no-wait
        printf "${GREEN}  ✓ Redémarrage lancé — la VM détectera le FQDN via IMDS au démarrage${NC}\n"
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

    *)
        printf "${RED}Usage: $0 <ensure|stop|start|delete|id|dns-assign|dns-assign-reboot|status>${NC}\n"
        exit 1
        ;;
esac

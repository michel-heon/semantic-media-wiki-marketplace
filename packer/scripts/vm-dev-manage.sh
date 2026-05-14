#!/usr/bin/env bash
# =============================================================================
# packer/scripts/vm-dev-manage.sh
# ADR-601 : vm-dev-manage — Workflow d'itération dev sur VM Azure (ADR-614)
# ADR-602 : Logique extraite du Makefile (règle des 3 lignes)
#
# Sous-commandes :
#   create     Créer une VM de développement depuis la dernière image gallery
#   push       Synchroniser les scripts provisioners sur la VM dev (sans rebuild Packer)
#   delete     Supprimer la VM dev et son resource group dédié
#   status     Afficher l'état, l'IP et la commande SSH de la VM dev
# =============================================================================
# Usage: bash packer/scripts/vm-dev-manage.sh <create|push|delete|status>
# Variables d'environnement optionnelles :
#   DEV_RG, VM_SIZE, GALLERY_NAME, GALLERY_IMAGE_NAME, GALLERY_RESOURCE_GROUP
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

# --- Valeurs par défaut ---
DEV_USER="${USER:-$(id -un)}"
BUILD_DATE="${BUILD_DATE:-$(date +%Y%m%d)}"
DEV_RG="${DEV_RG:-rg-smw-dev-${DEV_USER}}"
DEV_VM_NAME="dev-smw-${BUILD_DATE}"
VM_SIZE="${VM_SIZE:-Standard_D2s_v3}"
AZURE_LOCATION="${AZURE_LOCATION:-canadacentral}"
GALLERY_NAME="${GALLERY_NAME:?Variable GALLERY_NAME non définie dans config.make}"
GALLERY_IMAGE_NAME="${GALLERY_IMAGE_NAME:?Variable GALLERY_IMAGE_NAME non définie dans config.make}"
GALLERY_RESOURCE_GROUP="${GALLERY_RESOURCE_GROUP:?Variable GALLERY_RESOURCE_GROUP non définie dans config.make}"

# Répertoire local des provisioners Packer
PROVISIONERS_DIR="packer/provisioners"
# Chemin de destination sur la VM dev
REMOTE_PROVISIONERS="/tmp/smw-provisioners"

# --- Helpers ---
find_dev_vm() {
    az vm list -g "$DEV_RG" \
        --query "[?starts_with(name,'dev-smw')].name | sort(@) | [-1]" \
        -o tsv 2>/dev/null || true
}

get_vm_ip() {
    local vm_name="$1"
    az vm show -g "$DEV_RG" -n "$vm_name" -d \
        --query "publicIps" -o tsv 2>/dev/null || true
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

ensure_dev_rg() {
    if ! az group show -n "$DEV_RG" &>/dev/null; then
        printf "${CYAN}  → Création du resource group : ${DEV_RG} (${AZURE_LOCATION})${NC}\n"
        az group create -n "$DEV_RG" -l "$AZURE_LOCATION" --output none
        printf "${GREEN}  ✓ Resource group créé : ${DEV_RG}${NC}\n"
    else
        printf "${CYAN}  ℹ Resource group existant : ${DEV_RG}${NC}\n"
    fi
}

# --- Dispatch des sous-commandes ---
cmd="${1:-}"

case "$cmd" in
    create)
        ensure_dev_rg

        IMAGE_ID=$(get_latest_image_id)
        if [ -z "$IMAGE_ID" ]; then
            printf "${RED}  ✗ Aucune image disponible dans ${GALLERY_NAME}/${GALLERY_IMAGE_NAME}${NC}\n"
            printf "${YELLOW}  ℹ Lancez 'make vm-build' pour construire une image Packer d'abord.${NC}\n"
            exit 1
        fi
        VERSION=$(get_latest_image_version)
        printf "${CYAN}  → Image gallery : ${GALLERY_IMAGE_NAME} v${VERSION}${NC}\n"

        EXISTING_VM=$(find_dev_vm)
        if [ -n "$EXISTING_VM" ]; then
            printf "${YELLOW}  ⚠ VM dev existante : ${EXISTING_VM} dans ${DEV_RG}${NC}\n"
            printf "${YELLOW}  ℹ Lancez 'make vm-dev-delete' pour la supprimer avant d'en créer une nouvelle.${NC}\n"
            exit 1
        fi

        printf "${CYAN}  → Création VM dev : ${DEV_VM_NAME} (${VM_SIZE}) dans ${DEV_RG}${NC}\n"
        az vm create \
            --resource-group "$DEV_RG" \
            --name "$DEV_VM_NAME" \
            --image "$IMAGE_ID" \
            --size "$VM_SIZE" \
            --admin-username azureuser \
            --generate-ssh-keys \
            --public-ip-sku Standard \
            --output table

        # Ouvrir les ports HTTP/HTTPS dans le NSG généré automatiquement
        NSG_NAME="${DEV_VM_NAME}NSG"
        printf "${CYAN}  → Ouverture ports HTTP/HTTPS dans le NSG : ${NSG_NAME}${NC}\n"
        az network nsg rule create \
            -g "$DEV_RG" --nsg-name "${NSG_NAME}" \
            -n allow-http --priority 1010 \
            --access Allow --direction Inbound \
            --protocol Tcp --destination-port-ranges 80 --output none
        az network nsg rule create \
            -g "$DEV_RG" --nsg-name "${NSG_NAME}" \
            -n allow-https --priority 1020 \
            --access Allow --direction Inbound \
            --protocol Tcp --destination-port-ranges 443 --output none

        IP=$(get_vm_ip "$DEV_VM_NAME")
        printf "${GREEN}  ✓ VM dev créée : ${DEV_VM_NAME}${NC}\n"
        printf "${GREEN}  ✓ IP publique  : ${IP}${NC}\n"
        printf "${CYAN}  ℹ SSH         : ssh azureuser@${IP}${NC}\n"
        printf "${CYAN}  ℹ Push scripts : make provision-push${NC}\n"
        ;;

    push)
        VM=$(find_dev_vm)
        if [ -z "$VM" ]; then
            printf "${RED}  ✗ Aucune VM dev dans ${DEV_RG}${NC}\n"
            printf "${YELLOW}  ℹ Lancez 'make vm-dev-create' pour créer la VM dev.${NC}\n"
            exit 1
        fi

        IP=$(get_vm_ip "$VM")
        if [ -z "$IP" ]; then
            printf "${RED}  ✗ IP publique introuvable pour ${VM} — VM en cours de démarrage ?${NC}\n"
            exit 1
        fi

        if [ ! -d "$PROVISIONERS_DIR" ]; then
            printf "${RED}  ✗ Répertoire introuvable : ${PROVISIONERS_DIR}${NC}\n"
            exit 1
        fi

        printf "${CYAN}  → Synchronisation scripts provisioners vers ${VM} (${IP})...${NC}\n"
        printf "${CYAN}  → Source  : ${PROVISIONERS_DIR}/${NC}\n"
        printf "${CYAN}  → Dest    : azureuser@${IP}:${REMOTE_PROVISIONERS}/${NC}\n"

        ssh -o StrictHostKeyChecking=no \
            -o ConnectTimeout=10 \
            "azureuser@${IP}" \
            "mkdir -p ${REMOTE_PROVISIONERS} && chmod 755 ${REMOTE_PROVISIONERS}"

        rsync -avz --progress \
            -e "ssh -o StrictHostKeyChecking=no" \
            "${PROVISIONERS_DIR}/" \
            "azureuser@${IP}:${REMOTE_PROVISIONERS}/"

        ssh -o StrictHostKeyChecking=no \
            "azureuser@${IP}" \
            "chmod +x ${REMOTE_PROVISIONERS}/*.sh 2>/dev/null || true"

        printf "${GREEN}  ✓ Scripts synchronisés : ${REMOTE_PROVISIONERS}/${NC}\n"
        printf "${CYAN}  ℹ Pour re-exécuter firstboot : ssh azureuser@${IP}${NC}\n"
        printf "${CYAN}    sudo rm -f /var/lib/smw/.firstboot-done && sudo systemctl start smw-firstboot${NC}\n"
        printf "${CYAN}    ou : sudo bash ${REMOTE_PROVISIONERS}/08-firstboot-setup.sh${NC}\n"
        ;;

    delete)
        VM=$(find_dev_vm)
        if [ -z "$VM" ] && ! az group show -n "$DEV_RG" &>/dev/null; then
            printf "${YELLOW}  ⚠ Aucune ressource dev à supprimer (${DEV_RG})${NC}\n"
            exit 0
        fi

        printf "${YELLOW}  ⚠ Suppression du resource group dev : ${DEV_RG}${NC}\n"
        printf "${YELLOW}    Cette opération est irréversible.${NC}\n"
        printf "${CYAN}  → Suppression en cours...${NC}\n"
        az group delete \
            --name "$DEV_RG" \
            --yes \
            --no-wait
        printf "${GREEN}  ✓ Suppression lancée : ${DEV_RG} (opération asynchrone)${NC}\n"
        ;;

    status)
        VM=$(find_dev_vm)
        if [ -z "$VM" ]; then
            printf "${YELLOW}  ⚠ Aucune VM dev dans ${DEV_RG}${NC}\n"
            printf "${CYAN}  ℹ Lancez 'make vm-dev-create' pour créer la VM dev.${NC}\n"
            exit 0
        fi

        STATE=$(az vm show -g "$DEV_RG" -n "$VM" -d --query powerState -o tsv 2>/dev/null || echo "inconnu")
        IP=$(get_vm_ip "$VM")
        VERSION=$(get_latest_image_version)

        printf "${CYAN}  VM     : ${VM}${NC}\n"
        printf "${CYAN}  RG     : ${DEV_RG}${NC}\n"
        printf "${CYAN}  État   : ${STATE}${NC}\n"
        printf "${CYAN}  IP     : ${IP:-N/A}${NC}\n"
        printf "${CYAN}  Image  : ${GALLERY_IMAGE_NAME} v${VERSION:-N/A}${NC}\n"
        if [ -n "$IP" ]; then
            printf "${GREEN}  SSH    : ssh azureuser@${IP}${NC}\n"
            printf "${GREEN}  Wiki   : https://${IP}/  (après firstboot)${NC}\n"
            printf "${GREEN}  Log    : ssh azureuser@${IP} -- sudo journalctl -u smw-firstboot -f${NC}\n"
        fi
        ;;

    *)
        printf "${RED}  ✗ Sous-commande inconnue : '${cmd}'${NC}\n"
        printf "${YELLOW}  Usage : $0 <create|push|delete|status>${NC}\n"
        exit 1
        ;;
esac

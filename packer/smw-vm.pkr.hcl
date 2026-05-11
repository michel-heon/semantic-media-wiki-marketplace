# packer/smw-vm.pkr.hcl
# Template principal Packer — Image VM Semantic MediaWiki pour Azure Marketplace
# ADR-617 — HashiCorp Packer — Outil de Construction d'Images VM Azure
# ADR-613 — Architecture et Validation des Provisioners Packer
#
# Usage :
#   packer init packer/
#   packer validate -var-file=packer/generated.pkrvars.hcl packer/
#   packer build   -var-file=packer/generated.pkrvars.hcl packer/
#
# Ou via Makefile :
#   make vm-validate
#   make vm-build

packer {
  required_version = ">= 1.11.0"
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

# ---------------------------------------------------------------------------
# Locals — nommage versionné (ADR-617, US-01.5)
# ---------------------------------------------------------------------------

locals {
  # Format : {smw_version}.{YYYYMMDD} → ex: 6.0.1.20260511
  image_version = "${var.smw_version}.${var.build_date}"

  # Nom de l'image pour identification dans les logs
  image_label = "smw-knowledge-base-${local.image_version}"
}

# ---------------------------------------------------------------------------
# Source — azure-arm builder (ADR-617)
# ---------------------------------------------------------------------------

source "azure-arm" "smw" {
  # Authentification Service Principal via variables d'environnement
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret

  # Storage Account temporaire pour les artefacts de build
  resource_group_name = var.azure_resource_group
  storage_account     = var.storage_account

  # Image de base Azure endorsée (Ubuntu 22.04 LTS Gen2 — ADR-001)
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  os_type         = "Linux"
  os_disk_size_gb = 30

  # Taille VM de build (ADR-617 — Standard_D4s_v3 pour accélérer la construction)
  vm_size   = var.vm_size
  location  = var.azure_location

  # Destination — Azure Compute Gallery (ADR-617, US-01.3, US-01.5)
  shared_image_gallery_destination {
    resource_group      = var.gallery_resource_group
    gallery_name        = var.gallery_name
    image_name          = var.gallery_image_name
    image_version       = local.image_version
    replication_regions = [var.azure_location]
  }

  # Tags de traçabilité
  azure_tags = {
    project        = "smw-marketplace"
    smw_version    = var.smw_version
    mw_version     = var.mediawiki_version
    php_version    = var.php_version
    build_date     = var.build_date
    image_version  = local.image_version
  }
}

# ---------------------------------------------------------------------------
# Build — séquence des provisioners (ADR-613)
# ---------------------------------------------------------------------------

build {
  name    = "smw-marketplace"
  sources = ["source.azure-arm.smw"]

  # ------------------------------------------------------------------
  # 01 — Installation de base (OS, packages système, répertoires)
  # ------------------------------------------------------------------
  provisioner "shell" {
    script          = "${path.root}/provisioners/01-install-base.sh"
    execute_command = "chmod +x {{.Path}}; sudo -E bash '{{.Path}}'"
    environment_vars = [
      "SMW_LOG_FILE=/var/log/smw-install.log",
    ]
  }

  # ------------------------------------------------------------------
  # 02 — Installation PHP 8.2-FPM + extensions (ADR-001)
  # ------------------------------------------------------------------
  provisioner "shell" {
    script          = "${path.root}/provisioners/02-install-php.sh"
    execute_command = "chmod +x {{.Path}}; sudo -E bash '{{.Path}}'"
    environment_vars = [
      "PHP_VERSION=${var.php_version}",
      "BLOB_STORAGE_BASE_URL=${var.blob_storage_base_url}",
      "SMW_LOG_FILE=/var/log/smw-install.log",
    ]
  }

  # ------------------------------------------------------------------
  # 03 — Installation Apache 2.4 + configuration VirtualHost
  # ------------------------------------------------------------------
  provisioner "shell" {
    script          = "${path.root}/provisioners/03-install-apache.sh"
    execute_command = "chmod +x {{.Path}}; sudo -E bash '{{.Path}}'"
    environment_vars = [
      "PHP_VERSION=${var.php_version}",
      "SMW_LOG_FILE=/var/log/smw-install.log",
    ]
  }

  # ------------------------------------------------------------------
  # 04 — Installation MySQL 8.x (ADR-001)
  # ------------------------------------------------------------------
  provisioner "shell" {
    script          = "${path.root}/provisioners/04-install-mysql.sh"
    execute_command = "chmod +x {{.Path}}; sudo -E bash '{{.Path}}'"
    environment_vars = [
      "MYSQL_VERSION=${var.mysql_version}",
      "BLOB_STORAGE_BASE_URL=${var.blob_storage_base_url}",
      "SMW_LOG_FILE=/var/log/smw-install.log",
    ]
  }

  # ------------------------------------------------------------------
  # 05 — Installation MediaWiki 1.43.x (ADR-001)
  # ------------------------------------------------------------------
  provisioner "shell" {
    script          = "${path.root}/provisioners/05-install-mediawiki.sh"
    execute_command = "chmod +x {{.Path}}; sudo -E bash '{{.Path}}'"
    environment_vars = [
      "MEDIAWIKI_VERSION=${var.mediawiki_version}",
      "BLOB_STORAGE_BASE_URL=${var.blob_storage_base_url}",
      "SMW_LOG_FILE=/var/log/smw-install.log",
    ]
  }

  # ------------------------------------------------------------------
  # 06 — Installation Semantic MediaWiki 6.0.1 (ADR-001)
  # ------------------------------------------------------------------
  provisioner "shell" {
    script          = "${path.root}/provisioners/06-install-smw.sh"
    execute_command = "chmod +x {{.Path}}; sudo -E bash '{{.Path}}'"
    environment_vars = [
      "SMW_VERSION=${var.smw_version}",
      "MEDIAWIKI_VERSION=${var.mediawiki_version}",
      "BLOB_STORAGE_BASE_URL=${var.blob_storage_base_url}",
      "SMW_LOG_FILE=/var/log/smw-install.log",
    ]
  }

  # ------------------------------------------------------------------
  # 07 — Hardening sécurité OS (ADR-300)
  # ------------------------------------------------------------------
  provisioner "shell" {
    script          = "${path.root}/provisioners/07-security-harden.sh"
    execute_command = "chmod +x {{.Path}}; sudo -E bash '{{.Path}}'"
    environment_vars = [
      "SMW_LOG_FILE=/var/log/smw-install.log",
    ]
  }

  # ------------------------------------------------------------------
  # 08 — Nettoyage et généralisation Azure (obligatoire Marketplace)
  # DOIT être le dernier provisioner — waagent deprovision+user
  # ------------------------------------------------------------------
  provisioner "shell" {
    script          = "${path.root}/provisioners/08-cleanup-generalize.sh"
    execute_command = "chmod +x {{.Path}}; sudo -E bash '{{.Path}}'"
    environment_vars = [
      "SMW_LOG_FILE=/var/log/smw-install.log",
    ]
  }
}

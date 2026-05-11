# packer/variables.pkr.hcl
# Variables centralisées pour la construction de l'image VM SMW Marketplace
# ADR-617 — HashiCorp Packer — Outil de Construction d'Images VM Azure
# ADR-616 — Blob Storage Azure comme Cache de Packages
#
# ⚠️ Ne pas éditer les valeurs ici directement.
#    Passer par env/.env.dev (publiques) ou env/.env.dev.user (secrets).
#    Les valeurs effectives transitent via packer/generated.pkrvars.hcl (généré par make env-generate).

# ---------------------------------------------------------------------------
# Stack SMW — versions canoniques (ADR-001)
# ---------------------------------------------------------------------------

variable "smw_version" {
  type        = string
  default     = "6.0.1"
  description = "Version de Semantic MediaWiki (ex: 6.0.1)"
}

variable "mediawiki_version" {
  type        = string
  default     = "1.43.0"
  description = "Version de MediaWiki (ex: 1.43.0)"
}

variable "php_version" {
  type        = string
  default     = "8.2"
  description = "Version de PHP-FPM (ex: 8.2)"
}

variable "mysql_version" {
  type        = string
  default     = "8.0"
  description = "Version de MySQL Server (ex: 8.0)"
}

# ---------------------------------------------------------------------------
# Build — date et nommage versionné (ADR-617, US-01.5)
# ---------------------------------------------------------------------------

variable "build_date" {
  type        = string
  description = "Date de build au format YYYYMMDD (ex: 20260511) — injectée par make vm-build"
}

# ---------------------------------------------------------------------------
# Azure — infrastructure de build
# ---------------------------------------------------------------------------

variable "azure_subscription_id" {
  type        = string
  description = "Azure Subscription ID (ARM_SUBSCRIPTION_ID) — secret"
  sensitive   = true
}

variable "azure_tenant_id" {
  type        = string
  description = "Azure Tenant ID (ARM_TENANT_ID) — secret"
  sensitive   = true
}

variable "azure_client_id" {
  type        = string
  description = "Azure Service Principal Client ID (ARM_CLIENT_ID) — secret"
  sensitive   = true
}

variable "azure_client_secret" {
  type        = string
  description = "Azure Service Principal Client Secret (ARM_CLIENT_SECRET) — secret"
  sensitive   = true
}

variable "azure_location" {
  type        = string
  default     = "canadacentral"
  description = "Région Azure pour le build et la publication"
}

variable "azure_resource_group" {
  type        = string
  default     = "rg-smw-marketplace"
  description = "Resource Group Azure pour le build"
}

variable "azure_subscription_id_gallery" {
  type        = string
  default     = ""
  description = "Subscription ID de la Compute Gallery (si différente du build). Vide = même subscription."
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Compute Gallery — publication image (ADR-617, US-01.3, US-01.5)
# ---------------------------------------------------------------------------

variable "gallery_name" {
  type        = string
  default     = "galSMWMarketplace"
  description = "Nom de l'Azure Compute Gallery"
}

variable "gallery_image_name" {
  type        = string
  default     = "smw-knowledge-base"
  description = "Nom de la définition d'image dans la gallery (immutable, ADR-617)"
}

variable "gallery_resource_group" {
  type        = string
  default     = "rg-smw-marketplace"
  description = "Resource Group contenant la Compute Gallery"
}

# ---------------------------------------------------------------------------
# VM de build
# ---------------------------------------------------------------------------

variable "vm_size" {
  type        = string
  default     = "Standard_D4s_v3"
  description = "Taille de la VM temporaire de build Packer (ADR-617)"
}

variable "storage_account" {
  type        = string
  default     = "stsmwmarketplace"
  description = "Storage Account Azure pour les artefacts de build"
}

# ---------------------------------------------------------------------------
# Cache Blob Storage (ADR-616, US-01.4)
# ---------------------------------------------------------------------------

variable "blob_storage_base_url" {
  type        = string
  default     = "https://stsmwmarketplace.blob.core.windows.net/devops"
  description = "URL de base du conteneur Blob (sans slash final). Vide = pas de cache, fallback direct."
}

variable "packer_sas_token" {
  type        = string
  default     = ""
  description = "SAS Token pour accéder au cache Blob Storage (ADR-616). Vide = pas de cache, fallback direct."
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Wiki — configuration applicative
# ---------------------------------------------------------------------------

variable "wiki_port" {
  type        = string
  default     = "443"
  description = "Port HTTPS du wiki MediaWiki (ex: 443)"
}

# ---------------------------------------------------------------------------
# Azure Marketplace — publication
# ---------------------------------------------------------------------------

variable "azure_publisher_id" {
  type        = string
  default     = ""
  description = "Publisher ID Azure Marketplace (ADR-800). Vide pendant la phase de développement."
}

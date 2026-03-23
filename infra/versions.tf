# =============================================================================
# Terraform & Provider Configuration
# =============================================================================
# - azurerm ~> 3.100: Stable v3 provider
# - Backend: Azure Storage for remote state (team collaboration & state locking)
# =============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # ---------------------------------------------------------------------------
  # Remote State Backend (Azure Storage)
  # ---------------------------------------------------------------------------
  # Uncomment and configure for team use. Create the storage account first:
  #   az group create -n tfstate-rg -l japaneast
  #   az storage account create -n <unique-name> -g tfstate-rg -l japaneast --sku Standard_LRS
  #   az storage container create -n tfstate --account-name <unique-name>
  #
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "<unique-name>"
  #   container_name       = "tfstate"
  #   key                  = "webapp.tfstate"
  #   use_oidc             = true  # For GitHub Actions OIDC auth
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }

  # For GitHub Actions OIDC – set via environment variables:
  #   ARM_USE_OIDC=true
  #   ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
}

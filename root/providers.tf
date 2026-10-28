
terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-acme"
    storage_account_name = "stacmetfstate001"
    container_name       = "tfstate"
    key                  = "acme-ecommerce/westeurope/terraform.tfstate"
    # use_azuread_auth = true  # recommended for service principal auth
  }
}
provider "azurerm" {
  features {
    key_vault {
      # Prevent accidental key deletion during terraform destroy.
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    app_service {
      # Retain the App Service plan during destroy to avoid data loss warnings.
      delete_service_plan_with_app_service = false
    }
  }

  # Authentication: use environment variables or Azure CLI login.
  # ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET
  # or run: az login && az account set --subscription <id>
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}

provider "random" {}

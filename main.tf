terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.9.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "1.5.0"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.adb.id
}

###########
# Locals  #
###########
locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "AJC Data Platform"
      CostCenter  = var.environment == "prod" ? "Production" : "Development"
    },
    var.additional_tags
  )
}

###########
# Storage #
###########
resource "azurerm_resource_group" "datalake-rg" {
  name     = "${var.resource_prefix}-${var.environment}-datalake-rg"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "datalake" {
  name                     = "${var.resource_prefix}${var.environment}datalakesa"
  resource_group_name      = azurerm_resource_group.datalake-rg.name
  location                 = azurerm_resource_group.datalake-rg.location
  account_tier             = "Standard"
  account_replication_type = var.environment == "prod" ? "ZRS" : "LRS"
  is_hns_enabled           = true

  # Enable blob versioning for data protection
  blob_properties {
    versioning_enabled = true
  }

  tags = local.common_tags
}

resource "azurerm_storage_container" "albums" {
  name                 = "albums"
  storage_account_name = azurerm_storage_account.datalake.name
}

# Lifecycle management for cost optimization
resource "azurerm_storage_management_policy" "datalake_lifecycle" {
  storage_account_id = azurerm_storage_account.datalake.id

  rule {
    name    = "archive-old-data"
    enabled = true

    filters {
      prefix_match = ["albums/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = var.environment == "prod" ? 30 : 7
        tier_to_archive_after_days_since_modification_greater_than = var.environment == "prod" ? 90 : 30
      }
      snapshot {
        delete_after_days_since_creation_greater_than = var.environment == "prod" ? 90 : 30
      }
      version {
        delete_after_days_since_creation = var.environment == "prod" ? 90 : 30
      }
    }
  }
}

##############
# Databricks #
##############
resource "azurerm_resource_group" "adb-rg" {
  name     = "${var.resource_prefix}-${var.environment}-adb-rg"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_databricks_workspace" "adb" {
  name                = "${var.resource_prefix}-${var.environment}-adb"
  resource_group_name = azurerm_resource_group.adb-rg.name
  location            = azurerm_resource_group.adb-rg.location
  sku                 = var.environment == "prod" ? "premium" : "standard"
  tags                = local.common_tags
}

data "databricks_node_type" "smallest" {
  local_disk = true
  depends_on = [azurerm_databricks_workspace.adb]
}

data "databricks_spark_version" "latest_lts" {
  long_term_support = true
  depends_on        = [azurerm_databricks_workspace.adb]
}

resource "databricks_cluster" "single_node" {
  cluster_name            = "single_node"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.smallest.id
  autotermination_minutes = var.environment == "prod" ? 30 : 15
  depends_on              = [azurerm_databricks_workspace.adb]

  # Enable spot instances for non-production environments for cost savings
  azure_attributes {
    availability       = var.environment == "prod" ? "ON_DEMAND_AZURE" : "SPOT_WITH_FALLBACK_AZURE"
    first_on_demand    = var.environment == "prod" ? null : 0
    spot_bid_max_price = var.environment == "prod" ? null : -1
  }

  spark_conf = {
    # Single-node
    "spark.databricks.cluster.profile" : "singleNode"
    "spark.master" : "local[*]"
  }

  custom_tags = {
    "ResourceClass" = "SingleNode"
    "Environment"   = var.environment
  }
}

################
# Data Factory #
################
resource "azurerm_resource_group" "adf-rg" {
  name     = "${var.resource_prefix}-${var.environment}-adf-rg"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_data_factory" "adf" {
  name                = "${var.resource_prefix}-${var.environment}-adf"
  location            = azurerm_resource_group.adf-rg.location
  resource_group_name = azurerm_resource_group.adf-rg.name
  tags                = local.common_tags

  identity {
    type = "SystemAssigned"
  }

  public_network_enabled = true
}

#############
# Key Vault #
#############
resource "azurerm_resource_group" "kv-rg" {
  name     = "${var.resource_prefix}-${var.environment}-kv-rg"
  location = var.location
  tags     = local.common_tags
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "${var.resource_prefix}${var.environment}kv"
  location                    = azurerm_resource_group.kv-rg.location
  resource_group_name         = azurerm_resource_group.kv-rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = var.environment == "prod" ? 90 : 7
  purge_protection_enabled    = var.environment == "prod" ? true : false
  sku_name                    = "standard"
  tags                        = local.common_tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover"
    ]
  }

}

resource "azurerm_key_vault_secret" "storage_access_key" {
  name         = "storage-account-access-key"
  value        = azurerm_storage_account.datalake.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id
}

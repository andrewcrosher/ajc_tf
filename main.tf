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
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.adb.id
}

###########
# Storage #
###########
resource "azurerm_resource_group" "datalake-rg" {
  name     = "${var.resource_prefix}-${var.environment}-datalake-rg"
  location = var.location
}

resource "azurerm_storage_account" "datalake" {
  name                     = "${var.resource_prefix}${var.environment}datalakesa"
  resource_group_name      = azurerm_resource_group.datalake-rg.name
  location                 = azurerm_resource_group.datalake-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

resource "azurerm_storage_container" "albums" {
  name                 = "albums"
  storage_account_name = azurerm_storage_account.datalake.name
}

##############
# Databricks #
##############
resource "azurerm_resource_group" "adb-rg" {
  name     = "${var.resource_prefix}-${var.environment}-adb-rg"
  location = var.location
}

resource "azurerm_databricks_workspace" "adb" {
  name                = "${var.resource_prefix}-${var.environment}-adb"
  resource_group_name = azurerm_resource_group.adb-rg.name
  location            = azurerm_resource_group.adb-rg.location
  sku                 = "standard"
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
  autotermination_minutes = 20
  depends_on              = [azurerm_databricks_workspace.adb]
  spark_conf = {
    # Single-node
    "spark.databricks.cluster.profile" : "singleNode"
    "spark.master" : "local[*]"
  }

  custom_tags = {
    "ResourceClass" = "SingleNode"
  }
}

################
# Data Factory #
################
resource "azurerm_resource_group" "adf-rg" {
  name     = "${var.resource_prefix}-${var.environment}-adf-rg"
  location = var.location
}

resource "azurerm_data_factory" "adf" {
  name                = "${var.resource_prefix}-${var.environment}-adf"
  location            = azurerm_resource_group.adf-rg.location
  resource_group_name = azurerm_resource_group.adf-rg.name
}

#############
# Key Vault #
#############
resource "azurerm_resource_group" "kv-rg" {
  name     = "${var.resource_prefix}-${var.environment}-kv-rg"
  location = var.location
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = var.resource_prefix
  location                    = azurerm_resource_group.kv-rg.location
  resource_group_name         = azurerm_resource_group.kv-rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"

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

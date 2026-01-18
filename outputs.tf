output "tenant_id" {
  value       = data.azurerm_client_config.current.tenant_id
  description = "Azure AD tenant ID"
}

output "object_id" {
  value       = data.azurerm_client_config.current.object_id
  description = "Object ID of the signed-in principal"
}

output "storage_account_name" {
  value       = azurerm_storage_account.datalake.name
  description = "Name of the data lake storage account"
}

output "storage_account_id" {
  value       = azurerm_storage_account.datalake.id
  description = "Resource ID of the data lake storage account"
}

output "databricks_workspace_url" {
  value       = azurerm_databricks_workspace.adb.workspace_url
  description = "URL of the Databricks workspace"
}

output "databricks_workspace_id" {
  value       = azurerm_databricks_workspace.adb.id
  description = "Resource ID of the Databricks workspace"
}

output "data_factory_id" {
  value       = azurerm_data_factory.adf.id
  description = "Resource ID of the Data Factory"
}

output "data_factory_identity_principal_id" {
  value       = azurerm_data_factory.adf.identity[0].principal_id
  description = "Principal ID of the Data Factory managed identity"
}

output "key_vault_uri" {
  value       = azurerm_key_vault.kv.vault_uri
  description = "URI of the Key Vault"
}

output "key_vault_id" {
  value       = azurerm_key_vault.kv.id
  description = "Resource ID of the Key Vault"
}

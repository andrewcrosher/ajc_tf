# TFLint configuration for this repo

plugin "azurerm" {
  enabled = true
}

plugin "databricks" {
  enabled = true
}

# TFLint v0.54+: the "module" attribute was removed. No module-specific
# settings are required for this repo since no Terraform modules are used.

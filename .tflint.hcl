# TFLint configuration for this repo

plugin "azurerm" {
  enabled = true
  # Explicit source to ensure plugin resolves on CI runners
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
  version = "0.27.0"
}

plugin "databricks" {
  enabled = true
  # Explicit source to ensure plugin resolves on CI runners
  source  = "github.com/databricks/tflint-ruleset-databricks"
  version = "0.5.0"
}

# TFLint v0.54+: the "module" attribute was removed. No module-specific
# settings are required for this repo since no Terraform modules are used.

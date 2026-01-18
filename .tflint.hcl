# TFLint configuration for this repo

plugin "azurerm" {
  enabled = true
  # Explicit source to ensure plugin resolves on CI runners
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

plugin "databricks" {
  enabled = true
  # Explicit source to ensure plugin resolves on CI runners
  source  = "github.com/databricks/tflint-ruleset-databricks"
}

# TFLint v0.54+: the "module" attribute was removed. No module-specific
# settings are required for this repo since no Terraform modules are used.

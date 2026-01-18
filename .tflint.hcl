# TFLint configuration for this repo

plugin "azurerm" {
  enabled = true
}

plugin "databricks" {
  enabled = true
}

config {
  # Do not scan modules (none used here)
  module = false
}

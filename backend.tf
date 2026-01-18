terraform {
  backend "azurerm" {
    resource_group_name  = "ajc-dev-kv-rg"
    storage_account_name = "tftstaterepo42098"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.16.0"
    }
  }

  # This block defines where the tfstate will be stored. In Azure, inside a Blob
  # Backend when authenticating with Azure CLI
  backend "azurerm" {
    resource_group_name = "BU-MT"
    storage_account_name = "storageacctf"
    container_name = "storageacctf-container"
    key = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  features {} # Optional features
  subscription_id = "f89882ab-4505-45fb-b088-f9c3f90f834e"
  client_id = "efb5c55c-afbd-41cc-bbf1-8d52048360dd"
  tenant_id = "900691e1-4093-4a75-9cc7-33b19fb3bacc"
  skip_provider_registration = true # had to set it to True, as AuthorisationError occurred
}

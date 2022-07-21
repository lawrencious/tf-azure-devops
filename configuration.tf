terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.14.0"
    }
  }

  # This block defines where the tfstate will be stored. In Azure, inside a Blob
  # Backend when authenticating with Azure CLI
  backend "azurerm" {
    resource_group_name = "TF-Store-Acc-RG"
    storage_account_name = "storacctf"
    container_name = "tfstate"
    key = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  features {} # Optional features
}

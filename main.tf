provider "azurerm" {
    features {}
}

module "aks" {
  source = "./modules/AKS"
  env                 = "dev"
  region              = "eastus"
  resource_group_name = "KubeRG"
  aks_name            = "Terraformdeployk8s"
  aks_version         = "1.29.7"
  storage_account_name = "akstfazstorge"
}
provider "azurerm" {
    features { }
  }

########## Locals #############
locals {
    publisher = "MicrosoftWindowsServer"
    vmOffer = "WindowsServer"
    vmSKU = "2019-Datacenter"
    versionSKU = "latest"

    Deployment_type   =   "Terraform"
    Project_name         =   "LABTIME"
    Project_OP             =   "Onpremises"
    Project_Az             =   "Azure"    
}

locals {
    azcloud_tags = {
        Deployment    = local.Deployment_type
        Project             = local.Project_name
        Environment   =  local.Project_Az
    }
    onprem_tags = {
        Deployment    = local.Deployment_type
        Project             = local.Project_name
        Environment   =  local.Project_OP        
    }
}

#Creation of the Cloud resource group
resource "azurerm_resource_group" "azure" {
    name         =   "Cloud-rg"
    location     =   var.azloc 

    tags = local.azcloud_tags
}

# Creation of the onpremises resource group

resource "azurerm_resource_group" "onprem" {
     name         =   "Onpremises-rg"
    location     =   var.onpremloc 

    tags = local.onprem_tags
}

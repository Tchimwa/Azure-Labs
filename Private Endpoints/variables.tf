variable "azloc" {
    description  =  "Location of the resources on Azure"
    type             =  string
    default = "eastus"
}
variable "onpremloc" {
    description  =  "Location of the resources Onpremises"
    type             =  string
    default = "westus"
}
variable "username" {
    description  = "Username for all the VMs"
    type             = string
    default         = "Azure"
}
variable "password" {
    description =  "Password must meet Azure complexity requirements!"
    type            =  string
    default        =  "Networking2021#" 
}
variable "adminUsername" {
  default = "paloalto"
}
variable "adminPassword" {
  default = "Pal0Alt0@123"
}

variable "VMSize" {
    description = "Size of the VMs"
    type            =  string
    default        = "Standard_D2s_v3"
}

variable "hubvmname" {
    description = "Hub VM name"
    default = "HUB-VM01"
    type = string  
}
variable "opvmname" {
    description = "Onpremises VM name"
    default = "OP-VM01"
    type = string  
}
variable "opdnsvm" {
    description = "DNS Server name"
    default = "DNS-SRV01"
    type = string  
}
variable "hubdnsvm" {
    description = "Hub DNS Server name"
    default = "DNS-FWD01"
    type = string  
}
variable "panVMSize" {
    description = "Size of the Palo Alto VM series firewall"
    type            =  string
    default        = "Standard_DS3_v2"
}
variable "AZVnetName" {
    description = "Azure Cloud Hub Vnet name"
    default = "Azcloud-Hub"
    type = string
}
variable "AZSpokeVnetName" {
    description = "Azure Cloud Spoke Vnet name"
    default = "Azcloud-Spoke"
    type = string
}
variable "OPVnetName" {
    description = "Onpremises PAN Vnet name"
    default = "On-premises"
    type = string
}
variable "AZVnetPrefix" {
    description  =  "Address Space of the Azure VNET"
    type             =  string
    default         =  "10.10.0.0/16"
}

variable "AZSubnetPrefixes" {
    description  =  "Address Space for the AZ subnets"
    type             =  list (string)
    default         =  ["10.10.0.0/24", "10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
}

variable "AZSubnetName" {
    description  =  "Name of different subnets within the Azure VNET"
    type             =  list (string)
    default         =  [ "GatewaySubnet", "AzureBastionSubnet", "VM", "Servers"] 
}
variable "OPVnetPrefix" {
    description  =  "Address Space of the OnpremisesVNET"
    type             =  string
    default         =  "10.20.0.0/16" 
}

variable "OPSubnetPrefixes" {
    description  =  "Address Space for the Onpremises subnets"
    type             =  list (string)
    default         =  ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24", "10.20.4.0/24", "10.20.5.0/24"]
}

variable "OPSubnetName" {
    description  =  "Name of different subnets within the Onpremises VNET"
    type             =  list (string)
    default         =  [ "Mgmt", "Untrust", "Trust", "AzureBastionSubnet", "VM", "Servers"] 
}
variable "SpokeVnetPrefix" {
    description  =  "Address Space of the Spoke VNET"
    type             =  string
    default         =  "172.16.0.0/16" 
}

variable "SpokeSubnetPrefixes" {
    description  =  "Address Space for the Spoke subnets"
    type             =  list (string)
    default         =  ["172.16.0.0/24", "172.16.1.0/24"]
}

variable "SpokeSubnetName" {
    description  =  "Name of different subnets within the Spoke VNET"
    type             =  list (string)
    default         =  [ "PE", "Servers"] 
}
variable "panVMName" {
    description = "Name of the Palo Alto VM series firewall"
    default = "palovmlab01"
    type = string
}
variable "mgmtPublicIPName"{
    description = "Management Public IP Name"
    default = "mgmt-pip"
    type = string
}
variable "OutsidePublicIPName" {
    description = "Outside Public IP name"
    default = "Outside-PIP"
    type = string
}
variable "PublicIPType" {
    description = "Public IPs type"
    default = "Static"
    type = string  
}
variable "opbastionpip" {
    description = "OnPremises Bastion Public IP"
    default = "OP-Bastion-PIP"
    type = string  
}
variable "azbastionpip" {
    description = "Azure Bastion Public IP"
    default = "CL-Bastion-PIP"
    type = string  
}

variable "pip_sku" {
    description = "Public IP SKU"
    default = "Standard"
    type = string  
}
variable "bastioniptype" {
    description = "Bastion IP Type"
    default = "Dynamic"
    type = string  
}

variable "hubbastionname" {
    description = "Hub Bastion Name"
    default = "CL-Bastion"
    type = string  
}
variable "opbastionname" {
    description = "OnPremises Bastion Name"
    default = "OP-Bastion"
    type = string  
}

variable "oprtname" {
    description = "Onpremises Route table"
    default = "OP-RT"
    type = string  
}
variable "panfwstoraccnt" {
    description = "Firewall Storage Account"
    default = "panfwstoaccnt"
    type = string  
}

variable "vpngwname" {
    description = "Hub VPN Gateway"
    default = "CL-VPN-GW"
    type = string  
}

variable "oplng01" {
    description = "Local Network Gateway 1"
    default = "oplng01"
    type = string  
}

variable "oplng02" {
    description = "Local Network Gateway 2"
    default = "oplng02"
    type = string  
}

variable "vpngwpip01" {
    description = "Public IP of the first Instance"
    default = "CLVPNGW01-PIP"
    type = string     
}

variable "vpngwpip02" {
    description = "Public IP of the second Instance"
    default = "CLVPNGW02-PIP"
    type = string     
}
variable "panfwnsg" {
    description = "Default NSG attached to the FW"
    default = "pan-nsg"
    type = string  
}
variable "defaultroute" {
    description = "Outside to Internet - 0.0.0.0/0"
    default = "0.0.0.0/0"
    type = string  
}
variable "fileUris" {
    description = "Link to the custom script installing DNS role on the server DNS-SRV01"
    default = "https://raw.githubusercontent.com/Tchimwa/Azure-Labs/main/Private%20Endpoints/dnsserver.ps1"
    type = string  
}
variable "HubfileUris" {
    description = "Link to the custom script installing DNS role on DNS-FW01"
    default = "https://raw.githubusercontent.com/Tchimwa/Azure-Labs/main/Private%20Endpoints/dnsazfwd.ps1"
    type = string  
}

variable "hubconn01" {
    description = "First VPN connection to Onpremises"
    default = "Hub-to-Onpremises-01"
    type = string  
}

variable "hubconn02" {
    description = "Second VPN connection to Onpremises"
    default = "Hub-to-Onpremises-02"
    type = string  
}

variable "sqlsrvname" {
    description = "SQL Server name"
    default = "netsqlsrv"
    type = string  
}

variable "sqldbname" {
    description = "SQL Server name"
    default = "netsqldb"
    type = string  
}
############## Spoke VNET ################
resource "azurerm_virtual_network" "spoke" {

    name = var.AZSpokeVnetName
    location = var.azloc
    resource_group_name = azurerm_resource_group.azure.name
    address_space = [var.SpokeVnetPrefix ]
    
    tags = local.azcloud_tags
}

resource "azurerm_subnet" "PESubnet" {

    name = var.SpokeSubnetName[0]
    address_prefixes = [var.SpokeSubnetPrefixes[0]]
    resource_group_name = azurerm_resource_group.azure.name
    virtual_network_name = azurerm_virtual_network.spoke.name
  
}

resource "azurerm_subnet" "VMSubnet" {

    name = var.SpokeSubnetName[1]
    address_prefixes = [var.SpokeSubnetPrefixes[1]]
    resource_group_name = azurerm_resource_group.azure.name 
    virtual_network_name = azurerm_virtual_network.spoke.name
  
}

resource "azurerm_virtual_network_peering" "spoke-hub-peering" {

    name = "Spoke-to-Hub"
    resource_group_name = azurerm_resource_group.azure.name
    virtual_network_name = azurerm_virtual_network.spoke
    remote_virtual_network_id = azurerm_virtual_network.hub.id

    allow_virtual_network_access = true
    allow_gateway_transit = false
    allow_forwarded_traffic = true
    use_remote_gateways = true

    depends_on = [azurerm_virtual_network.hub, azurerm_virtual_network.spoke, azurerm_virtual_network_gateway.hub_vpngw]  
}
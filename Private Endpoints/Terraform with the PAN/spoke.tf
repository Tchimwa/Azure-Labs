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
    virtual_network_name = azurerm_virtual_network.spoke.name
    remote_virtual_network_id = azurerm_virtual_network.hub.id

    allow_virtual_network_access = true
    allow_gateway_transit = false
    allow_forwarded_traffic = true
    use_remote_gateways = true

    depends_on = [azurerm_virtual_network.hub, azurerm_virtual_network.spoke, azurerm_virtual_network_gateway.hub_vpngw]  
}

resource "azurerm_sql_server" "sql_server" {
    name = var.sqlsrvname
    resource_group_name = azurerm_resource_group.azure.name
    location = var.azloc
    version = "12.0"
    administrator_login = "azure"
    administrator_login_password = "Networking2021#"

    tags = local.azcloud_tags
  
}

resource "azurerm_sql_database" "sql_db" {
    name = var.sqldbname
    resource_group_name = azurerm_resource_group.azure.name
    location = var.azloc
    edition = "Basic"
    collation = "SQL_Latin1_General_CP1_CI_AS"
    create_mode = "Default"
    requested_service_objective_name = "Basic"

    server_name = azurerm_sql_server.sql_server.name

    tags = local.azcloud_tags
    depends_on = [
      azurerm_sql_server.sql_server,
    ]
}

resource "azurerm_sql_firewall_rule" "sqlfw_rule" {
    name                = "allow-azure-services"
    resource_group_name = azurerm_resource_group.azure.name
    server_name         = azurerm_sql_server.sql_server.name
    start_ip_address    = "0.0.0.0"
    end_ip_address      = "0.0.0.0"

    depends_on = [ azurerm_sql_database.sql_db ]
}

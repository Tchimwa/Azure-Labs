########## SQL Server and Database ###########

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

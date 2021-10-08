
################### Onpremises Vnet #################
resource "azurerm_virtual_network" "on_prem" {

    name = var.OPVnetName
    location = var.onpremloc
    resource_group_name = azurerm_resource_group.onprem.name
    address_space = [var.OPVnetPrefix]
    dns_servers = [ "10.20.5.100"]

    tags = local.onprem_tags
}
resource "azurerm_subnet" "Mgmt" {

    name = var.OPSubnetName[0]
    address_prefixes = [var.OPSubnetPrefixes[0]]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name

}

resource "azurerm_subnet_network_security_group_association" "mgmt_nsg" {
    subnet_id = azurerm_subnet.Mgmt.id
    network_security_group_id = azurerm_network_security_group.pan_fw_nsg.id  

    depends_on = [azurerm_subnet.Mgmt, azurerm_network_security_group.pan_fw_nsg]
}
resource "azurerm_subnet" "Outside" {

    name = var.OPSubnetName[1]
    address_prefixes = [var.OPSubnetPrefixes[1]]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name    
  
}

resource "azurerm_subnet_network_security_group_association" "outside_nsg" {
    subnet_id = azurerm_subnet.Outside.id
    network_security_group_id = azurerm_network_security_group.pan_fw_nsg.id  

    depends_on = [azurerm_subnet.Outside, azurerm_network_security_group.pan_fw_nsg]
}
resource "azurerm_subnet" "inside" {
  
    name = var.OPSubnetName[2]
    address_prefixes = [var.OPSubnetPrefixes[2]]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name

}

resource "azurerm_subnet_route_table_association" "inside-route" {
    subnet_id = azurerm_subnet.inside.id
    route_table_id = azurerm_route_table.onprem_route.id

    depends_on = [azurerm_subnet.inside, azurerm_route_table.onprem_route]
}
resource "azurerm_subnet" "opbastionsbnet" {

    name = var.OPSubnetName[3]
    address_prefixes = [var.OPSubnetPrefixes[3]]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name
  
}
resource "azurerm_subnet" "vm" {

    name = var.OPSubnetName[4]
    address_prefixes = [var.OPSubnetPrefixes[4]]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name

}

resource "azurerm_subnet_route_table_association" "vm-route" {
    subnet_id = azurerm_subnet.vm.id
    route_table_id = azurerm_route_table.onprem_route.id

    depends_on = [azurerm_subnet.vm, azurerm_route_table.onprem_route]
}
resource "azurerm_subnet" "servers" {

    name = var.OPSubnetName[5]
    address_prefixes = [var.OPSubnetPrefixes[5]]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name
  
}

resource "azurerm_subnet_route_table_association" "servers-route" {
    subnet_id = azurerm_subnet.servers.id
    route_table_id = azurerm_route_table.onprem_route.id

    depends_on = [azurerm_subnet.servers, azurerm_route_table.onprem_route]
}

################## VM and DNS NIC cards ##################

resource "azurerm_network_interface" "op_vm_nic" {
    name = "opvmnic01"
    resource_group_name = azurerm_resource_group.onprem.name
    location = var.onpremloc
    enable_accelerated_networking = true

    ip_configuration {
      name = "opvm-ipconfig"
      subnet_id = azurerm_subnet.vm.id
      private_ip_address_allocation = "Static"
      private_ip_address = "10.20.4.10"
    }

    depends_on = [azurerm_virtual_network.on_prem]
    tags = local.onprem_tags  
}

resource "azurerm_network_interface" "op_dns_nic" {
    name = "opdnsnic01"
    resource_group_name = azurerm_resource_group.onprem.name
    location = var.onpremloc
    enable_accelerated_networking = true

    ip_configuration {
      name = "opdns-ipconfig"
      subnet_id = azurerm_subnet.servers.id
      private_ip_address_allocation = "Static"
      private_ip_address = "10.20.5.100"
    }

    depends_on = [azurerm_virtual_network.on_prem]
    tags = local.onprem_tags  
}

############## OP Bastion ##############
resource "azurerm_public_ip" "op_bastion_pip" {
    name = var.opbastionpip
    location = var.onpremloc
    resource_group_name = azurerm_resource_group.onprem.name
    allocation_method = var.bastioniptype
    sku = var.pip_sku

    tags = local.onprem_tags
}

resource "azurerm_bastion_host" "op_bastion" {
    name = var.opbastionname
    resource_group_name = azurerm_resource_group.onprem.name
    location = var.onpremloc

    ip_configuration {
        name = "opbastion-ipconfig"
        subnet_id = azurerm_subnet.opbastionsbnet.id
        public_ip_address_id = azurerm_public_ip.op_bastion_pip.id    
    }

    tags = local.onprem_tags 
    depends_on = [azurerm_subnet.opbastionsbnet, azurerm_public_ip.op_bastion_pip] 
}

######### OP VM #############

resource "azurerm_windows_virtual_machine" "op_vm" {
    name = var.opvmname
    resource_group_name = azurerm_resource_group.onprem.name
    location = var.onpremloc
    network_interface_ids = [azurerm_network_interface.op_vm_nic.id]
    admin_username = var.username
    admin_password = var.password
    size = var.VMSize

    source_image_reference {
      publisher = local.publisher
      offer = local.vmOffer
      sku = local.vmSKU
      version = local.versionSKU
    }
    os_disk {
      storage_account_type = "Standard_LRS"
      caching = "ReadWrite"
    }

    tags = local.onprem_tags
    depends_on = [azurerm_network_interface.op_vm_nic] 
}

########### OP DNS VM ##########

resource "azurerm_windows_virtual_machine" "op_dns" {
    name = var.opdnsvm
    resource_group_name = azurerm_resource_group.onprem.name
    location = var.onpremloc
    network_interface_ids = [azurerm_network_interface.op_dns_nic.id]
    admin_username = var.username
    admin_password = var.password
    size = var.VMSize
    
    source_image_reference {
      publisher = local.publisher
      offer = local.vmOffer
      sku = local.vmSKU
      version = local.versionSKU
    }
    os_disk {
      storage_account_type = "Standard_LRS"
      caching = "ReadWrite"
      create_option = "FromImage"
    }
    tags = local.onprem_tags  
}

resource "azurerm_virtual_machine_extension" "dnsrole" {
    name = "dns-role"
    virtual_machine_id = azurerm_windows_virtual_machine.op_dns.id
    publisher = "Microsoft.Azure.Extensions"
    type = "CustomScript"
    type_handler_version = "2.1"
    auto_upgrade_minor_version = true
    settings = <<SETTINGS
        {
            "fileUris": [
                "${var.fileUris}"
                ]
        }
    SETTINGS
    protected_settings = <<PROTECTED_SETTINGS
        {
            "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file dnsserver.ps1"
        }
    PROTECTED_SETTINGS

    depends_on = [azurerm_windows_virtual_machine.op_dns]
    tags = local.onprem_tags  
}
################### Onpremises Vnet #################

resource "azurerm_virtual_network" "on_prem" {

    name = var.OPVnetName
    location = var.onpremloc
    resource_group_name = azurerm_resource_group.onprem.name
    address_space = [var.OPVnetPrefix]
    tags = local.onprem_tags
}
resource "azurerm_subnet" "Mgmt" {

    name = var.pan-sb-mgmt
    address_prefixes = [join("", list(var.OPSubnetPrefixes, "0.0/24"))]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name

}

resource "azurerm_subnet_network_security_group_association" "mgmt_nsg" {
    subnet_id = azurerm_subnet.Mgmt.id
    network_security_group_id = azurerm_network_security_group.pan_fw_nsg.id  

    depends_on = [azurerm_virtual_network.on_prem]
}
resource "azurerm_subnet" "Outside" {

    name = var.pan-sb-untrust
    address_prefixes = [join("", list(var.OPSubnetPrefixes, "1.0/24"))]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name    

    depends_on = [azurerm_virtual_network.on_prem]
}

resource "azurerm_subnet_network_security_group_association" "outside_nsg" {
    subnet_id = azurerm_subnet.Outside.id
    network_security_group_id = azurerm_network_security_group.pan_fw_nsg.id  
}
resource "azurerm_subnet" "inside" {
  
    name = var.pan-sb-trust
    address_prefixes = [join("", list(var.OPSubnetPrefixes, "2.0/24"))]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name

    depends_on = [azurerm_virtual_network.on_prem]
}

resource "azurerm_subnet_route_table_association" "inside-route" {
    subnet_id = azurerm_subnet.inside.id
    route_table_id = azurerm_route_table.onprem_route.id

    depends_on = [azurerm_virtual_network.on_prem]
}
resource "azurerm_subnet" "opbastionsbnet" {

    name = var.pan-sb-bastion
    address_prefixes = [join("", list(var.OPSubnetPrefixes, "3.0/24"))]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name

    depends_on = [azurerm_virtual_network.on_prem]  
}
resource "azurerm_subnet" "vm" {

    name = var.pan-sb-vm
    address_prefixes = [join("", list(var.OPSubnetPrefixes, "4.0/24"))]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name

    depends_on = [azurerm_virtual_network.on_prem]
}

resource "azurerm_subnet_route_table_association" "vm-route" {
    subnet_id = azurerm_subnet.vm.id
    route_table_id = azurerm_route_table.onprem_route.id
}
resource "azurerm_subnet" "servers" {

    name = var.pan-sb-servers
    address_prefixes = [join("", list(var.OPSubnetPrefixes, "5.0/24"))]
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name

    depends_on = [azurerm_virtual_network.on_prem]  
}

resource "azurerm_subnet_network_security_group_association" "servers_nsg" {
    subnet_id = azurerm_subnet.servers.id
    network_security_group_id = azurerm_network_security_group.op_dns_nsg.id    
}

resource "azurerm_subnet_route_table_association" "servers-route" {
    subnet_id = azurerm_subnet.servers.id
    route_table_id = azurerm_route_table.onprem_route.id
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

resource "azurerm_virtual_machine" "op_dns" {
    name = var.opdnsvm
    resource_group_name = azurerm_resource_group.onprem.name
    location = var.onpremloc
    network_interface_ids = [azurerm_network_interface.op_dns_nic.id]
    vm_size = var.VMSize

    storage_image_reference {
        publisher = local.publisher
        offer = local.vmOffer
        sku = local.vmSKU
        version = local.versionSKU
    }

    storage_os_disk {
        name = "dns-srv01-osdisk"
        managed_disk_type  = "Standard_LRS"
        caching = "ReadWrite"
        create_option = "FromImage"     
    }

    os_profile {
        computer_name  = "dns-srv01"
        admin_username = var.username
        admin_password = var.password
  }

    os_profile_windows_config {
        provision_vm_agent = true
  }                                                                                                                            
  
   tags = local.onprem_tags  
}

resource "azurerm_virtual_machine_extension" "dnsrole" {
    name = "dns-role"
    virtual_machine_id = azurerm_virtual_machine.op_dns.id
    publisher = "Microsoft.Compute"
    type = "CustomScriptExtension"
    type_handler_version = "1.9"
    auto_upgrade_minor_version = true

    settings = <<SETTINGS
        {
            "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted Install-WindowsFeature -Name DNS -IncludeAllSubFeature -IncludeManagementTools; Add-DnsServerForwarder -IPAddress 8.8.8.8 -PassThru; exit 0"
        }
    SETTINGS

    tags = local.onprem_tags  
}
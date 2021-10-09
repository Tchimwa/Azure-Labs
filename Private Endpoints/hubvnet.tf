####################### HUB VNET ######################
resource "azurerm_virtual_network" "hub" {

    name = var.AZVnetName
    location = var.azloc
    resource_group_name = azurerm_resource_group.azure.name
    address_space = [var.AZVnetPrefix]
    
    tags = local.azcloud_tags
}

resource "azurerm_subnet" "vpngw" {

    name = var.AZSubnetName[0]
    address_prefixes = [ var.AZSubnetPrefixes[0] ]
    resource_group_name = azurerm_resource_group.azure.name
    virtual_network_name = azurerm_virtual_network.hub.name 

}

resource "azurerm_subnet" "bastion" {

    name = var.AZSubnetName[1]
    address_prefixes = [var.AZSubnetPrefixes[1]]
    resource_group_name = azurerm_resource_group.azure.name 
    virtual_network_name = azurerm_virtual_network.hub.name
  
}

resource "azurerm_subnet" "hub_vm" {

    name = var.AZSubnetName[2]
    address_prefixes = [var.AZSubnetPrefixes[2]]
    resource_group_name = azurerm_resource_group.azure.name
    virtual_network_name = azurerm_virtual_network.hub.name
  
}

resource "azurerm_subnet" "hub_servers" {

    name = var.AZSubnetName[3]
    address_prefixes = [var.AZSubnetPrefixes[3]]
    resource_group_name = azurerm_resource_group.azure.name
    virtual_network_name = azurerm_virtual_network.hub.name
  
}

resource "azurerm_virtual_network_peering" "hub-spoke-peering" {

    name = "Hub-to-Spoke"
    resource_group_name = azurerm_resource_group.azure.name
    virtual_network_name = azurerm_virtual_network.hub.name
    remote_virtual_network_id = azurerm_virtual_network.spoke.id

    allow_forwarded_traffic = true
    allow_gateway_transit = true
    allow_virtual_network_access = true
    use_remote_gateways = false

    depends_on = [azurerm_virtual_network.hub, azurerm_virtual_network.spoke, azurerm_virtual_network_gateway.hub_vpngw]  
}

########## Hub public IPs ############

resource "azurerm_public_ip" "vpn_pip_01" {
    name = var.vpngwpip01
    location = var.azloc
    resource_group_name = azurerm_resource_group.azure.name
    allocation_method = var.PublicIPType
    
    tags = local.azcloud_tags
}

resource "azurerm_public_ip" "vpn_pip_02" {
    name = var.vpngwpip02
    location = var.azloc
    resource_group_name = azurerm_resource_group.azure.name
    allocation_method = var.PublicIPType

    tags = local.azcloud_tags
}

resource "azurerm_public_ip" "hub_bastion_pip" {
    name = var.azbastionpip
    location = var.azloc
    resource_group_name = azurerm_resource_group.azure.name
    sku = var.pip_sku
    allocation_method = var.bastioniptype

    tags = local.azcloud_tags
}

########## VPN Gateway #############

resource "azurerm_virtual_network_gateway" "hub_vpngw" {
    name = var.vpngwname
    location = var.azloc
    resource_group_name = azurerm_resource_group.azure.name
    private_ip_address_enabled = false
    active_active = true
    enable_bgp = true
    generation = "Generation1"
    sku = "VpnGw1"
    type = "Vpn"
    vpn_type = "RouteBased"
   
    ip_configuration {
      name = "hubvpngwconfig01"
      private_ip_address_allocation = "Dynamic"
      subnet_id = azurerm_subnet.vpngw.id
      public_ip_address_id = azurerm_public_ip.vpn_pip_01.id
    }

    ip_configuration {
      name = "hubvpngwconfig02"
      private_ip_address_allocation = "Dynamic"
      subnet_id = azurerm_subnet.vpngw.id
      public_ip_address_id = azurerm_public_ip.vpn_pip_02.id
    }

    depends_on = [azurerm_public_ip.vpn_pip_01, azurerm_public_ip.vpn_pip_02, azurerm_subnet.vpngw]
    tags = local.azcloud_tags
}

############## Hub Bastion Host ##################

resource "azurerm_bastion_host" "hub_bastion" {
    name = var.hubbastionname
    location = var.azloc
    resource_group_name = azurerm_resource_group.azure.name

    ip_configuration {
      name = "hubbastconfig01"
      public_ip_address_id = azurerm_public_ip.hub_bastion_pip.id
      subnet_id = azurerm_subnet.bastion.id
    }

    depends_on = [azurerm_virtual_network.hub, azurerm_public_ip.hub_bastion_pip ]
    tags =   local.azcloud_tags
}

############# Hub VM NICs ############

resource "azurerm_network_interface" "hub_vm_nic" {
    name = "hubvmnic01"
    resource_group_name = azurerm_resource_group.azure.name
    location = var.azloc
    enable_accelerated_networking = true

    ip_configuration {
      name = "hubvm-ipconfig"
      subnet_id = azurerm_subnet.hub_vm.id
      private_ip_address_allocation = "Static"
      private_ip_address = "10.10.2.10"
    }

    depends_on = [azurerm_virtual_network.hub]
    tags = local.azcloud_tags 
}

resource "azurerm_network_interface" "hub_dns_nic" {
    name = "hubdnsnic01"
    resource_group_name = azurerm_resource_group.azure.name
    location = var.azloc
    enable_accelerated_networking = true

    ip_configuration {
      name = "hubdns-ipconfig"
      subnet_id = azurerm_subnet.hub_servers.id
      private_ip_address_allocation = "Static"
      private_ip_address = "10.10.3.100"
    }

    depends_on = [azurerm_virtual_network.hub]
    tags = local.azcloud_tags  
}

############## Hub VM #############

resource "azurerm_windows_virtual_machine" "hub_vm" {
    name = var.hubvmname
    resource_group_name = azurerm_resource_group.azure.name
    location = var.azloc
    network_interface_ids = [azurerm_network_interface.hub_vm_nic.id]
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

    tags = local.azcloud_tags
    depends_on = [azurerm_network_interface.hub_vm_nic]
}

########## Hub DNS VM ############

resource "azurerm_windows_virtual_machine" "hub_dns" {
    name = var.hubdnsvm
    resource_group_name = azurerm_resource_group.azure.name
    location = var.azloc
    network_interface_ids = [azurerm_network_interface.hub_dns_nic.id]
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

    tags = local.azcloud_tags
    depends_on = [azurerm_network_interface.hub_dns_nic]
}

resource "azurerm_virtual_machine_extension" "hubdnsrole" {
    name = "hub-dns-role"    
    virtual_machine_id = azurerm_windows_virtual_machine.hub_dns.id
    publisher = "Microsoft.Azure.Extensions"
    type = "CustomScript"
    type_handler_version = "2.1"
    auto_upgrade_minor_version = true
    settings = <<SETTINGS
        {
            "fileUris": [
                "${var.HubfileUris}"
                ]
        }
    SETTINGS
    protected_settings = <<PROTECTED_SETTINGS
        {
            "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file dnsazfwd.ps1"
        }
    PROTECTED_SETTINGS

    depends_on = [azurerm_windows_virtual_machine.hub_dns]
    tags = local.azcloud_tags  
}

########### Local network Gateways for the connection #########

resource "azurerm_local_network_gateway" "lng1" {
    name = var.oplng01
    resource_group_name = azurerm_resource_group.azure.name
    location = var.azloc
    gateway_address = azurerm_public_ip.pan_out_pip.ip_address

    bgp_settings {
      asn = "65015"
      bgp_peering_address = "1.1.1.1"      
    }

    depends_on = [ azurerm_public_ip.pan_out_pip, azurerm_virtual_machine.pan_fw_vm ]
    tags = local.azcloud_tags  
}

resource "azurerm_local_network_gateway" "lng2" {
    name = var.oplng02
    resource_group_name = azurerm_resource_group.azure.name
    location = var.azloc
    gateway_address = azurerm_public_ip.pan_out_pip.ip_address

    bgp_settings {
      asn = "65015"
      bgp_peering_address = "1.1.1.1"      
    }

    depends_on = [ azurerm_public_ip.pan_out_pip, azurerm_virtual_machine.pan_fw_vm ]
    tags = local.azcloud_tags  
}

############## VPN connections ###############

resource "azurerm_virtual_network_gateway_connection" "onpremconn01" {
    name = var.hubconn01
    location = var.azloc
    resource_group_name = azurerm_resource_group.azure.name
    enable_bgp = true
    connection_protocol = "IKEv2"
    shared_key = "Networking2021#"
    type = "IPsec"


    virtual_network_gateway_id = azurerm_virtual_network_gateway.hub_vpngw.id
    local_network_gateway_id = azurerm_local_network_gateway.lng1.id

    depends_on = [ azurerm_virtual_network_gateway.hub_vpngw, azurerm_virtual_machine.pan_fw_vm, azurerm_local_network_gateway.lng1 ]
    tags = local.azcloud_tags 
}

resource "azurerm_virtual_network_gateway_connection" "onpremconn02" {
    name = var.hubconn02
    location = var.azloc
    resource_group_name = azurerm_resource_group.azure.name
    enable_bgp = true
    connection_protocol = "IKEv2"
    shared_key = "Networking2021#"
    type = "IPsec"


    virtual_network_gateway_id = azurerm_virtual_network_gateway.hub_vpngw.id
    local_network_gateway_id = azurerm_local_network_gateway.lng2.id

    depends_on = [ azurerm_virtual_network_gateway.hub_vpngw, azurerm_virtual_machine.pan_fw_vm, azurerm_local_network_gateway.lng2 ]
    tags = local.azcloud_tags 
}

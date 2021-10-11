/*
Using the AzCLI, accept the licensing terms and conditions offered prior to deployment. 
```
az vm image terms accept --urn paloaltonetworks:vmseries1:byol:latest
```
*/
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
    address_prefixes = "${var.OPSubnetPrefixes}0.0/24"
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
    address_prefixes = join("",[var.OPSubnetPrefixes, "1.0/24"])
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
    address_prefixes = "${var.OPSubnetPrefixes}2.0/24"
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
    address_prefixes = "${var.OPSubnetPrefixes}3.0/24"
    resource_group_name = azurerm_resource_group.onprem.name
    virtual_network_name = azurerm_virtual_network.on_prem.name

    depends_on = [azurerm_virtual_network.on_prem]  
}
resource "azurerm_subnet" "vm" {

    name = var.pan-sb-vm
    address_prefixes = "${var.OPSubnetPrefixes}4.0/24"
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
    address_prefixes = "${var.OPSubnetPrefixes}5.0/24"
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

############## PAN Storage Account ###############
resource "azurerm_storage_account" "palo_fw_stg" {
    name = var.panfwstoraccnt
    resource_group_name = azurerm_resource_group.onprem.name
    location = var.onpremloc
    account_replication_type = "LRS"
    account_tier = "Standard"

    tags = local.onprem_tags  
}

################## PAN Public IPs ################

resource "azurerm_public_ip" "pan_mgmt_pip" {
    name = var.mgmtPublicIPName
    location = var.onpremloc
    resource_group_name = azurerm_resource_group.onprem.name
    allocation_method = "Static"
    sku = var.pip_sku
    domain_name_label = var.panVMName

    tags = local.onprem_tags
}
resource "azurerm_public_ip" "pan_out_pip" {
    name = var.OutsidePublicIPName
    location = var.onpremloc
    resource_group_name = azurerm_resource_group.onprem.name
    allocation_method = "Static"
    sku = var.pip_sku

    tags = local.onprem_tags
}

################### NSG required for the PAN FW ###############
resource "azurerm_network_security_group" "pan_fw_nsg" {
  name                = var.panfwnsg
  location            = var.onpremloc
  resource_group_name = azurerm_resource_group.onprem.name

  security_rule {
    name                       = "Allow-Outside-From-IP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.defaultroute
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Intra"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.OPVnetPrefix
    destination_address_prefix = "*"
  }

  tags = local.onprem_tags
}

resource "azurerm_network_security_group" "op_dns_nsg" {
  name                = var.opdnsnsg
  location            = var.onpremloc
  resource_group_name = azurerm_resource_group.onprem.name

  security_rule {
    name                       = "Allow RDP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.onprem_tags
}

############### Default Route for the PAN FW ##############
/*
resource "azurerm_route_table" "pan_fw_defroute" {
    name = "pan-def-route"
    location = var.onpremloc
    resource_group_name = azurerm_resource_group.onprem.name

    route {
        name = "pan-default-route"
        address_prefix = var.defaultroute
        next_hop_type = "VirtualAppliance"
        next_hop_in_ip_address = "10.20.1.4"
    }

    tags = local.onprem_tags
}
*/
resource "azurerm_route_table" "onprem_route" {
    name = var.oprtname
    location = var.onpremloc
    resource_group_name = azurerm_resource_group.onprem.name
 
    route {
        name = "Hub-route"
        address_prefix = var.AZVnetPrefix
        next_hop_type = "VirtualAppliance"
        next_hop_in_ip_address = "10.20.2.4"
    }
    route {
        name = "Spoke-route"
        address_prefix = var.SpokeVnetPrefix
        next_hop_type = "VirtualAppliance"
        next_hop_in_ip_address = "10.20.2.4"
    }

    tags = local.onprem_tags  
}

############ Network Interfaces of the PAN FW #############

resource "azurerm_network_interface" "pan_mgmt_nic" {
    name = "panmgmtnic01"
    resource_group_name = azurerm_resource_group.onprem.name
    location = var.onpremloc
    enable_accelerated_networking = true

    ip_configuration {
      name = "mgmt-ipconfig"
      subnet_id = azurerm_subnet.Mgmt.id
      private_ip_address_allocation = "Dynamic"
      public_ip_address_id = azurerm_public_ip.pan_mgmt_pip.id
    }

        tags = local.onprem_tags  
}

resource "azurerm_network_interface" "pan_untrust_nic" {
    name = "panoutnic01"
    resource_group_name = azurerm_resource_group.onprem.name
    location = var.onpremloc
    enable_accelerated_networking = true
    enable_ip_forwarding = true

    ip_configuration {
      name = "out-ipconfig"
      subnet_id = azurerm_subnet.Outside.id
      private_ip_address_allocation = "Static"
      private_ip_address = "10.20.1.4"
      public_ip_address_id = azurerm_public_ip.pan_out_pip.id
    }

    tags = local.onprem_tags 
}

resource "azurerm_network_interface" "pan_trust_nic" {
    name = "paninnic01"
    resource_group_name = azurerm_resource_group.onprem.name
    location = var.onpremloc
    enable_accelerated_networking = true
    enable_ip_forwarding = true

    ip_configuration {
      name = "in-ipconfig"
      subnet_id = azurerm_subnet.inside.id
      private_ip_address_allocation = "Static"
      private_ip_address = "10.20.2.4"
    }

    tags = local.onprem_tags 
}

########### PAN firewall VM ###############

resource "azurerm_virtual_machine" "pan_fw_vm" {
    name = var.panVMName
    location = var.onpremloc
    resource_group_name = azurerm_resource_group.onprem.name
    vm_size = var.panVMSize
    depends_on = [azurerm_network_interface.pan_mgmt_nic, 
                            azurerm_network_interface.pan_untrust_nic, 
                            azurerm_network_interface.pan_trust_nic,
                            azurerm_storage_account.palo_fw_stg ]
                           
    plan {
        name        = "byol"
        publisher  = "paloaltonetworks"
        product     = "vmseries1"
    }

    storage_image_reference {
        publisher = "paloaltonetworks"
        offer        = "vmseries1"
        sku          = "byol"
        version    = "latest"
    }
    storage_os_disk {
      name = "panfw-osdisk"
      caching = "ReadWrite"
      create_option = "FromImage"
      vhd_uri = "${azurerm_storage_account.palo_fw_stg.primary_blob_endpoint}vhds/${var.panVMName}-vmseries-byol.vhd"
    }
    os_profile {
      computer_name = var.panVMName
      admin_username = var.adminUsername
      admin_password = var.adminPassword
    }

    primary_network_interface_id = azurerm_network_interface.pan_mgmt_nic.id
    network_interface_ids = [azurerm_network_interface.pan_mgmt_nic.id,
                                             azurerm_network_interface.pan_untrust_nic.id, 
                                             azurerm_network_interface.pan_trust_nic.id ]

    os_profile_linux_config {
      disable_password_authentication = false
    }
    
    tags = local.onprem_tags
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
}

######### OP VM #############

resource "azurerm_virtual_machine" "op_vm" {
    name = var.opvmname
    resource_group_name = azurerm_resource_group.onprem.name
    location = var.onpremloc
    network_interface_ids = [azurerm_network_interface.op_vm_nic.id]
    vm_size = var.VMSize

    storage_image_reference {
        publisher = local.publisher
        offer = local.vmOffer
        sku = local.vmSKU
        version = local.versionSKU
    }
    storage_os_disk {
        name = "dns-fwd01-osdisk"
        managed_disk_type = "Standard_LRS"
        caching = "ReadWrite"
        create_option = "FromImage" 
    }
    os_profile {
        computer_name  = "dns-fwd01"
        admin_username = var.username
        admin_password = var.password
  }
  os_profile_windows_config {
        provision_vm_agent = true
  }                                          

    tags = local.onprem_tags
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

    protected_settings = <<PROTECTED_SETTINGS
        {
            "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted Install-WindowsFeature -Name DNS -IncludeAllSubFeature -IncludeManagementTools; Add-DnsServerForwarder -IPAddress 8.8.8.8 -PassThru; exit 0"
        }
    PROTECTED_SETTINGS

    tags = local.onprem_tags  
}
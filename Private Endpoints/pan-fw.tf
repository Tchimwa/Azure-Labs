/*
Using the AzCLI, accept the licensing terms and conditions offered prior to deployment. 
```
az vm image terms accept --urn paloaltonetworks:vmseries1:byol:latest
```
*/
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
  depends_on = [azurerm_virtual_network.on_prem]
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
  depends_on = [azurerm_virtual_network.on_prem]
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

    depends_on = [azurerm_virtual_network.on_prem, azurerm_public_ip.pan_mgmt_pip]
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

    depends_on = [azurerm_virtual_network.on_prem, azurerm_public_ip.pan_out_pip]
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

    depends_on = [azurerm_virtual_network.on_prem]
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
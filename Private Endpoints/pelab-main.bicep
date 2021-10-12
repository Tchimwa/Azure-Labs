param publisher string = 'MicrosoftWindowsServer'
param vmOffer string = 'WindowsServer'
param vmSKU string = '2019-Datacenter'
param versionSKU string = 'latest'


var aztag = {
  Deployment_type:   'Terraform'
  Project:                    'LABTIME'
  Environment:             'Azure'    
}


param username string = 'Azure'
param password string = 'Networking2021#'
param VMSize string = 'Standard_D2s_v3'
param hubvmname string = 'hub-vm01'
param hubdnsvm string = 'dns-fwd01'
param hubbastionpip string = 'hub-bastion-pip'
param bastioniptype string = 'Static'
param bastionipsku string = 'Standard'
param hubbastionname string = 'CL-Bastion'
param vpngwname string = 'cl-vpn-gw'
//param oplng1 string = 'oplng01'
//param oplng2 string = 'oplng02'
param vpngwpip1 string = 'clvpngw01-pip'
param vpngwpip2 string = 'clvpngw02-pip'
param hubsrvnsg string = 'hubsrv-nsg'
//param hubconn01 string = 'hub-to-onprem-01'
//param hubconn02 string = 'hub-to-onprem-02'
param sqlsrvname string = 'netsqlsrv'
param sqldbname string = 'netsqldb'
param AzVnetName string = 'Azcloud-hub'
param AzSpokeVnetName string = 'Azcloud-Spoke'
param AzHubVnetSettings object = {
  addressPrefix: '10.10.0.0/16'
  subnets: [
    {
      name: 'GatewaySubnet'
      addressPrefix: '10.10.0.0/24'
    }
    {
      name: 'AzureBastionSubnet'
      addressPrefix: '10.0.1.0/24'
    }
    {
      name: 'hub-vm'
      addressPrefix: '10.10.2.0/24'
    }
    {
      name: 'hub-Servers'
      addressPrefix: '10.10.3.0/24'
    }
  ]
}
param AzSpokeVnetSettings object = {
  addressPrefix: '172.16.0.0/16'
  subnets: [
    {
      name: 'PE'
      addressPrefix: '172.16.0.0/24'
    }
    {
      name: 'Spoke-servers'
      addressPrefix: '172.16.1.0/24'
    }
  ]
}
param hubfileUris string = 'https://raw.githubusercontent.com/Tchimwa/Azure-Labs/main/Private%20Endpoints/dnsazfwd.ps1'


resource hub_srv_nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: hubsrvnsg
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'default-allow-3389'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}
  
resource hub_vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: AzVnetName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes:[
        AzHubVnetSettings.addressPrefix
      ]
    }
    subnets:[
      {
        name: AzHubVnetSettings.subnets[0].name
        properties:{
          addressPrefix: AzHubVnetSettings.subnets[0].addressPrefix
        }
      }
      {
        name: AzHubVnetSettings.subnets[1].name
        properties:{
          addressPrefix: AzHubVnetSettings.subnets[1].addressPrefix
        }
      }
      {
        name: AzHubVnetSettings.subnets[2].name
        properties:{
          addressPrefix: AzHubVnetSettings.subnets[2].addressPrefix
        }
      }
      {
        name: AzHubVnetSettings.subnets[3].name
        properties:{
          addressPrefix: AzHubVnetSettings.subnets[3].addressPrefix
          networkSecurityGroup: {
            id: hub_srv_nsg.id
          }
        }
      }      
    ]
  }
  tags:aztag
}

resource spoke 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: AzSpokeVnetName
  location:resourceGroup().location
  properties:{
    addressSpace:{
      addressPrefixes: [
        AzSpokeVnetSettings.addressPrefix
      ]
    }
    subnets: [
      {
        name: AzSpokeVnetSettings.subnets[0].name
        properties: {
          addressPrefix: AzSpokeVnetSettings.subnets[0].addressPrefix
        }
      }
      {
        name: AzSpokeVnetSettings.subnets[1].name
        properties: {
          addressPrefix: AzSpokeVnetSettings.subnets[1].addressPrefix
        }
      }
    ]
  }
  tags: aztag  
}

resource hub_spoke_peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: 'Hub-to-Spoke'
  parent: hub_vnet
  properties:{
    allowForwardedTraffic: true
    allowGatewayTransit: true
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    remoteVirtualNetwork:{
      id:spoke.id
    }
  }
}

resource spoke_hub_peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: 'Spoke-to-Hub'
  parent: spoke
  properties:{
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: true
    remoteVirtualNetwork:{
      id:hub_vnet.id
    }
  }
}

resource sqlserver 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: sqlsrvname
  location:resourceGroup().location
  properties:{
    administratorLogin: 'sqladmin'
    administratorLoginPassword: password
    version: '12.0'
  }
}

resource sqldb 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  name: sqldbname
  location:resourceGroup().location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties:{
    collation: 'SQL_Latin1_General_CP1_CI_AS'    
  }
}

resource hub_bastion_pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: hubbastionpip
  location:resourceGroup().location
  sku:{
    name: bastionipsku
  }
  properties:{
    publicIPAllocationMethod: bastioniptype
  }
  tags:aztag
}

resource vpngw01_pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: vpngwpip1
  location:resourceGroup().location
  sku: {
    name:'Basic'
    tier: 'Regional'
  }
  properties:{
    publicIPAllocationMethod: 'Dynamic'
  }
  tags: aztag
}

resource vpngw02_pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: vpngwpip2
  location:resourceGroup().location
  sku: {
    name:'Basic'
    tier: 'Regional'
  }
  properties:{
    publicIPAllocationMethod: 'Dynamic'
  }
  tags: aztag
}

resource hub_bastion 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: hubbastionname
  location: resourceGroup().location
  properties:{
    ipConfigurations:[
      {
        name:'hubbastipconf'
        properties:{
          publicIPAddress: {
            id:hub_bastion_pip.id
          }
          subnet: {
            id:AzHubVnetSettings.subnets[1].id
          }
        }

      }
    ]
  }
  dependsOn:[
    hub_vnet
  ]
  tags:aztag
}

resource hub_vm_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'hubvmnic01'
  location:resourceGroup().location
  properties: {
    ipConfigurations:[
      {
        name:'hubvmipconf'
        properties:{
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.10.2.10'
          subnet: {
            id: AzHubVnetSettings.subnets[2].id
          }
        }
      }
    ]
  }
  tags:aztag
}

resource hub_dns_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'hubdnsnic01'
  location:resourceGroup().location
  properties: {
    ipConfigurations:[
      {
        name:'hubdnsipconf'
        properties:{
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.10.3.100'
          subnet: {
            id: AzHubVnetSettings.subnets[3].id
          }
        }
      }
    ]
  }
  tags:aztag  
}

resource hub_vm 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: hubvmname
  location: resourceGroup().location
  properties:{
    hardwareProfile:{
      vmSize:VMSize
    }
    osProfile:{
      adminPassword: password
      adminUsername:username
      computerName:hubvmname
    }
    storageProfile: {
      imageReference:{
        publisher: publisher
        offer: vmOffer
        sku: vmSKU
        version: versionSKU
      }
      osDisk: {
        caching:'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun:0
          createOption:'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id:hub_vm_nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }          
  }
  tags: aztag
}

resource hub_dns 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: hubdnsvm
  location: resourceGroup().location
  properties:{
    hardwareProfile:{
      vmSize:VMSize
    }
    osProfile:{
      adminPassword: password
      adminUsername:username
      computerName:hubdnsvm
    }
    storageProfile: {
      imageReference:{
        publisher: publisher
        offer: vmOffer
        sku: vmSKU
        version: versionSKU
      }
      osDisk: {
        caching:'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun:0
          createOption:'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id:hub_dns_nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }          
  }
  tags: aztag
}

resource hub_dns_extension 'Microsoft.Compute/virtualMachines/extensions@2021-04-01' = {
  name: 'hub-dns-role'
  parent: hub_dns
  location: resourceGroup().location
  properties: {
    publisher : 'Microsoft.Compute'
    type : 'CustomScriptExtension'
    typeHandlerVersion : '1.9'
    autoUpgradeMinorVersion : true
    settings: {
      fileUris: [
        '${hubfileUris}'
      ]
    }
    protectedSettings: {
      'commandToExecute': 'powershell -ExecutionPolicy Unrestricted -file dnsazfwd.ps1'
    }
  }
  tags:aztag
}

resource vpngw 'Microsoft.Network/virtualNetworkGateways@2021-02-01' = {
  name: vpngwname
  location: resourceGroup().location
  properties: {
    activeActive: true
    enableBgp: true
    gatewayType: 'Vpn'
    enablePrivateIpAddress: false
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    vpnType: 'RouteBased'
    ipConfigurations: [
      {
        name:'vpngwipconfig01'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vpngw01_pip.id
          }
          subnet: {
            id: AzHubVnetSettings.subnets[0].id
          }
        }
      }
      {
        name: 'vpngwipconfig02'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id:vpngw02_pip.id
          }
          subnet: {
            id:AzHubVnetSettings.subnets[0].id
          }
        }
      }
    ]
    bgpSettings: {
      asn:65010
    }
    vpnGatewayGeneration: 'Generation1'
  }
  tags:aztag  
}

output vpngwip1 string = vpngw01_pip.properties.ipAddress
output vpngwip2 string = vpngw02_pip.properties.ipAddress

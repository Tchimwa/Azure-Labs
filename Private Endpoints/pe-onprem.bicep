param publisher string = 'MicrosoftWindowsServer'
param vmOffer string = 'WindowsServer'
param vmSKU string = '2019-Datacenter'
param versionSKU string = 'latest'


var optag = {
  Deployment_type:   'Terraform'
  Project:                    'LABTIME'
  Environment:           'On-premises'    
}

param username string = 'Azure'
param password string = 'Networking2021#'
param adminUsername string = 'paloalto'
param adminPassword string  = 'Pal0Alt0@123'
param VMSize string = 'Standard_D2s_v3'
param opvmname string = 'op-vm01'
param opdnsvm string = 'dns-srv01'
param panVMSize string = 'Standard_DS3_v2'
param panVMName string = 'palovmnetlab01'
param mgmtPublicIPName string = 'mgmt-pip'
param outPublicIPname string = 'outside-pip'
param opbastionpip string = 'op-bastion-pip'
param bastionipsku string = 'Standard'
param bastioniptype string = 'Static'
param opbastionname string = 'OP-Bastion'
param oprtname string = 'op-rt'
param panstoaccnt string = 'panfwstoaccnt'
param panfwnsg string = 'pan-nsg'
param opsrvnsg string = 'opsrv-nsg'
param dftroute string = '0.0.0.0/0'
param OPVnetName string = 'On-premises'
param AzVnetPrefix string = '10.10.0.0/16'
param SpokeVnetPrefix string = '172.16.0.0/16'
//param fileUri string = 'https://raw.githubusercontent.com/Tchimwa/Azure-Labs/main/Private%20Endpoints/dnsserver.ps1'
param OPVnetSettings object = {
  addressPrefix: '10.20.0.0/16'
  subnets: [
    {
      name: 'Mgmt'
      addressPrefix: '10.20.0.0/24'
    }
    {
      name: 'Untrust'
      addressPrefix: '10.20.1.0/24'
    }
    {
      name: 'Trust'
      addressPrefix: '10.20.2.0/24'
    }
    {
      name: 'AzureBastionSubnet'
      addressPrefix: '10.20.3.0/24'
    }
    {
      name: 'op-vm'
      addressPrefix: '10.20.4.0/24'
    }
    {
      name: 'op-Servers'
      addressPrefix: '10.20.5.0/24'
    }
  ]
}

resource pan_fw_nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: panfwnsg
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'Allow-traffic-from-Outside'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: dftroute
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Allow-traffic-from-Outside'
        properties: {
          priority: 120
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: OPVnetSettings.addressPrefix
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
  tags: optag
}

resource op_srv_nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: opsrvnsg
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
  tags: optag
}

resource op_rt 'Microsoft.Network/routeTables@2021-02-01' = {
  name: oprtname
  location: resourceGroup().location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name:'Hub-route'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: AzVnetPrefix
          nextHopIpAddress: '10.20.2.4'
        }
      }
      {
        name:'Spoke-route'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: SpokeVnetPrefix
          nextHopIpAddress: '10.20.2.4'
          }
      }
    ]
  }
  tags: optag
}

resource op_vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: OPVnetName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes:[
        OPVnetSettings.addressPrefix
      ]
    }
    subnets:[
      {
        name: OPVnetSettings.subnets[0].name
        properties:{
          addressPrefix: OPVnetSettings.subnets[0].addressPrefix
          networkSecurityGroup: {
            id:pan_fw_nsg.id
          }
        }
      }
      {
        name: OPVnetSettings.subnets[1].name
        properties:{
          addressPrefix: OPVnetSettings.subnets[1].addressPrefix
          networkSecurityGroup: {
            id: pan_fw_nsg.id
          }
        }
      }
      {
        name: OPVnetSettings.subnets[2].name
        properties:{
          addressPrefix: OPVnetSettings.subnets[2].addressPrefix
          routeTable: {
            id:op_rt.id
          }
        }
      }
      {
        name: OPVnetSettings.subnets[3].name
        properties:{
          addressPrefix: OPVnetSettings.subnets[3].addressPrefix
        }
      }
      {
        name: OPVnetSettings.subnets[4].name
        properties:{
          addressPrefix: OPVnetSettings.subnets[4].addressPrefix
          routeTable: {
            id:op_rt.id
          }
        }
      }
      {
        name: OPVnetSettings.subnets[5].name
        properties:{
          addressPrefix: OPVnetSettings.subnets[5].addressPrefix
          routeTable: {
            id: op_rt.id
          }
          networkSecurityGroup: {
            id:op_srv_nsg.id
          }
        }
      }
    ]
  }
  tags: optag
}

resource op_bastion_pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: opbastionpip
  location:resourceGroup().location
  sku:{
    name: bastionipsku
  }
  properties:{
    publicIPAllocationMethod: bastioniptype
  }
  tags: optag
}

resource mgmt_pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: mgmtPublicIPName
  location:resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties:{
    publicIPAllocationMethod: 'Static'
  }
  tags: optag
}

resource out_pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: outPublicIPname
  location:resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties:{
    publicIPAllocationMethod: 'Static'
  }
  tags: optag
}

resource op_bastion 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: opbastionname
  location: resourceGroup().location
  properties:{
    ipConfigurations:[
      {
        name:'opbastipconf'
        properties:{
          publicIPAddress: {
            id:op_bastion_pip.id
          }
          subnet: {
            id:OPVnetSettings.subnets[3].id
          }
        }

      }
    ]
  }
  dependsOn:[
    op_vnet
  ]
  tags: optag
}

resource pan_mgmt_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'panmgmtnic01'
  location:resourceGroup().location
  properties: {
    ipConfigurations:[
      {
        name:'panmgmtipconf'
        properties:{
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: mgmt_pip
          subnet: {
            id: OPVnetSettings.subnets[0].id
          }
        }
      }
    ]
  }
  tags: optag
}

resource pan_out_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'panoutnic01'
  location:resourceGroup().location
  properties: {
    ipConfigurations:[
      {
        name:'panoutipconf'
        properties:{
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: out_pip
          subnet: {
            id: OPVnetSettings.subnets[1].id
          }
        }
      }
    ]
  }
  tags: optag
}

resource pan_in_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'paninnic01'
  location:resourceGroup().location
  properties: {
    ipConfigurations:[
      {
        name:'paninipconf'
        properties:{
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.20.2.4'
          subnet: {
            id: OPVnetSettings.subnets[2].id
          }
        }
      }
    ]
  }
  tags: optag
}

resource op_vm_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'opvmnic01'
  location:resourceGroup().location
  properties: {
    ipConfigurations:[
      {
        name:'opvmipconf'
        properties:{
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.20.4.10'
          subnet: {
            id: OPVnetSettings.subnets[4].id
          }
        }
      }
    ]
  }
  tags: optag
}

resource op_dns_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'opdnsnic01'
  location:resourceGroup().location
  properties: {
    ipConfigurations:[
      {
        name:'hubdnsipconf'
        properties:{
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.20.5.100'
          subnet: {
            id: OPVnetSettings.subnets[5].id
          }
        }
      }
    ]
  }
  tags: optag
}

resource op_vm 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: opvmname
  location: resourceGroup().location
  properties:{
    hardwareProfile:{
      vmSize:VMSize
    }
    osProfile:{
      adminPassword: password
      adminUsername:username
      computerName:opvmname
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
          id:op_vm_nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }          
  }
  tags: optag
}

resource op_dns 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: opdnsvm
  location: resourceGroup().location
  properties:{
    hardwareProfile:{
      vmSize:VMSize
    }
    osProfile:{
      adminPassword: password
      adminUsername:username
      computerName:opdnsvm
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
          id: op_dns_nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }          
  }
  tags: optag
}

resource op_dns_extension 'Microsoft.Compute/virtualMachines/extensions@2021-04-01' = {
  name: 'hub-dns-role'
  parent: op_dns
  location: resourceGroup().location
  properties: {
    publisher : 'Microsoft.Compute'
    type : 'CustomScriptExtension'
    typeHandlerVersion : '1.9'
    autoUpgradeMinorVersion : true
    protectedSettings: {
      'commandToExecute': 'powershell.exe -ExecutionPolicy Unrestricted Install-WindowsFeature -Name DNS -IncludeAllSubFeature -IncludeManagementTools; Add-DnsServerForwarder -IPAddress 8.8.8.8 -PassThru; exit 0'
    }
  }
  tags: optag
}

resource pan_fw_stg 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: panstoaccnt
  location:resourceGroup().location
  kind: 'StorageV2'
  sku:{
    name: 'Standard_LRS'    
  }
  properties: {
    accessTier: 'Hot'
  }  
}

resource pan_fw 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: panVMName
  location: resourceGroup().location
  plan: {
    name: 'byol'
    publisher: 'paloaltonetworks'
    product: 'vmseries1'
  }
  properties: {    
    hardwareProfile: {
      vmSize: panVMSize      
    }
    osProfile: {
      adminPassword: adminPassword
      adminUsername: adminUsername
      computerName: panVMName
      linuxConfiguration: {
        provisionVMAgent: true
        disablePasswordAuthentication: false       
      }      
    }
    networkProfile: {      
      networkInterfaces: [
        {
          id: pan_mgmt_nic.id
          properties: {
            primary: true
          }
        }
        {
          id: pan_out_nic.id
          properties: {
            primary: false
          }
        }
        {
          id: pan_in_nic.id
          properties: {
            primary: false
          }
        }
      ]
    }
    storageProfile: {
      imageReference: {
        publisher: 'paloaltonetworks'
        offer: 'vmseries1'
        sku: 'byol'
        version: 'latest'        
      }
      osDisk: {
        osType: 'Linux'
        diskSizeGB:60
        createOption: 'FromImage'
        caching: 'ReadWrite'
        name: 'panfw-osdisk'
        vhd: {
          uri:'${pan_fw_stg.properties.primaryEndpoints.blob}vhds/${panVMName}-vmseries-byol.vhd'
        }
      }      
    }
  }
  tags: optag
  dependsOn: [
    pan_fw_stg
    op_vnet
  ]
}

output pan_mgmt_ip string = mgmt_pip.properties.ipAddress
output pan_out_ip string = out_pip.properties.ipAddress

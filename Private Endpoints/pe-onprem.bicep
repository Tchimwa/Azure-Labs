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
param VMSize string = 'Standard_D2s_v3'
param opvmname string = 'op-vm01'
param opdnsvm string = 'dns-srv01'
param csrVMSize string = 'Standard_DS3_v2'
param csrVMName string = 'csr01v-netlab'
param outPublicIPname string = 'outside-pip'
param opbastionpip string = 'op-bastion-pip'
param bastionipsku string = 'Standard'
param bastioniptype string = 'Static'
param opbastionname string = 'OP-Bastion'
param oprtname string = 'op-rt'
param csr01vnsg string = 'csr-nsg'
param opsrvnsg string = 'opsrv-nsg'
param OPVnetName string = 'On-premises'
param AzVnetPrefix string = '10.10.0.0/16'
param SpokeVnetPrefix string = '172.16.0.0/16'
param OPVnetSettings object = {
  addressPrefix: '10.20.0.0/16'
  subnets: [
    {
      name: 'Outside'
      addressPrefix: '10.20.0.0/24'
    }
    {
      name: 'DMZ'
      addressPrefix: '10.20.1.0/24'
    }
    {
      name: 'Inside'
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

resource csr01v_nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: csr01vnsg
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'Allow-traffic-from-Outside'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
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
            id:csr01v_nsg.id
          }
        }
      }
      {
        name: OPVnetSettings.subnets[1].name
        properties:{
          addressPrefix: OPVnetSettings.subnets[1].addressPrefix
          networkSecurityGroup: {
            id: csr01v_nsg.id
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
            id: op_bastion_pip.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', op_vnet.name, OPVnetSettings.subnets[3].name)
          }
        }

      }
    ]
  }
  dependsOn:[
    op_vnet
    op_bastion_pip
  ]
  tags: optag
}

resource csr_out_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'csroutnic01'
  location:resourceGroup().location
  properties: {
    ipConfigurations:[
      {
        name:'csroutipconf'
        properties:{
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress:  {
             id: out_pip.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', op_vnet.name, OPVnetSettings.subnets[0].name)
          }
        }
      }
    ]
  }
  tags: optag
  dependsOn: [
    op_vnet
  ]
}

resource csr_in_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'csrinnic01'
  location:resourceGroup().location
  properties: {
    ipConfigurations:[
      {
        name:'csrinipconf'
        properties:{
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.20.2.4'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', op_vnet.name, OPVnetSettings.subnets[2].name)
          }
        }
      }
    ]
  }
  tags: optag
  dependsOn: [
    op_vnet
  ]
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
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', op_vnet.name, OPVnetSettings.subnets[4].name)
          }
        }
      }
    ]
  }
  tags: optag
  dependsOn: [
    op_vnet
  ]
}

resource op_dns_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'opdnsnic01'
  location:resourceGroup().location
  properties: {
    ipConfigurations:[
      {
        name:'opdnsipconf'
        properties:{
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.20.5.100'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', op_vnet.name, OPVnetSettings.subnets[5].name)
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
          storageAccountType: 'Standard_LRS'
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
  dependsOn: [
    op_dns
  ]
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
          storageAccountType: 'Standard_LRS'
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

resource csr01v 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: csrVMName
  location: resourceGroup().location
  plan: {
    name: '17_3_3-byol'
    publisher: 'cisco'
    product: 'cisco-csr-1000v'
  }
  properties: {    
    hardwareProfile: {
      vmSize: csrVMSize      
    }
    osProfile: {
      adminPassword: password
      adminUsername: username
      computerName: csrVMName
      linuxConfiguration: {
        provisionVMAgent: true
        disablePasswordAuthentication: false       
      }      
    }
    networkProfile: {      
      networkInterfaces: [       
        {
          id: csr_out_nic.id
          properties: {
            primary: true
          }
        }
        {
          id: csr_in_nic.id
          properties: {
            primary: false
          }
        }
      ]
    }
    storageProfile: {
      imageReference: {
        publisher: 'cisco'
        offer: 'cisco-csr-1000v'
        sku: '17_3_3-byol'
        version: '17.3.320210317'        
      }
      osDisk: {
        osType: 'Linux'
        diskSizeGB:8
        createOption: 'FromImage'
        caching: 'ReadWrite'
        name: 'csr01v-osdisk'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }      
  }
  
  tags: optag
  dependsOn: [
    csr_out_nic
    csr_in_nic
    op_vnet
  ]
}

output csr01v_Out string = out_pip.properties.ipAddress

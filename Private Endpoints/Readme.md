# Private Endpoint with common DNS scenarios

## Introduction

With all the security breaches that keep happening around the world, we have customers looking for secure way to access their PaaS resources on Azure. Luckily we have Azure Private Link that enables you to access Azure PaaS Services (for example, Azure Storage and SQL Database) and Azure hosted customer-owned/partner services over a private endpoint in your virtual network.Private Link, when combined with either Site to Site VPN or Express Route enable the full encryption and protection of traffic flowing to and from your on-premises. A private endpoint is simply a NIC that connects you privately and securely to your PaaS resource powered by Azure Private Link.

Due to the different DNS scenarios that can be sometimes confusing for most our customers, we chose to build this lad to illustrate and clarify the DNS traffic flow of each scenario and also see the requirements needed for every one of them. We will have HUb-and-Spoke infrastructure in Azure and another VNET simulating the on-premises environment. Both environment will be connected using an Active-active BGP VPN connection with a Cisco CSR1000v being the customer VPN appliance on-premises.  From this lab, the topics listed below will  be covered and explained:

- BICEP template
- Active-Active Site-to-Site
- Azure Private Link
- Azure Private Endpoint
- Different DNS scenarios when it comes to Azure Private Endpoints:
  - Virtual network workloads without custom DNS server (Using Azure DNS)
  - Virtual network and on-premises workloads using a DNS server on Azure
  - Virtual network and on-premises workloads using a DNS server located on-premises
  - Special scenario with the P2S connection

> [!Important]
> This lab has been built and it is being use for training and learning purposes not PRODUCTION.

## Topology

Below, we have the representation of the lab we will work on:

![PE_Infrastructure_lab]()



## Requirements

1. Use the ***pe-deploy.azcli*** file to deploy the BICEP templates. Feel free to change the location or the name of the resource group as it pleases you.

2. Use the following [link](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms?view=sql-server-ver15#download-ssms) below to download and install SSMS on the hub-vm01 and op-vm01 virtual machines. <>
    You might be prompted to install NETFramework 2.0 on the server before installing SMSS, please use this [link](https://www.interserver.net/tips/kb/enable-net-framework-3-5-windows-server/#:~:text=Enable%20.NET%20Framework%203.5%20on%20Windows%20Server%201,the%20%E2%80%98Close%E2%80%99%20button%20to%20finalize%20the%20installation%20process) to complete the operation, then install SMSS.

3. From the portal, make sure to toggle to "Yes" on  "Allow Azure services and resources to access this server"

## Task 1: Set up the Active-Active BGP VPN connection between On-premises and Azure

1. Configure the connection on Azure to handle the active-active configuration

    - Set the local network gateway - Replace ***csr01v_out_pip*** by the public IP of csr01v.

    ```azurecli
    az network local-gateway create --name oplng1 --resource-group Cloud-rg --gateway-ip-address ***csr01v_out_pip*** --asn 65015 --bgp-peering-address 1.1.1.1

    ```

    - Set up the connection itself:

    ```azurecli
    az network vpn-connection create --name Hub-to-Onpremises-AA --resource-group Cloud-rg --vnet-gateway1 cl-vpn-gw --local-gateway2 oplng1 --enable-bgp --shared-key Networking2021# 

    ```

2. Configure the Cisco router csr01v

Connect to the VM using Bastion and use the credentials below:

```text
login: azure
Password: Networking2021#
```

Then, access the configuration mode with the command "***config t***" and paste the config below.

```typescript
ip route 10.20.4.0 255.255.255.0 10.20.2.1
ip route 10.20.5.0 255.255.255.0 10.20.2.1

crypto ikev2 proposal AzIkev2Proposal
 encryption aes-cbc-256
 integrity sha1
 group 2
 exit
crypto ikev2 policy AzIkev2Pol 
 match address local 10.20.0.4
 proposal AzIkev2Proposal
 exit        
crypto ikev2 keyring AzToOnPremKeyring
 peer **vpngwpip1**
  address **vpngwpip1**
  pre-shared-key Networking2021#
  exit 
 peer **vpngwpip2**
  address **vpngwpip2**
  pre-shared-key Networking2021#
  exit
 exit
crypto ikev2 profile AzIkev2Prof
 match address local 10.20.0.4
 match identity remote address **vpngwpip1** 255.255.255.255 
 match identity remote address **vpngwpip2** 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local AzToOnPremKeyring
 lifetime 28800
 dpd 10 5 on-demand
 exit
crypto ipsec transform-set Az-xformSet esp-gcm 256 
 mode tunnel
 exit
crypto ipsec profile Az-IPSec-Profile
 set transform-set Az-xformSet 
 set ikev2-profile AzIkev2Prof
 exit
interface Loopback11
 ip address 1.1.1.1 255.255.255.255
 no shut
 exit
interface Tunnel11
 ip address 11.11.11.11 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.20.0.4
 tunnel mode ipsec ipv4
 tunnel destination **vpngwpip1**
 tunnel protection ipsec profile Az-IPSec-Profile
 no shut
 exit
interface Tunnel12
 ip address 22.22.22.22 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.20.0.4
 tunnel mode ipsec ipv4
 tunnel destination **vpngwpip2**
 tunnel protection ipsec profile Az-IPSec-Profile
 no shut
 exit 
ip route 10.10.0.4 255.255.255.255 Tunnel11
ip route 10.10.0.5 255.255.255.255 Tunnel12

router bgp 65015
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 neighbor 10.10.0.4 remote-as 65010
 neighbor 10.10.0.4 ebgp-multihop 255
 neighbor 10.10.0.4 update-source Loopback11
 neighbor 10.10.0.5 remote-as 65010
 neighbor 10.10.0.5 ebgp-multihop 255
 neighbor 10.10.0.5 update-source Loopback11 
 address-family ipv4
  network 10.20.4.0 mask 255.255.255.0
  network 10.20.5.0 mask 255.255.255.0
  neighbor 10.10.0.4 activate
  neighbor 10.10.0.5 activate
  maximum-paths 2
 exit-address-family
exit
```

Use the commands below to check the status of the connection and to check the route table

```azurecli
az network vpn-connection show --name Hub-to-Onpremises-AA --resource-group Cloud-rg --query "{status: connectionStatus}"
az network vnet-gateway list-learned-routes --resource-group Cloud-rg -name cl-vpn-gw -o table
az network vnet-gateway list-advertised-routes --resource-group Cloud-rg --name cl-vpn-gw --peer 1.1.1.1 -o table
```

## Task 2: Create the Private Endpoint on the netsqlsrv database server

Before creating the private endpoint on the SQL database server, feel free to run the ***nslookup netsqlsrv.database.windows.net*** command from both ***hub-vm01*** and ***op-vm01*** to confirm that they're resolving to the public IP of the sql server as it shows below:

```typescript
PS C:\Users\Azure> nslookup netsqlsrv.database.windows.net
Server:  UnKnown
Address:  168.63.129.16

Non-authoritative answer:
Name:    cr3.eastus1-a.control.database.windows.net
Address:  40.79.153.12
Aliases:  netsqlsrv.database.windows.net
          netsqlsrv.privatelink.database.windows.net
          dataslice6.eastus.database.windows.net
          dataslice6eastus.trafficmanager.net
```

From the left panel Menu on the netsqlsrv portal, under **Security**, select **Private endpoint connections** to configure the Private Endpoint.
    - The PE will be set up on the **AzCloud-Spoke/PE** subnet
    -  Select the resource type "**Microsoft.Sql/servers**"
    - Subresource: **Sql Server (sqlServer)**
    -  Zone name: **privatelink.database.windows.net**
    - Notice also that during the creation you can already create a private DNS zone, that will work for Azure resources that uses the Azure DNS.
    - Check the PE status and sure that is "***Approved**", also check the private DNS zone and make there is a record for the sql private endpoint.

## Task 3:  Virtual network workloads without custom DNS server (Using Azure DNS)

This configuration is appropriate for virtual network workloads without a custom DNS server. In this scenario, the client queries for the private endpoint IP address to the Azure-provided DNS service 168.63.129.16. Azure DNS will be responsible for DNS resolution of the private DNS zones.

- Run the ***nslookup netsqlsrv.database.windows.net*** command from both ***hub-vm01*** and ***op-vm01***, what is the result?
- Why do we still have the public IP address even with the Private Endpoint created?
- How to resolve the issue ?

**Resolution**:  Since we are having a Hub-and-spoke topology, we should link the private DNS zone ***privatelink.database.windows.net*** to all the VNET that contain clients that need DNS resolution from the zone

## Task 4: Virtual network and on-premises workloads using a DNS server on Azure

The following scenario is for an on-premises network with virtual networks in Azure. Both networks access the private endpoint located in a Azcloud-Spoke network, and have a DNS server hosted on Azure.

- Run the ***nslookup netsqlsrv.database.windows.net*** command from both ***hub-vm01*** and ***op-vm01***, what is the result?
- Why do we still have the public IP address even with the Private Endpoint created?
- How to resolve the issue ?

**Resolution**: For workloads accessing a private endpoint from virtual and on-premises networks, use a DNS forwarder to resolve the Azure service public DNS zone deployed in Azure. This DNS forwarder is responsible for resolving all the DNS queries via a server-level forwarder to the Azure-provided DNS service 168.63.129.16.

## Task 5: Virtual network and on-premises workloads using a DNS server located on-premises

The following scenario is for an on-premises network with virtual networks in Azure. Both networks access the private endpoint located in a Azcloud-Spoke network, and only have a DNS server hosted on-premises.

- Run the ***nslookup netsqlsrv.database.windows.net*** command from both ***hub-vm01*** and ***op-vm01***, what is the result?
- Why do we still have the public IP address even with the Private Endpoint created?
- What are the missing requirements to have the result expected?
- How to resolve the issue ?

**Resolution**: The on-premises DNS solution must be configured to forward DNS traffic to Azure DNS via a conditional forwarder. The conditional forwarder references the DNS forwarder deployed in Azure.
Here, the customer will need to deploy a server-level DNS forwarder on Azure to resolve the issue and handle the conditional forwarding coming from on-premises.

## Special scenario with the P2S connection

Accessing the private endpoint via P2S requires yo to have a DNS forwarder to be able to resolve the endpoint. We all know that the common tool used to check the DNS validation is ***nslookup***. Unfortunately, when it come to DNS resolution with the P2S and the Azure client, NS LOOKUP seems not to be the right tool for the job.
In fact, Windows 10 like Windows server 2012/R2 has a feature called the Name Resolution Policy Table - [NRPT](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn593632(v=ws.11)#introduction-to-the-nrpt) and the VPN connections will add DNS information inside of NRPT.

Whenever you use NSlookup it will, by default, automatically send queries directly to the DNS servers configured on the network adapter, regardless of the NRPT. Because ***nslookup*** is not aware of NRPT and you must use PowerShell cmdlet Resolve-DNSName to validate the DNS resolution while you are on P2S.
It is an ongoing issue and it hasn't been resolved yet. However when it comes to the DNS configuration on the P2S, you can either set up the DNS servers form your VNET configuration as you see below or add the DNS entry to [Azure VPN client XML] file once downloaded from the portal.  For more information regarding adding the entry, please use the link below:
<https://docs.microsoft.com/en-us/azure/vpn-gateway/openvpn-azure-ad-client#how-do-i-add-custom-dns-servers-to-the-vpn-client>


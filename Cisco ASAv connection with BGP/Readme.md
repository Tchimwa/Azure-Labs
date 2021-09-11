# VPN connection between Azure and a Cisco ASAv with BGP

This lab puts into practice a VPN connection between Azure and a Cisco ASAv using BGP routing protocol. Azure here is represented by the virtual network called Azure, Onpremises is a representation of the remote entity. During this lab session, we will be working on the different topics below:
 - Azure Virtual Network
 - Azure VPN Gateway
 - Site-to-Site IPSec connection with BGP
 - Routing on Azure
 - The Peering connectivity
 - NAT on Azure VPN Gateway

> Note: I would like to mention that this lab is only used for testing and learning purposes.

The configurations have been done using Azure CLI for the Azure part. When it comes to the Cisco configuration, we are using the CLI and the commands are shown below.

## Topology 

We have added a Spoke VNET to experience the automatic routing update happening on the VPN Gateway.

![ASAv VPN](https://github.com/Tchimwa/Azure-Labs/blob/main/Cisco%20ASAv%20connection%20with%20BGP/ASAv%20VPN.jpg)

## Part 1. Create and configure the Azure environment

### 0. Create the resource group

The resource group below will host all the resources reprenting the Azure environment in our infrastructure.

<pre lang=" Azure-cli"> 
 az group create --name vpn-rg --location eastus
</pre>

### 1. Create and configure the Azure VNET and the NSG with a security rule allowing the traffic on the port 3389 for testing purpose

<pre lang=" Azure-cli">
az network nsg create --name vm-nsg --resource-group vpn-rg --location eastus
az network nsg rule create --name Allow-NSG --nsg-name vm-nsg --resource-group vpn-rg --access Allow --description "Allowing RDP to the VM" --priority 110 --protocol TCP --direction Inbound --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 3389

az network vnet create --resource-group vpn-rg --location eastus --name Azure --address-prefixes 192.168.0.0/16 --subnet-name Apps --subnet-prefix 192.168.1.0/24
az network vnet subnet create --resource-group vpn-rg --name GatewaySubnet --vnet-name Azure --address-prefix 192.168.0.0/24
az network vnet subnet create --resource-group vpn-rg --name Servers --vnet-name Azure --address-prefix 192.168.2.0/24 --network-security-group vm-nsg
</pre>

### 2. Create the Azure VPN Gateway that will be used for the connection with the BGP configuration

<pre lang=" Azure-cli">
az network public-ip create --resource-group vpn-rg --name vpngw-pip --allocation-method Dynamic

az network vnet-gateway create --name Azure-GW --public-ip-addresses vpngw-pip --resource-group vpn-rg --vnet Azure --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --asn 65010 --bgp-peering-address 192.168.0.254 --no-wait
</pre>

## Part 2. Create and configure the Cisco ASAv and the On-premises VNET

Here, we will be working on the onpremises entity. Most of the time, the Onpremises is the customer environment using his own VPN appliance, here a Cisco ASAv to connect to Azure.

### 0. Create the resource group for on-prem:
As we set up the Azure environment, the entire customer environment will be host under the resource group "on-prem-rg". Here, we choose "East US 2" as the customer's location.

<pre lang=" Azure-cli">
az group create --name onprem-rg --location eastus2
</pre>

### 1. Create and configure the Onpremises VNET emulating the customer's onprem network infrastructure

<pre lang=" Azure-cli">
az network nsg create --name asa-nsg --resource-group onprem-rg --location eastus2 
az network nsg rule create --name Allow-NSG --nsg-name asa-nsg --resource-group onprem-rg --access Allow --description "Allowing SSH to the VM" --priority 110 --protocol TCP --direction Inbound --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22

az network vnet create --resource-group onprem-rg --location eastus2 --name On-premises --address-prefix 172.16.0.0/16 --subnet-name Outside --subnet-prefix 172.16.0.0/24
az network vnet subnet create --resource-group onprem-rg --name Inside --vnet-name On-premises --address-prefix 172.16.1.0/24 --network-security-group asa-nsg
az network vnet subnet create --resource-group onprem-rg --name VM --vnet-name On-premises --address-prefix 172.16.2.0/24 --network-security-group asa-nsg
</pre>

### 2. Create the Cisco ASAv

#### - Get the versions of the Cisco ASAv available on Azure

<pre lang=" Azure-cli">
az vm image list --all --publisher cisco --offer cisco-asav --query "[?sku=='asav-azure-byol'].version" -o tsv
</pre>
#### - Verify the version of the cisco ASA (Optional). Here we choose to use the version 9.14 which is one of the most stable versions of the Cisco ASAv

<pre lang=" Azure-cli">
az vm image show --location eastus2 --urn cisco:cisco-asav:asav-azure-byol:9142215.0.0
</pre>
#### - Accept the licensing terms and conditions:

Before using the Cisco ASAv product from Cisco, you might have to accept the licensing terms and conditions established.

<pre lang=" Azure-cli">
az vm image terms accept --urn cisco:cisco-asav:asav-azure-byol:9142215.0.0
</pre>

#### - Creating the Cisco ASAv with only 2 interfaces for our configuration, it can have more depending on your choice of deployment.

<pre lang=" Azure-cli">
az network public-ip create --name asav-pip --resource-group onprem-rg --idle-timeout 30 --allocation-method Static

az network nic create --name asanicOut01 --resource-group onprem-rg --vnet On-premises --subnet Outside --public-ip-address asav-pip --private-ip-address 172.16.0.4 --ip-forwarding
az network nic create --name asanicIn01 --resource-group onprem-rg --vnet On-premises --subnet Inside --private-ip-address 172.16.1.4 --ip-forwarding

az vm create --resource-group onprem-rg --location eastus2 --name asav01 --size Standard_D3_v2 --nics asanicOut01 asanicIn01 --image cisco:cisco-asav:asav-azure-byol:9142215.0.0 --admin-username azure --admin-password Networking2021#
</pre>

### 3. Get the ASAv and the Azure GW public IP address, also the BGP parameters of the VPN GW

We will be using those parameters to set up the local network Gateway and also to configure the Cisco ASA onpremises

<pre lang=" Azure-cli">
az network public-ip show --resource-group onprem-rg --name asav-pip --query "{address: ipAddress}"

az network public-ip show --resource-group vpn-rg --name vpngw-pip --query "{address: ipAddress}"
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group vpn-rg
</pre>

## Part 3. Establish the IPSec VPN connection

### 0. Creating the local network gateway

<pre lang=" Azure-cli">
az network local-gateway create --gateway-ip-address ***asav-pip*** --name az-lng --resource-group vpn-rg --asn 65015 --bgp-peering-address 1.1.1.1
</pre>

### 1.  Create the connection from Azure to On-premises

#### - Create the connection using the local network gateway configuration and the VPN GW
<pre lang=" Azure-cli">
az network vpn-connection create --name Az-to-Onprem --resource-group vpn-rg --vnet-gateway1 Azure-GW --location eastus --shared-key Networking2021# --local-gateway2 az-lng --enable-bgp
</pre>
#### - Due to some reasons, we may be forced to changes the parameters of our connexion as you can see on the pic below. In this case, DH Group 2 which is send by default by Azure is getting deprecated from the future cisco ASAv versions, so we change the configuration to use the DH Group 14. 

![DH Group 14 - Custom policy](https://github.com/Tchimwa/Azure-Labs/blob/main/Cisco%20ASAv%20connection%20with%20BGP/DH%20Group%2014%20-%20Custom%20policy.jpg)

Or you can use the CLI below to adjust the policy as well:
<pre lang=" Azure-cli">
az network vpn-connection ipsec-policy add --resource-group vpn-rg --connection-name Az-to-Onprem \
    --dh-group DHGroup14 --ike-encryption AES256 --ike-integrity SHA1 --ipsec-encryption AES256 \
    --ipsec-integrity SHA256 --pfs-group None --sa-lifetime 27000 --sa-max-size 102400000
</pre>
## Part 4. Set up the Cisco ASA
SSH to ASA management address and paste in the below configuration in config mode.
<pre lang="...">
login: azure
Password: Networking2021#
</pre>
### 0.Addressing the interfaces 
<pre lang="cli">
interface GigabitEthernet0/0
 nameif Inside
 security-level 100
 no shut
 ip address 172.16.1.4 255.255.255.0
!
interface Management0/0
 no management-only
 nameif Outside
 security-level 0
 no shut
exit
</pre>
### 1. Enable IKEv2 on the outside interface and configure the IKEv2 policy
<pre lang="cli">
crypto ikev2 enable Outside
crypto ikev2 notify invalid-selectors

crypto ikev2 policy 10
 encryption aes-256 aes-192 aes
 integrity sha512 sha384 sha256 sha
 group 2 14
 prf  sha512 sha384 sha256 sha
 lifetime seconds 28800
 exit
 </pre>

### 2. Configure an IPsec Proposal and profile
<pre lang="cli">
crypto ipsec ikev2 ipsec-proposal Azure-IpSec-Proposal
 protocol esp encryption aes-256
 protocol esp integrity sha-256

crypto ipsec profile Azure-IpSec-Profile
 set ikev2 ipsec-proposal Azure-IpSec-Proposal
 set security-association lifetime kilobytes unlimited
 set security-association lifetime seconds 27000
 !
</pre>   
### 3. Configure the tunnel interfaces
<pre lang="cli">
interface Tunnel10
 nameif  Onprem-to-Az
 ip address 1.1.1.1 255.255.255.252 
 tunnel source interface Outside
 tunnel destination ***Azure-GW Public IP***
 tunnel mode ipsec ipv4
 tunnel protection ipsec profile Azure-IpSec-Profile
 no shut
!
</pre>
### 4. Configure the tunnel group
<pre lang="cli">
group-policy AzGroup internal
group-policy AzGroup attributes
 vpn-tunnel-protocol ikev2 
tunnel-group ***Azure-GW Public IP*** type ipsec-l2l
tunnel-group ***Azure-GW Public IP*** general-attributes
 default-group-policy AzGroup
tunnel-group ***Azure-GW Public IP*** ipsec-attributes
 ikev2 remote-authentication pre-shared-key Networking2021#
 ikev2 local-authentication pre-shared-key Networking2021#
no tunnel-group-map enable peer-ip
tunnel-group-map default-group ***Azure-GW Public IP***
</pre>

### 5. Configure dynamic routing with BGP
<pre lang="cli">
route Inside 172.16.2.0 255.255.255.0 172.16.1.1 1
route Onprem-to-Az 192.168.0.254 255.255.255.255 1.1.1.0 1

router bgp 65015
 bgp log-neighbor-changes
 bgp graceful-restart
 bgp router-id 1.1.1.1
 address-family ipv4 unicast
  neighbor 192.168.0.254 remote-as 65010
  neighbor 192.168.0.254 ebgp-multihop 255
  neighbor 192.168.0.254 activate
  network 172.16.2.0 mask 255.255.255.0
  no auto-summary
  no synchronization
  redistribute static
  redistribute connected
 exit-address-family
!
</pre>
## Part 5.  Create the VMs for testing 

### 0. Create Azure Hub VM

<pre lang="Azure-cli">
az network public-ip create --name azvm-pip --resource-group vpn-rg --location eastus --allocation-method Static
az network nic create --resource-group vpn-rg --name azvmnic01 --location eastus --subnet Servers --private-ip-address 192.168.2.100 --vnet-name Azure --public-ip-address azvm-pip
az vm create --name AzVM --resource-group vpn-rg --location eastus --image Win2012R2Datacenter --admin-username azure --admin-password Networking2021# --nics azvmnic01
</pre>

### 1. On-premises VMs

#### - Inside VM 
<pre lang="Azure-cli">
az network public-ip create --name insidevm-pip --resource-group onprem-rg --location eastus2 --allocation-method Static
az network nic create --resource-group onprem-rg --name insidevmnic01 --location eastus2 --subnet Inside --private-ip-address 172.16.1.100 --vnet-name On-premises --public-ip-address insidevm-pip
az vm create --name Inside-VM --resource-group onprem-rg --location eastus2 --image UbuntuLTS --admin-username azure --admin-password Networking2021# --nics insidevmnic01
</pre>

#### - Onprem-VM
<pre lang="Azure-cli">
az network public-ip create --name onpremvm-pip --resource-group onprem-rg --location eastus2 --allocation-method Static
az network nic create --resource-group onprem-rg --name onpremvmnic01 --location eastus2 --subnet VM --private-ip-address 172.16.2.100 --vnet-name On-premises --public-ip-address onpremvm-pip
az vm create --name Onprem-VM --resource-group onprem-rg --location eastus2 --image UbuntuLTS --admin-username azure --admin-password Networking2021# --nics onpremvmnic01
</pre>
### 2. Route table to direct the traffic to the ASAv
<pre lang="Azure-cli">
az network route-table create --name OnPrem-rt --resource-group onprem-rg
az network route-table route create --name Azure-rt --resource-group onprem-rg --route-table-name OnPrem-rt --address-prefix 192.168.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 172.16.1.4
az network vnet subnet update --name VM --vnet-name On-premises --resource-group onprem-rg --route-table Onprem-rt
az network vnet subnet update --name Inside --vnet-name On-premises --resource-group onprem-rg --route-table Onprem-rt
</pre>
## Part 6. Verification

### 0. From Azure 
#### - The Status of the connection
<pre lang="Azure-cli">
az network vpn-connection show --name Az-to-Onprem --resource-group vpn-rg --query "{status: connectionStatus}"
</pre>
#### - The BGP routes learned by the Azure VPN Gateway
<pre lang="Azure-cli">
az network vnet-gateway list-learned-routes -g vpn-rg -n Azure-GW -o table
</pre>
#### - The routes advertised
<pre lang="Azure-cli">
az network vnet-gateway list-advertised-routes -g vpn-rg -n Azure-GW --peer 1.1.1.1 -o table
</pre>
### 1. From the Cisco ASAv
<pre lang="Azure-cli">
show crypto ikev2 sa

show crypto ipsec sa

ping 192.168.0.254

show bgp summary

show bgp nei 192.168.0.254 routes

show route

debug icmp trace
</pre>

## Part 7. The peering 

The goal of this part is only to show you how a new route is getting added automaticatically to the VPN Gateway and propagated onpremises via BGP.

### 1. Let's create a Azure-spoke VNET and peer it to the Azure VNET
<pre lang="Azure-cli">
az network vnet create --resource-group vpn-rg --location eastus --name Azure-Spoke --address-prefixes 10.10.0.0/16 --subnet-name DevOps --subnet-prefix 10.10.0.0/24 --network-security-group vm-nsg
az network vnet subnet create --resource-group vpn-rg --name PE --vnet-name Azure-Spoke --address-prefix 10.10.1.0/24
</pre>
### 2. The peering connections

#### -  Get the ID of  both VNETs
<pre lang="Azure-cli">
SpokeId=$(az network vnet show --resource-group vpn-rg --name Azure-Spoke --query id --out tsv)
HubId=$(az network vnet show --resource-group vpn-rg --name Azure --query id --out tsv)
</pre>
#### - Set up the peerings between the Azure and the Azure-Spoke VNETs
<pre lang="Azure-cli">
az network vnet peering create --name Spoke-to-Hub --resource-group vpn-rg --vnet-name Azure-Spoke --remote-vnet $HubId --allow-vnet-access --use-remote-gateways --allow-forwarded-traffic
az network vnet peering create --name Hub-to-Spoke --resource-group vpn-rg --vnet-name Azure --remote-vnet $SpokeId --allow-forwarded-traffic --allow-vnet-access --allow-gateway-transit
</pre>
#### - Update the route table Azure-rt on the Onpremises environment
<pre lang="Azure-cli">
az network route-table route create --name Azure-Spoke-rt --resource-group onprem-rg --route-table-name Onprem-rt --address-prefix 10.10.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 172.16.1.4
az network vnet subnet update --name VM --vnet-name On-premises --resource-group onprem-rg --route-table Onprem-rt
az network vnet subnet update --name Inside --vnet-name On-premises --resource-group onprem-rg --route-table Onprem-rt
</pre>
### 3. Testing

#### - Spoke VM to test the connectivity with the Onpremises network
<pre lang="Azure-cli">
az network public-ip create --name spokevm-pip --resource-group vpn-rg --location eastus --allocation-method Static
az network nic create --resource-group vpn-rg --name spokevmnic01 --location eastus --subnet DevOps --private-ip-address 10.10.0.100 --vnet-name Azure-Spoke --public-ip-address spokevm-pip
az vm create --name Spoke-VM --resource-group vpn-rg --location eastus --image Win2012R2Datacenter --admin-username azure --admin-password Networking2021# --nics spokevmnic01
</pre>
#### - The BGP routes advertised by the Azure VPN Gateway
<pre lang="Azure-cli">
az network vnet-gateway list-advertised-routes -g vpn-rg -n Azure-GW --peer 1.1.1.1 -o table

Network         NextHop        Origin    AsPath    Weight
--------------  -------------  --------  --------  --------
192.168.0.0/16  192.168.0.254  Igp       65010     0
10.10.0.0/16    192.168.0.254  Igp       65010     0
</pre>
#### - The BGP routes learned by the Azure VPN Gateway
<pre lang="Azure-cli">
az network vnet-gateway list-learned-routes -g vpn-rg -n Azure-GW -o table

Network         Origin    SourcePeer     AsPath    Weight    NextHop
--------------  --------  -------------  --------  --------  ---------
192.168.0.0/16  Network   192.168.0.254            32768
1.1.1.1/32      Network   192.168.0.254            32768
10.10.0.0/16    Network   192.168.0.254            32768
172.16.2.0/24   EBgp      1.1.1.1        65015     32768     1.1.1.1
1.1.1.0/30      EBgp      1.1.1.1        65015     32768     1.1.1.1
172.16.0.0/24   EBgp      1.1.1.1        65015     32768     1.1.1.1
172.16.1.0/24   EBgp      1.1.1.1        65015     32768     1.1.1.1
</pre>
#### - Route Table from the Cisco ASAv
<pre lang="Azure-cli">
asav01# show route

Codes: L - local, C - connected, S - static, R - RIP, M - mobile, B - BGP
       D - EIGRP, EX - EIGRP external, O - OSPF, IA - OSPF inter area
       N1 - OSPF NSSA external type 1, N2 - OSPF NSSA external type 2
       E1 - OSPF external type 1, E2 - OSPF external type 2, V - VPN
       i - IS-IS, su - IS-IS summary, L1 - IS-IS level-1, L2 - IS-IS level-2
       ia - IS-IS inter area, * - candidate default, U - per-user static route
       o - ODR, P - periodic downloaded static route, + - replicated route
       SI - Static InterVRF
Gateway of last resort is 172.16.0.1 to network 0.0.0.0

S*       0.0.0.0 0.0.0.0 [1/0] via 172.16.0.1, Outside
C        1.1.1.0 255.255.255.252 is directly connected, Onprem-to-AZ
L        1.1.1.1 255.255.255.255 is directly connected, Onprem-to-AZ
B        10.10.0.0 255.255.0.0 [20/0] via 192.168.0.254, 01:15:33
C        172.16.0.0 255.255.255.0 is directly connected, Outside
L        172.16.0.4 255.255.255.255 is directly connected, Outside
C        172.16.1.0 255.255.255.0 is directly connected, Inside
L        172.16.1.4 255.255.255.255 is directly connected, Inside
S        172.16.2.0 255.255.255.0 [1/0] via 172.16.1.1, Inside
B        192.168.0.0 255.255.0.0 [20/0] via 192.168.0.254, 09:48:49
S        192.168.0.254 255.255.255.255 [1/0] via 1.1.1.0, Onprem-to-AZ
</pre>

## Part 8. Configure NAT on Azure VPN Gateway

NAT defines the mechanisms to translate one IP address to another in an IP packet. There are multiple scenarios for NAT:
 - Connect multiple networks with overlapping IP addresses
 - Connect from networks with private IP addresses (RFC1918) to the Internet
 - Connect IPv6 networks to IPv4 networks (NAT64)
Azure VPN Gateway NAT **ONLY** supports the first scenario to connect on-premises networks or branch offices to an Azure virtual network with overlapping IP addresses. You can read more about the topic here: https://docs.microsoft.com/en-us/azure/vpn-gateway/nat-overview#config 

Organizations commonly use private IP addresses for internal communication in their private networks.When these networks are connected using VPN over the Internet or across private WAN, the address spaces must not overlap otherwise the communication would fail. To connect two or more networks with overlapping IP addresses, NAT is deployed on the gateway devices connecting the networks.

### 0. Adding the 10.10.0.0/16 to the Onpremises VNET

In order to simulate the NAT in our lab, we'll be adding another address space 10.10.0.0/16 which is the same as the Azure-Spoke VNET on the Onpremises VNET, so we can have networks with overlapping address space and create a subnet within the newly created address space

<pre lang="Azure-cli">
az network vnet update --name On-premises --resource-group onprem-rg --address-prefixes 172.16.0.0/16 10.10.0.0/16
az network vnet subnet create --resource-group onprem-rg --name NAT-Subnet --vnet-name On-premises --address-prefix 10.10.0.0/24 --network-security-group asa-nsg --route-table Onprem-rt
</pre>

### 1. Upgrade our Azure VPN Gateway and create the NAT rules 

Since we have an Azure VPN Gateway with VpnGw1 SKU, we will have to upgrade to the VpnGw2 at least in order to use the NAT rules. NAT is supported on the the following SKUs: VpnGw2-to-5, VpnGw2AZ-to-5AZ.

Before updating the connection and update the routing on the Onpremises device, we have to create and save the NAT rules on the Azure VPN gateway.

**Important: Do not forget to enable BGP route translation since we're using BGP**

<pre lang="Azure-cli">
az network vnet-gateway update --resource-group vpn-rg --name Azure-GW --sku VpnGw2

az network vnet-gateway nat-rule add --resource-group vpn-rg --gateway-name Azure-GW --name Azure-Spoke-NAT --internal-mappings 10.10.0.0/16 --external-mappings 100.10.0.0/16 --type Static --mode EgressSnat --no-wait
az network vnet-gateway nat-rule add --resource-group vpn-rg --gateway-name Azure-GW --name OnPremises-NAT --internal-mappings 10.10.0.0/16 --external-mappings 200.10.0.0/16 --type Static --mode IngressSnat --no-wait
az network vnet-gateway update --resource-group vpn-rg --name Azure-GW --set enableBgpRouteTranslationForNat=false --no-wait
</pre>

### 2. Update the VPN connection to integrate the NAT rule and update the routing table Onpremises
#### 1. Update the VPN connection
Since the NAT rules are still Preview, the CLI commands are very limited. We'll be using PS to update the VPN connection.

```azurepowershell
$EgressRule = Get-AzVirtualNetworkGatewayNatRule -ResourceGroupName vpn-rg -Name Azure-Spoke -ParentResourceName Azure-GW
$IngressRule = Get-AzVirtualNetworkGatewayNatRule -ResourceGroupName vpn-rg -Name OnPremises-NAT -ParentResourceName Azure-GW
$AzConn = Get-AzVirtualNetworkGatewayConnection -Name Az-to-Onprem -ResourceGroupName vpn-rg
Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $AzConn -IngressNatRule $IngressRule -EgressNatRule $EgressRule
```

#### 2. Update the Onprem-rt to integrate the NAT changes

```azurecli-interactive
az network route-table route create --name Azure-Spoke-NAT --resource-group onprem-rg --route-table-name Onprem-rt --address-prefix 100.10.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 172.16.1.4
az network route-table route delete --name Azure-Spoke-rt --resource-group onprem-rg --route-table-name Onprem-rt
az network vnet subnet update --name VM --vnet-name On-premises --resource-group onprem-rg --route-table Onprem-rt
az network vnet subnet update --name Inside --vnet-name On-premises --resource-group onprem-rg --route-table Onprem-rt
az network vnet subnet update --name NAT-Subnet --vnet-name On-premises --resource-group onprem-rg --route-table Onprem-rt
```

#### 3. Update the Cisco ASA routing to integrate the address space 10.10.0.0/16

Using the config mode, we will enter the commands below to add a route to the new address space 10.10.0.0/16
<pre lang="...">
route Inside 10.10.0.0 255.255.0.0 172.16.1.1 1
router bgp 65015
 address-family ipv4 anycast
  network 10.10.0.0 mask 255.255.0.0
 exit-address-family
</pre>

As verification, we can use the same tools we used earlier to confirm the changes on the results.















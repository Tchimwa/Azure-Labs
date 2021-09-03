# Azure VPN connection with a Cisco ASAv  with BGP

This lab puts into practice a VPN connection between Azure and a Cisco ASAv with the BGP routing protocol. Azure here is represented by the virtual network called Azure, Onpremises is a representation of the remote entity.
I would like to mention that this lab is only used for testing and learning purposes.
The configurations have been done using Azure CLI for the Azure part. When it comes to the Cisco configuration, we use the CLI and the commands are shown below.

## Topology 

We have added a Spoke VNET to experience the automatic routing update happening on the VPN Gateway.

![ASAv VPN](https://github.com/Tchimwa/Azure-Labs/blob/main/Cisco%20ASAv%20connection%20with%20BGP/ASAv%20VPN.jpg)

## Part 1 - Create and configure the Azure environment

### 0. Create the resource group
The resource group below will host all the resources reprenting the Azure environment in our infrastructure.

<pre lang=" Azure-cli"> 
 az group create --name vpn-rg --location eastus
</pre>

### 1. Create and configure the Azure VNET

az network nsg create --name vm-nsg --resource-group vpn-rg --location eastus
az network nsg rule create --name Allow-NSG --nsg-name vm-nsg --resource-group vpn-rg --access Allow --description "Allow SSH to the ASA VM" --priority 110 --protocol TCP --direction Inbound --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 3389

az network vnet create --resource-group vpn-rg --location eastus --name Azure --address-prefixes 192.168.0.0/16 --subnet-name Apps --subnet-prefix 192.168.1.0/24
az network vnet subnet create --resource-group vpn-rg --name GatewaySubnet --vnet-name Azure --address-prefix 192.168.0.0/24
az network vnet subnet create --resource-group vpn-rg --name Servers --vnet-name Azure --address-prefix 192.168.2.0/24 --network-security-group vm-nsg

### 2. Create the VPN GW 

az network public-ip create --resource-group vpn-rg --name vpngw-pip --allocation-method Dynamic

az network vnet-gateway create --name Azure-GW --public-ip-addresses vpngw-pip --resource-group vpn-rg --vnet Azure --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --asn 65010 --bgp-peering-address 192.168.0.254 --no-wait

## Part 2 - Create and configure the Cisco ASA and the On-premises VNET

### 0. Create the resource group for on-prem:

az group create --name onprem-rg --location eastus2

### 1. Create and configure the Onprem VNET

az network nsg create --name asa-nsg --resource-group onprem-rg --location eastus2 
az network nsg rule create --name Allow-NSG --nsg-name asa-nsg --resource-group onprem-rg --access Allow --description "Allow RDP to the ASA VM" --priority 110 --protocol TCP --direction Inbound --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 3389

az network vnet create --resource-group onprem-rg --location eastus2 --name On-premises --address-prefix 172.16.0.0/16 --subnet-name Outside --subnet-prefix 172.16.0.0/24
az network vnet subnet create --resource-group onprem-rg --name Inside --vnet-name On-premises --address-prefix 172.16.1.0/24 --network-security-group asa-nsg
az network vnet subnet create --resource-group onprem-rg --name VM --vnet-name On-premises --address-prefix 172.16.2.0/24 --network-security-group asa-nsg

### 2. Create the Cisco ASA

#### - Grab the latest version of the Cisco ASAv

az vm image list --all --publisher cisco --offer cisco-asav --query "[?sku=='asav-azure-byol'].version" -o tsv

#### - Verify the version of the cisco ASA (Optional):

az vm image show --location eastus2 --urn cisco:cisco-asav:asav-azure-byol:9142215.0.0

#### - Accept the licensing terms and condiftions:

az vm image terms accept --urn cisco:cisco-asav:asav-azure-byol:9142215.0.0

az network public-ip create --name asav-pip --resource-group onprem-rg --idle-timeout 30 --allocation-method Static

az network nic create --name asanicOut01 --resource-group onprem-rg --vnet On-premises --subnet Outside --public-ip-address asav-pip --private-ip-address 172.16.0.4 --ip-forwarding
az network nic create --name asanicIn01 --resource-group onprem-rg --vnet On-premises --subnet Inside --private-ip-address 172.16.1.4 --ip-forwarding

az vm create --resource-group onprem-rg --location eastus2 --name asav01 --size Standard_D3_v2 --nics asanicOut01 asanicIn01--image cisco:cisco-asav:asav-azure-byol:9142215.0.0 --admin-username azure --admin-password Networking2021#

3. Obtain the ASAv public IP addresses and the BGP parameters of the VPN GW

az network public-ip show --resource-group onprem-rg --name asav-pip --query "{address: ipAddress}"

az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group vpn-rg

Part 3: Establish an active-active cross-premises connection

0. Creating the local network gateways

az network local-gateway create --gateway-ip-address ***asav-pip*** --name az-lng --resource-group vpn-rg --asn 65015 --bgp-peering-address 1.1.1.1

1.  Establish the connections from Azure to On-premises

az network vpn-connection create --name Az-to-Onprem --resource-group vpn-rg --vnet-gateway1 Azure-GW --location eastus --shared-key Networking2021# --local-gateway2 az-lng --enable-bgp

Part 4. Set up the Cisco ASA
SSH to ASA management address and paste in the below configuration in config mode.
0.  Addressing the interfaces 

interface GigabitEthernet0/0
 nameif Inside
 security-level 100
 ip address 172.16.1.4 255.255.255.0
!
interface Management0/0
 no management-only
 nameif Outside
 security-level 0
!
1. Enable IKEv2 on the outside interface and configure the IKEv2 policy

crypto ikev2 enable Outside
crypto ikev2 notify invalid-selectors

crypto ikev2 policy 10
 encryption aes-256 aes-192 aes
 integrity sha512 sha 384 sha256 sha
 group 2 14
 prf  sha512 sha384 sha256 sha
 lifetime seconds 28800

2. Configure an IPsec transform set and an IPsec profile

crypto ipsec ikev2 ipsec-proposal Azure-IpSec-Proposal
 protocol esp encryption aes-256
 protocol esp integrity sha-256

crypto ipsec profile Azure-IpSec-Profile
 set ikev2 ipsec-proposal Azure-IpSec-Proposal
 set security-association lifetime kilobytes unlimited
 set security-association lifetime seconds 27000
   
3. Configure the tunnel interfaces

interface Tunnel10
 nameif  Omprem-to-Az
 ip address 1.1.1.1 255.255.255.252 
 tunnel source interface Management ( Here it is the default interface to Internet)
 tunnel destination ***Azure-GW Public IP***
 tunnel mode ipsec ipv4
 tunnel protection ipsec profile Azure-IpSec-Profile
 no shut
!
4. Configure the tunnel group

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


5. Configure dynamic routing

route Inside 172.16.2.0 255.255.255.0 172.16.1.1 1
route Onprem-to-AZ 192.168.0.254 255.255.255.255 1.1.1.0 1

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
  redistribute connected
 exit-address-family
!
Part 5.  Create the VM for testing 
0. Azure VM

az network public-ip create --name azvm-pip --resource-group vpn-rg --location eastus --allocation-method Dynamic
az network nic create --resource-group vpn-rg --name azvmnic01 --location eastus --subnet Servers --private-ip-address 192.168.2.100 --vnet-name Azure --public-ip-address azvm-pip
az vm create --name AzVM --resource-group vpn-rg --location eastus --image Win2012R2Datacenter --admin-username azure --admin-password Networking2021# --nics azvmnic01

1. On-premises VM

az network public-ip create --name insidevm-pip --resource-group onprem-rg --location eastus2 --allocation-method Dynamic
az network nic create --resource-group onprem-rg --name insidevmnic01 --location eastus2 --subnet Inside --private-ip-address 172.16.1.100 --vnet-name On-premises --public-ip-address insidevm-pip
az vm create --name Inside-VM --resource-group onprem-rg --location eastus2 --image Win2012R2Datacenter --admin-username azure --admin-password Networking2021# --nics insidevmnic01

az network public-ip create --name onpremvm-pip --resource-group onprem-rg --location eastus2 --allocation-method Dynamic
az network nic create --resource-group onprem-rg --name onpremvmnic01 --location eastus2 --subnet VM --private-ip-address 172.16.2.100 --vnet-name On-premises --public-ip-address onpremvm-pip
az vm create --name Onprem-VM --resource-group onprem-rg --location eastus2 --image Win2012R2Datacenter --admin-username azure --admin-password Networking2021# --nics onpremvmnic01

2. Route table to direct the traffic to the ASAv

az network route-table create --name OnPrem-rt --resource-group onprem-rg
az network route-table route create --name Onprem-rt --resource-group onprem-rg --route-table-name Azure-rt --address-prefix 192.16.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 172.16.1.4
az network vnet subnet update --name VM --vnet-name On-premises --resource-group onprem-rg --route-table Onprem-rt
az network vnet subnet update --name Inside --vnet-name On-premises --resource-group onprem-rg --route-table Onprem-rt

Part.6 Verification

0. On Azure 

az network vpn-connection show --name Az-to-Onprem --resource-group vpn-rg --query "{status: connectionStatus}"

- The BGP routes learned

 az network vnet-gateway list-learned-routes -g vpn-rg -n Azure-GW -o table

 - The routes advertised

 az network vnet-gateway list-advertised-routes -g vpn-rg -n Azure-GW --peer 1.1.1.1 -o table

1. From the Cisco ASA

show crypto ikev2 sa

show crypto ipsec sa

ping 192.168.0.254

show bgp summary

show bgp nei 192.168.0.254 routes

show route

debug icmp trace

***Peering***

1. Let's create a Azure-spoke VNET and peer it to the Azure VNET

az network vnet create --resource-group vpn-rg --location eastus --name Azure-Spoke --address-prefixes 10.10.0.0/16 --subnet-name DevOps --subnet-prefix 10.10.0.0/24 --network-security-group vm-nsg
az network vnet subnet create --resource-group vpn-rg --name PE --vnet-name Azure-Spoke --address-prefix 10.10.1.0/24

2. The peerings

-  Get the ID of  both VNETs

SpokeId=$(az network vnet show --resource-group vpn-rg --name Azure-Spoke --query id --out tsv)
HubId=$(az network vnet show --resource-group vpn-rg --name Azure --query id --out tsv)

- Set up the peerings

az network vnet peering create --name Spoke-to-Hub --resource-group vpn-rg --vnet-name Azure-Spoke --remote-vnet $HubId --allow-vnet-access --use-remote-gateways --allow-forwarded-traffic
az network vnet peering create --name Hub-to-Spoke --resource-group vpn-rg --vnet-name Azure --remote-vnet #SpokeId --allow-forwarded-traffic --allow-vnet-access --allow-gateway-transit

- Update the route table

az network route-table route create --name Azure-Spoke-rt --resource-group onprem-rg --route-table-name Azure-rt --address-prefix 10.10.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 172.16.1.4
az network vnet subnet update --name VM --vnet-name On-premises --resource-group onprem-rg --route-table Azure-rt
az network vnet subnet update --name Inside --vnet-name On-premises --resource-group onprem-rg --route-table Azure-rt

3. Testing

- Spoke VM

az network public-ip create --name spokevm-pip --resource-group vpn-rg --location eastus --allocation-method Dynamic
az network nic create --resource-group vpn-rg --name spokevmnic01 --location eastus --subnet DevOps --private-ip-address 10.10.0.100 --vnet-name Azure-Spoke --public-ip-address spokevm-pip
az vm create --name Spoke-VM --resource-group vpn-rg --location eastus --image Win2012R2Datacenter --admin-username azure --admin-password Networking2021# --nics spokevmnic01

- az network vnet-gateway list-advertised-routes -g vpn-rg -n Azure-GW --peer 1.1.1.1 -o table
Network         NextHop        Origin    AsPath    Weight
--------------  -------------  --------  --------  --------
192.168.0.0/16  192.168.0.254  Igp       65010     0
10.10.0.0/16    192.168.0.254  Igp       65010     0

- az network vnet-gateway list-learned-routes -g vpn-rg -n Azure-GW -o table
Network         Origin    SourcePeer     AsPath    Weight    NextHop
--------------  --------  -------------  --------  --------  ---------
192.168.0.0/16  Network   192.168.0.254            32768
1.1.1.1/32      Network   192.168.0.254            32768
10.10.0.0/16    Network   192.168.0.254            32768
172.16.2.0/24   EBgp      1.1.1.1        65015     32768     1.1.1.1
1.1.1.0/30      EBgp      1.1.1.1        65015     32768     1.1.1.1
172.16.0.0/24   EBgp      1.1.1.1        65015     32768     1.1.1.1
172.16.1.0/24   EBgp      1.1.1.1        65015     32768     1.1.1.1

- asav01# show route

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

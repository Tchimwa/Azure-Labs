# Redundancy and Path control with BGP

With the advent of the cloud, we've been finding more enterprises with virtual private connections from their on-premises infrastructure to their cloud environment. To minimize or avoid the downtime which can result to lost revenue and probably lost of customers, most of the enterprises find important and critical to have a redundant connectivity to their cloud environment. Despite the fact that it can be costly and complex, redundancy will be essential to keep the connectivity always UP. When it comes to path control, depending on the applications ran in their network and for less latency and better efficiency, some companies choose to have different paths for each type of traffic.

In this lab, we will have 4 VNETs: one simulating the customer's environment on-premises, a Hub and spoke VNETs on one region, and another one as a branch VNET on a different region. The Hub and  Spoke Vnets will be peered together with a VPN Gateway on the Hub Vnet. The Hub and the Branch will be connected using a Vnet-to-Vnet connection with BGP and  the On-premises Vnet will be connected to the Hub and the Branch Vnets using a Site-to-site VPN connection with BGP as well. We'll see how the redundancy has been implemented to access each of the regions, and a case scenario of path control based on the customer's requirements.

## Prerequisites

Having an Azure subscription, and understand BGP and its different attributes.

> [Important]
> This lab has been built and it is being used for training and learning purposes not PRODUCTION.

## Lab Infrastructure

Below is the lab infrastructure we will be working with. Please use the file **deploy.azcli** to deploy the environment.

![Infrastructure_lab](https://github.com/Tchimwa/Azure-Labs/blob/main/BGP%20Redundancy/images/BGP%20Redundancy.png)

## Redundancy

Below we will study and see the redundancy implemented on each region using BGP. There are always 2 ways to access each region from any of them. In case of a network failure, the traffic will flow from the first to the redundant or backup path to avoid downtime.

### From On-premises to both regions

From the routing table, we can clearly see the best route to each region as it is shown below.

![show_ip_route](https://github.com/Tchimwa/Azure-Labs/blob/main/BGP%20Redundancy/images/show_ip_route.png)

However, from the BGP topology table, we can actually see that both regions have at least 2 ways that the router can use to reach out to them. This is idolizing the redundancy. If the best route failed, the second route despite the fact that it goes through another region will be available for use.

![show_ip_bgp_topology](https://github.com/Tchimwa/Azure-Labs/blob/main/BGP%20Redundancy/images/show_ip_bgp_topo.png)

- In *Yellow*, we have the best route actually used the router csr01v and written in the routing table  
- In *Green*, we have the redundant path which is the back up route. from what we can see it goes through 2 different AS when the best route is just one AS away.

### From the Hub to the Branch and On-premises

From the table of the routes learned below, we can clearly see that the Hub-GW  has 2 path to access the other regions which are the Branch region and the On-premises network.
The best path is just an AS away from Hub-GW (in *Green*), and the backup path is 2 AS away from Hub-GW (in *Yellow*)

```typescript
az network vnet-gateway list-learned-routes -g azure-rg -n Hub-GW -o table
```

![Hub_learned_routes](https://github.com/Tchimwa/Azure-Labs/blob/main/BGP%20Redundancy/images/Hub_learned_routes.png)

- In *Green*, it is the best path
- In *Yellow* the backup route

### From the Branch to the Hub and On-premises

Same as the Hub-GW earlier, but here we have an additional route due to the Spoke Vnet (100.0.0.0/16 ) peered to the Hub Vnet.

```typescript
az network vnet-gateway list-learned-routes -g azure-rg -n Branch-GW -o table
```

![Branch_learned_routes](https://github.com/Tchimwa/Azure-Labs/blob/main/BGP%20Redundancy/images/Branch_learned_routes.png)

- In *Green*, it is the best path
- In *Yellow* the backup route

### Redundancy Test

Since the VPN connection from on-premises to the Hub is using the Tunnel 1 as we can see on the pic below, let's simulate a network failure by shutting down the Tunnel1.

![Redundancy_test](https://github.com/Tchimwa/Azure-Labs/blob/main/BGP%20Redundancy/images/Redundancy_test.png)

The backup path will become active, and we'll notice that the next hop has changed from 172.16.0.254 (Hub-GW BGP peer IP) to be the BGP peer address of the Branch-GW which is 10.10.0.254.

![Redundancy_result](https://github.com/Tchimwa/Azure-Labs/blob/main/BGP%20Redundancy/images/Redundancy_result.png)

## Path Control with BGP

We can't just start talking about Path control with BGP without brushing up the main BGP attributes used to implement the Path control. In fact, BGP used the path attributes below to implement the best path selection

Reference: <https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html>

### Weight

**Description:** Administrative Weight, Cisco Proprietary, Optional, non-transitive so only valid locally (intra-AS),
Default value for routes learned through BGP is 0, 32768 if the route was advertised locally
**Preference:** Highest

### Local Preference

**Description:** Well-known Discretionary so it is recognized, and might or might not be included in BGP Update, non-transitive
Default value is 100
**Preference:** Highest

### Locally Originated

**Description:** Optional, non-transitive
**Preference:** Prefer self-originated prefix (with next hop 0.0.0.0 ) over same prefix we learn from neighbor

### AS_PATH

**Description:** Well-known, Mandatory so it has to be included in the BGP update, transitive ( inter-AS)
Can do inbound or outbound for all Well-known, Mandatory attributes
**Preference:** Prefer shortest path

### Origin

**Description:** Well-known, Mandatory so it has to be included in the BGP update, transitive ( inter-AS)
**Preference:** Lowest (IGP) -  IGP (i) is better Redistributed/incomplete(?)
IGP(i):  Prefixes learned internally through the AS by iBGP or added using the network command

### MED

**Description:** Optional, non-transitive
Attribute exchanged between eBGP Peers to inform the external peers of the entry point of the AS
Default value is 0
**Preference:** Lowest

### BGP AD - Path Type

**Description:**Path type, Optional
**Preference:**eBGP is preferred over iBGP

### Router-ID

**Description:** BGP uses router-id to identify its peers
**Preference:** Path with lowest router-id is preferred

### Case scenario

The customer just acquires a company named WVD that has a Vnet in the *Central US* region and he created a Vnet-to-Vnet BGP connection with the Branch Vnet for personal reasons. Since the bandwidth between the On-premises and the Branch Vnet is not enough to handle the traffic to the new Vnet WVD, he would like the traffic from On-premises to the new Vnet WVD to go through the Hub.

#### Requirements

- New Vnet named WVD peered to the Branch Vnet
- Traffic to WVD: On-premises - Hub - Branch - WVD

#### New Infrastructure with the traffic paths desired by the customer

- In *Red*, Traffic to WVD

![BGP_Redundancy _Scenario](https://github.com/Tchimwa/Azure-Labs/blob/main/BGP%20Redundancy/images/BGP%20Redundancy_Scenario.png)

#### WVD creation and peering connection with Branch

```typescript
az network vnet create --resource-group azure-rg --location centralus --name WVD  --address-prefixes 200.0.0.0/16 --subnet-name GatewaySubnet --subnet-prefix 200.0.0.0/24
az network vnet subnet create --resource-group azure-rg --name Servers --vnet-name WVD  --address-prefix 200.0.1.0/24
az network vnet subnet create --resource-group azure-rg --name Dev --vnet-name WVD  --address-prefix 200.0.2.0/24

az network public-ip create --resource-group azure-rg --location centralus --name wvdgw-pip --allocation-method Dynamic
az network vnet-gateway create --name WVD-GW --location centralus --public-ip-addresses wvdgw-pip --resource-group azure-rg --vnet WVD --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --asn 65030 --bgp-peering-address 200.0.0.254

$WVDId = az network vnet-gateway show --resource-group azure-rg --name WVD-GW --query id --out tsv
$BranchId = az network vnet-gateway show --resource-group azure-rg --name Branch-GW --query id --out tsv

az network vpn-connection create --name Branch-to-WVD --vnet-gateway1 $BranchId --vnet-gateway2 $WVDId  --location southcentralus --enable-bgp  --resource-group azure-rg --shared-key Networking2021# 
az network vpn-connection create --name WVD-to-Branch --vnet-gateway1 $WVDId --vnet-gateway2 $BranchId  --location centralus  --enable-bgp  --resource-group azure-rg --shared-key Networking2021# 
```

#### Path control for the traffic to WVD

The path control will be implemented on the Cisco router csr01v hosted on-premises for both traffic path, for demonstration we will be using different BDP attributes to accomplish it.

From csr01v, we can see that the route to join 200.0.0.0/16  is currently through Branch-GW which has 10.10.0.254 as peer address. Based on AS_PATH, the router actually chooses that path because it has the shortest path to get to WVD, it is only an AS (65020) away from the destination.

![WVD_Current_Route](https://github.com/Tchimwa/Azure-Labs/blob/main/BGP%20Redundancy/images/WVD_Current_Route.png)

To complete the requirement of the customer, we will use the BGP attribute "AS_Path". We'll be using the path prepend to affect the routing. It consists of increasing the length of a path to make it less preferable for best route. Access-list" and "route-map" to only affect the route to 200.0.0.0.

- Commands

```typescript
csr01v(config)#access-list 1 permit 200.0.0.0 0.0.255.255
csr01v(config)#route-map WVD_Prepend permit 10
csr01v(config-route-map)#match ip address 1
csr01v(config-route-map)#set as-path prepend last-as 5                                                                                                                                      
csr01v(config-route-map)#route-map WVD_Prepend permit 5000                                                                                                                                                                            
csr01v(config-route-map)#router bgp 65015
csr01v(config-router)#neighbor 10.10.0.254 route-map WVD_Prepend in 
```

- Result of the command

Below we can notice that the length of the path through 10.10.0.254 bas been increased and the next-hop has been changed. Now the best route to 200.0.0.0/16 goes through 172.16.0.254 which is the Hub-GW since it now has the shortest path of both.

![WVD_Path_Result](https://github.com/Tchimwa/Azure-Labs/blob/main/BGP%20Redundancy/images/WVD_Path_Result.png)

It would be nice to experiment the other BGP attributes to better understand how they work and when to use them.

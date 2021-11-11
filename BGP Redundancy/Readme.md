# Redundancy and Path control with BGP

With the advent of te cloud, we've been finding more enterprises with virtual private connections from their on-premises infrastructure to their cloud environment. To minimize or avoid the downtime which can result to lost revenue and probably lost of customers, most of the enterprises find important and critical to have a redundant connectivity to their cloud environment. Despite the fact that it can be costly and complex, redundancy will be essential to keep the connectivity always UP. When it comes to path control, depending on the applications ran in their network, some companies choose to have different path for different type of traffic especially for less latency and better efficiency.

In this lab, we will have 4 VNETs: one simulating the customer's environment on-premises, a Hub and spoke VNETs on one region, and another one as a branch VNET on a different region. The Hub and  Spoke Vnets will be peered together with a VPN Gateway on the Hub Vnet. The Hub and the Branch will be connected using a Vnet-to-Vnet connection with BGP and  the On-premises Vnet will be connected to the Hub and the Branch Vnets using a Site-to-site VPN connection with BGP as well. We'll see how the redundancy has been implemented to access each of the regions, and different case scenarios of path control totally dependant of the customer.

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

From the routing table, we can clearly see the best route to each region as we can below.

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

We can just start talking about Path control with BGP without brushing up the BGP attributes used to implement the Path control. In fact, BGP used the path attributes below to implement the best path selection

Reference: <https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html>

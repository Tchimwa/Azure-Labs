# Private Endpoint with common DNS scenarios

## Requirements

1. Use the ***pe-deploy.azcli*** file to deploy the BICEP templates. Feel free to change the location or the name of the resource group as it pleases you.

2. Use the following [link](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms?view=sql-server-ver15#download-ssms) below to download and install SSMS on the hub-vm01 and op-vm01 virtual machines. <>
    You might be prompted to install NETFramework 2.0 on the server before installing SMSS, please use this [link](https://www.interserver.net/tips/kb/enable-net-framework-3-5-windows-server/#:~:text=Enable%20.NET%20Framework%203.5%20on%20Windows%20Server%201,the%20%E2%80%98Close%E2%80%99%20button%20to%20finalize%20the%20installation%20process) to complete the operation, then install SMSS.

## Task 1: Set up the Active-Active BGP VPN connection between On-premises and Azure

1. Configure the connection on Azure to handle the active-active configuration

    - Set the local network gateway - Replace ***csr01v_out_pip*** by the public IP of csr01v

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

3. Verification

```azurecli
az network vnet-gateway list-learned-routes --resource-group Cloud-rg -name cl-vpn-gw -o table
az network vnet-gateway list-advertised-routes --resource-group Cloud-rg --name cl-vpn-gw --peer 1.1.1.1 -o table
```

## Task 2: Create the Private Endpoint on the netsqlsrv database server

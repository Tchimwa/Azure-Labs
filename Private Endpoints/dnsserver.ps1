Install-WindowsFeature -Name DNS -IncludeManagementTools
Add-DnsServerForwarder -IPAddress 8.8.8.8
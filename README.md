## Overview
A powershell module that generates various ip/subnet information, such as cidr notation, network address, potential default gateway, broadcast address, usable ip count, and it will return an array of "usable" IPs given the network scope.
Which is particularly helpful if you want to run a command for each ip on a specific subnet.  

# Basic Use
To begin using the Module start by downloading or clone the repo to a location such as your desktop folder.  If you download, in lieu of cloning you'll need to extract the module from the zip file.

Open Powershell and browse to the folder where you downloaded\extracted the module.

```
cd ~/Desktop/IPSubnetInformation
```

Next you will need to import the module to have access to the command.  This needs to be done each time you open powershell or you'll need to place the module in your modules path.

```
Import-Module ./Get-IPSubNetInformation.ps1
```

After successfully importing the module you can use the Get-IPSubNetInformation command.

```
Get-IPSubNetInformation -IPAddress 10.10.10.1 -SubnetMask 255.255.255.0
```
or

```
Get-IPSubnetInformation -CIDRNotation 10.10.10.1/24
```

# Additional Properties
Get-IPSubNetInformation returns the following properties:
-IPAddress
-CIDRNotation
-SubnetMask
-CIDR
-NetworkAddress
-DefaultGateway
-BroadcastAddress
-UsableIPCount
-UsableIPs

# Other Examples

```
$network = Get-IPSubNetInformation -CIDR 192.168.5.2/24

foreach $ip in $network.UsableIPs {
    'do command for $ip
}
```

# Warnings
While you can process /8 or /16 subnets, just know that powershell is slow and it will take a little while.

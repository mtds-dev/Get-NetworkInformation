function Get-NetworkInformation
{
   <# 
    .SYNOPSIS
    A cmdlet that helps retrieve basic subnetting information.

    .DESCRIPTION
    A cmdlet that helps retrieve basic subnetting information.

    .PARAMETER IPAddress
    .PARAMETER SubnetMask
    .PARAMETER CIDRNotation
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "IPAddress", Position = 0)]
        [Alias("IP")]
        [ValidatePattern("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$")]
        [String]$IPAddress,

        [Parameter(Mandatory = $true, ParameterSetName = "IPAddress", Position = 1)]
        [Alias("Mask", "Subnet")]
        [ValidatePattern("^(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)\.(255|254|252|248|240|224|192|128|0)$")]
        [String]$SubnetMask,

        [Parameter(Mandatory = $true, ParameterSetName = "CIDR", Position = 0)]
        [Alias("CIDR","Notation")]
        [String]$CIDRNotation
    )

    process {
        [System.Net.IPAddress] $working_ipaddress 
        [System.Net.IPAddress] $working_subnet 

        if ($PSCmdlet.ParameterSetName -eq "IPAddress") {
            $working_ipaddress = [System.Net.IPaddress]::Parse($IPAddress)
            $working_subnet = [System.Net.IPaddress]::Parse($SubnetMask)
        }

        if ($PSCmdlet.ParameterSetName -eq "CIDR") {
            $splitarguments = $CIDRNotation -split "/"
            $working_ipaddress = [System.Net.IPAddress]::Parse($splitarguments[0])
            $working_subnet = Convert-CIDRToIPSubnetMask -CIDRNotation $splitarguments[1]
        }

        $working_networkaddress = Get-NetworkAddress -IPAddress $working_ipaddress -SubnetMask $working_subnet
        $working_cidr = (Get-CIDRNotation -SubnetMask $working_subnet)

        $customIPAddress = [PSCustomObject]@{
            IPAddress = $working_ipaddress
            SubnetMask = $working_subnet
            NetworkAddress = $working_networkaddress 
            CIDR = $working_cidr 
            CIDRNotation = ($working_ipaddress.IPAddressToString + "/" + $working_cidr)
            DefaultGateway = (Add-ToIPAddress -IPAddress $working_networkaddress -IncrementBy 1)
            BroadcastAddress = (Get-BroadcastAddress -IPAddress $working_ipaddress -SubnetMask $working_subnet)
            UsableIPCount = (Get-UsableIPAddressCount -NetworkAddress $working_networkaddress -SubnetMask $working_subnet)
            UsableIPs = (Get-UsableIPAddresses -NetworkAddress $working_networkaddress -SubnetMask $working_subnet)
        }
        return $customIPAddress
    }
}
Export-ModuleMember -Function Get-NetworkInformation


function Get-NetworkAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("IP")]
        [System.Net.IPAddress]$IPAddress,

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias("Subnet","Mask")]
        [System.Net.IPAddress]$SubnetMask
    )

    $ipToBytes = $IPAddress.GetAddressBytes()
    $subnetToBytes = $SubnetMask.GetAddressBytes()

    $networkAddressInBytes = for ($i = 0; $i -lt $ipToBytes.Length; $i++) {
        $ipToBytes[$i] -band $subnetToBytes[$i]
    }

    return [System.Net.IPAddress]::new($networkAddressInBytes)
}

function Add-ToIPAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "IPAddress", Position = 0)]
        [Alias("IP")]
        [System.Net.IPAddress]$IPAddress,

        [Parameter(Mandatory = $true, ParameterSetName = "IPAddress", Position = 1)]
        [Alias("Inc")]
        [int]$IncrementBy
    )

    $addressInBytes = $IPAddress.GetAddressBytes()
    [Array]::Reverse($addressInBytes)
    $int = [BitConverter]::ToUInt32($addressInBytes, 0)
    $int += $IncrementBy
    $newAddressBytes = [BitConverter]::GetBytes($int)
    [Array]::Reverse($newAddressBytes)
    return [System.Net.IPAddress]::new($newAddressBytes)

}

function Get-BroadcastAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("IP")]
        [System.Net.IPAddress]$IPAddress,

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias("Subnet","Mask")]
        [System.Net.IPAddress]$SubnetMask
    )

    $subnetMaskToBytes = $SubnetMask.GetAddressBytes()

    $networkAddress = Get-NetworkAddress -IPAddress $IPAddress -SubnetMask $SubnetMask
    $networkAddressToBytes = $networkAddress.GetAddressBytes()
    
    $wildcardToBytes = for ($i = 0; $i -lt 4; $i++) {
        -bnot $subnetMaskToBytes[$i] -band 0xFF
    }

    $broadcastToBytes = for ($i = 0; $i -lt 4; $i++) {
        $networkAddressToBytes[$i] -bor $wildcardToBytes[$i]
    }

    return [System.Net.IPAddress]::new($broadcastToBytes)

}

function Get-UsableIPAddressCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("IP")]
        [System.Net.IPAddress]$NetworkAddress,

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias("Subnet","Mask")]
        [System.Net.IPAddress]$SubnetMask
    )

    $subnetMaskToBytes = $SubnetMask.GetAddressBytes()
    $binarySubnetMask = ($subnetMaskToBytes | ForEach-Object { [Convert]::ToString($_,2).PadLeft(8,'0')}) -join ''

    $networkBits = ($binarySubnetMask.ToCharArray() | Where-Object {$_ -eq '1' }).Count
    $hostBits = 32 - $networkBits

    if ($hostBits -le 1) {
        return 0
    } else {
        return [math]::Pow(2, $hostBits) - 2
    }
}


function Get-UsableIPAddresses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("IP")]
        [System.Net.IPAddress]$NetworkAddress,

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias("Subnet","Mask")]
        [System.Net.IPAddress]$SubnetMask
    )

    $networkAddressToBytes = $NetworkAddress.GetAddressBytes()
    $subnetMaskToBytes = $SubnetMask.GetAddressBytes()

    [Array]::Reverse($networkAddressToBytes)
    $networkInt = [BitConverter]::ToUInt32($networkAddressToBytes, 0)

    [Array]::Reverse($subnetMaskToBytes)
    $subnetMaskInt = [BitConverter]::ToUInt32($subnetMaskToBytes, 0)    

    $hostBits = 32 - ([Convert]::ToString($subnetMaskInt, 2).ToCharArray() | Where-Object {$_ -eq '1'}).Count
    
    if ($hostBits -le 1) {
        return @()
    }

    $totalHosts = [math]::Pow(2, $hostBits)
    $firstUsable = $networkInt + 1
    $lastUsable = $networkInt + $totalHosts - 2

    $usableIPs = @()
    
    for ($i = $firstUsable; $i -le $lastUsable; $i++) {
        $bytes = [BitConverter]::GetBytes($i)
        [Array]::Reverse($bytes)
        $usableIPs += [System.Net.IPAddress]::new($bytes)
    }

    return $usableIPs
    
}

function Get-CIDRNotation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("Subnet","Mask")]
        [System.Net.IPAddress]$SubnetMask
    )
    
    $subnetMaskToBytes = $subnetMask.GetAddressBytes()

    $cidrNotation = ($subnetMaskToBytes | ForEach-Object {
        [Convert]::ToString($_, 2).ToCharArray() | Where-Object {$_ -eq '1' }
        }).Count

    return $cidrNotation 
}

function Convert-CIDRToIPSubnetMask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("CIDR")]
        [String]$CIDRNotation
    )

    $intCIDR = [int]$CIDRNotation

    if ($intCIDR -lt 0 -or $intCIDR -gt 32) {
        throw "Invalid CIDR"
    }

    $subnetMaskBits = ("1" * $intCIDR).PadRight(32, "0")
    $subnetMaskBytes = @(
        [Convert]::ToByte($subnetMaskBits.Substring(0, 8), 2),
        [Convert]::ToByte($subnetMaskBits.Substring(8, 8), 2),
        [Convert]::ToByte($subnetMaskBits.Substring(16, 8), 2),
        [Convert]::ToByte($subnetMaskBits.Substring(24, 8), 2)
    )

    return [System.Net.IPAddress]::new($subnetMaskBytes)
}

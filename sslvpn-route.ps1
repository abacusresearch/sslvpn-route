#requires -version 5 -RunAsAdministrator

<#
.SYNOPSIS
	set route to destination through SSLVPN
.INPUTS
	destination as hostname or IP
.NOTES
	Version:		1.0.0
	Author:			Benjamin Rechsteiner
	Creation Date:	2022-03-22
	Last Modified:	2022-03-22
	Purpose/Change: First Release
#>

param (
	[String]$Dest
)

if ([string]::IsNullOrEmpty($Dest)) {
	Write-Host 'Destination argument is not a valide IP or Hostname'
	exit $false
}

$IPs = @()

function Get-IPs {
	if ($Dest -match '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
		$script:IPs += $Dest
	} elseif ($Dest -match '^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$') {
		Resolve-DnsName -Type A $Dest | foreach { $script:IPs += $_.IPAddress }
	} else {
		Write-Host 'Destination argument is not a valide IP or Hostname'
		exit $false
	}
	if (-Not $script:IPs.Count -gt 0) {
		Write-Host 'No IP could be resolved for this hostname'
		exit $false
	}
}

function Get-GwIp {
	Get-NetRoute -DestinationPrefix 46.227.224.0/21
}

function Set-Route {
	$Gw = Get-GwIp
	Foreach ($ip in $script:IPs) {
		route ADD $ip MASK 255.255.255.255 $Gw.NextHop
		Write-Host "Set Route $ip/32 through SSLVPN"
	}
}

Get-IPs
Set-Route

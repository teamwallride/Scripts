# Get failovers for an agent or gateway
$Failover=""
$Computer = Get-SCOMagent -Name "AGENT_FQDN"
# $Computer = Get-SCOMManagementServer -Name "GW_FQDN"
$Primary="(P)"+$Computer.GetPrimaryManagementServer().name
$Failovers=$Computer.GetFailoverManagementServers()
foreach ($i in $Failovers) {
$Failover+="(F)"+$i.principalname + "`n"
}
$Primary,$Failover

#Get failovers for all agents & gateways and write to file
#This gets the primary and failover servers for agents and gateways and writes the output to screen and file.

[int]$count="" # need to declare at int or $count gets weird.
$item=""
$fqdn=""
$pri=""
$file=""
$fail=""
$arr=@("Agent", "Gateway")
$file+="TYPE^FQDN^PRIMARY_MS^FAIL_1^FAIL_2^FAIL_3`r"
$output="C:\temp\FailoverConfig.csv"
foreach ($item in $arr) {
if ($item -eq "Agent") {
<#
Use this for testing, otherwise script will get everything.
$Type=Get-SCOMAgent | where {$_.PrincipalName -match "domain.name"} | sort PrincipalName | select -First 20
#>
$Type=Get-SCOMAgent | sort PrincipalName
} elseif ($item -eq "Gateway") {
$Type=Get-SCOMManagementServer | where {$_.IsGateway -eq $true} | sort PrincipalName
}
$Type | sort name | foreach {
$count+=1
$fqdn=$_.PrincipalName
$pri=($_.GetPrimaryManagementServer()).PrincipalName
$failovers=$_.GetFailoverManagementServers()
foreach ($i in $failovers) {
$fail+=$i.principalname + "^"
}
$file+="$item^$fqdn^$pri^$fail`r"
Write-Host "$count^$item^$fqdn^$pri^$fail"
# Need to reset these.
$fqdn=""
$pri=""
$fail=""
}}
write-host "Exporting output to $output"
$file | out-file $output

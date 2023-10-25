<#
I think this might be a replacement for gGreyAgents.ps1
#>

$date= Get-Date
Write-Host
Write-Host -ForegroundColor yellow "Script start: $date"
Write-Host
$csv+="PING,STATE,PLATFORM,FQDN,COMPUTER_NAME,DOMAIN_NAME`r"
$Classes="Microsoft.SystemCenter.Agent", "Microsoft.Unix.Computer"
foreach ($Class in $Classes) { # start for
If ($Class -eq "Microsoft.SystemCenter.Agent") {
$Platform="Windows"} Else {
$Platform="UNIX_Linux"}
Write-Host -ForegroundColor yellow "Getting $Platform agent state..."
Write-Host
$Class=Get-SCOMClass -Name $Class
$Agents=Get-SCOMClassInstance -Class $Class #| where {$_.IsAvailable -ne $false}
	foreach ($Agent in $Agents) {
	$fqdn = $Agent.DisplayName
	$compname=$fqdn.split("{.}",2)[0]
	$domname=$fqdn.split("{.}",2)[1]
	If ($Agent.IsAvailable -ne $True) {
		If (Test-Connection -computername $fqdn -Count 2 -quiet) {
		$csv+="Up,Broken,$Platform,$fqdn,$compname,$domname`r" # Agent is grey but responds to ping.
		}
		Else
		{
		$csv+="Down,Offline,$Platform,$fqdn,$compname,$domname`r" # Agent is offline.
		}
	} Else {
	$csv+="Up,Healthy,$Platform,$fqdn,$compname,$domname`r" # Agent is healthy.
	}
	}
} # end for
write-host -ForegroundColor yellow "Exporting output to C:\temp\scripts\ALL_AGENTS.csv"
Write-Host
$csv | out-file C:\temp\scripts\ALL_AGENTS.csv
$date= Get-Date
Write-Host -ForegroundColor yellow "Script finish: $date"
Write-Host

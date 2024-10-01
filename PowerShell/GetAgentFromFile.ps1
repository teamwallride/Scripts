<#
This gets a list of computers from file then checks to see if it's in SCOM. It checks for:
	- Windows computers.
	- UNIX/Linux computers.
	- Pending queue.
	
Output is written to screen and csv file for sorting.
#>
clear-host
[int]$Count = ""
$File = ""
$File = "FQDN^TYPE^STATE`r"
$Output = "C:\temp\GetAgentFromFile.csv"
$Servers = gc C:\Temp\file.txt | sort
#$Windows = Get-SCOMAgent | sort DisplayName
#$Unix = Get-SCOMClass -Name Microsoft.Unix.Computer | Get-SCOMClassInstance | sort DisplayName # Gets both UNIX and Linux.
#$Pending = Get-SCOMPendingManagement | sort AgentName
foreach($server in $Servers)
{
	$Count += 1
	$ServerUpper = $server.ToUpper()
	$MatchWindows = $Windows | where-object {$_.DisplayName -eq $server}
	$MatchUnix = $Unix | where-object {$_.DisplayName -eq $server}
	$MatchPending = $Pending | where-object {$_.AgentName -eq $server}
	If ($MatchWindows)
	{
		$File += "$ServerUpper^WINDOWS^IN SCOM`r"
		Write-Host -ForegroundColor green "$Count^$ServerUpper^WINDOWS^IN SCOM"
	}
	ElseIf ($MatchUnix)
	{
		$File += "$ServerUpper^UNIX^IN SCOM`r"
		Write-Host -ForegroundColor green "$Count^$ServerUpper^UNIX^IN SCOM"
	}
	ElseIf ($MatchPending)
	{
		# Only Windows servers appear in the pending queue, hence column name.
		$File += "$ServerUpper^WINDOWS^IN PENDING`r"
		Write-Host -ForegroundColor yellow "$Count^$ServerUpper^WINDOWS^IN PENDING"
	}
	Else
	{
		$File += "$ServerUpper^UNKNOWN^NOT IN SCOM`r"
		Write-Host -ForegroundColor red "$Count^$ServerUpper^UNKNOWN^NOT IN SCOM"
	}
}
$File | out-file $Output
